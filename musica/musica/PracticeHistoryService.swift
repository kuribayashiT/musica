//
//  PracticeHistoryService.swift
//  musica
//
//  練習セッションを UserDefaults に記録・集計するサービス。
//

import Foundation

// MARK: - Models

enum PracticeType: String, Codable, CaseIterable {
    case dictation, sectionRepeat, flashCard

    var displayName: String {
        switch self {
        case .dictation:    return "ディクテーション"
        case .sectionRepeat: return "区間リピート"
        case .flashCard:    return "フラッシュカード"
        }
    }

    var symbolName: String {
        switch self {
        case .dictation:    return "waveform.and.mic"
        case .sectionRepeat: return "repeat"
        case .flashCard:    return "rectangle.on.rectangle.angled"
        }
    }
}

struct PracticeRecord: Codable {
    let id: UUID
    let date: Date
    let type: PracticeType
    let trackTitle: String
    let trackArtist: String
    let correctCount: Int
    let totalCount: Int

    var scorePercent: Int? {
        guard totalCount > 0 else { return nil }
        return Int((Double(correctCount) / Double(totalCount) * 100).rounded())
    }
}

// MARK: - Service

final class PracticeHistoryService {
    static let shared = PracticeHistoryService()
    private init() {}

    private let storageKey = "practice_history_v1"
    private var cache: [PracticeRecord]?

    func allRecords() -> [PracticeRecord] {
        if let c = cache { return c }
        let loaded = loadFromDisk()
        cache = loaded
        return loaded
    }

    func add(_ record: PracticeRecord) {
        var updated = allRecords()
        updated.insert(record, at: 0)
        if updated.count > 200 { updated = Array(updated.prefix(200)) }
        cache = updated
        saveToDisk(updated)
    }

    // 0 if never practiced; counts consecutive days ending today
    func currentStreak() -> Int {
        let calendar = Calendar.current
        let practicedDays = Set(allRecords().map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var check  = calendar.startOfDay(for: Date())
        while practicedDays.contains(check) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    // [oldest (6 days ago) … today], true = practiced that day
    func weekActivity() -> [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let practicedDays = Set(allRecords().map { calendar.startOfDay(for: $0.date) })
        return (0..<7).map { offset in
            guard let d = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return false }
            return practicedDays.contains(d)
        }
    }

    // MARK: Aggregates

    struct Summary {
        let streak: Int
        let thisMonthCount: Int
        let thisYearCount: Int
        let totalCount: Int
    }

    func summary() -> Summary {
        let calendar = Calendar.current
        let now      = Date()
        let records  = allRecords()
        let y = calendar.component(.year,  from: now)
        let m = calendar.component(.month, from: now)
        let thisMonth = records.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.date)
            return c.year == y && c.month == m
        }.count
        let thisYear = records.filter { calendar.component(.year, from: $0.date) == y }.count
        return Summary(streak: currentStreak(), thisMonthCount: thisMonth,
                       thisYearCount: thisYear, totalCount: records.count)
    }

    // [(month: 1...12, count)] for the given year
    func monthlyBreakdown(year: Int) -> [(month: Int, count: Int)] {
        let calendar = Calendar.current
        var counts   = [Int: Int]()
        for record in allRecords() {
            let c = calendar.dateComponents([.year, .month], from: record.date)
            guard c.year == year, let month = c.month else { continue }
            counts[month, default: 0] += 1
        }
        return (1...12).map { (month: $0, count: counts[$0, default: 0]) }
    }

    func allActiveYears() -> [Int] {
        let calendar = Calendar.current
        return Set(allRecords().compactMap {
            calendar.dateComponents([.year], from: $0.date).year
        }).sorted()
    }

    // MARK: Track Summaries

    struct TrackSummary {
        let title: String
        let artist: String
        let sessions: [PracticeRecord]   // newest-first

        var latestDate: Date  { sessions.first?.date ?? .distantPast }
        var sessionCount: Int { sessions.count }
        var bestScore: Int?   { sessions.compactMap { $0.scorePercent }.max() }

        /// Oldest → newest, up to last 5 sessions that have a score
        var scoreTrend: [Int] {
            Array(sessions.reversed().compactMap { $0.scorePercent }.suffix(5))
        }

        /// latest score − oldest score in trend; positive = improving
        var trendDelta: Int? {
            let t = scoreTrend
            guard t.count >= 2 else { return nil }
            return t.last! - t.first!
        }

        var dominantType: PracticeType {
            Dictionary(grouping: sessions, by: { $0.type })
                .max(by: { $0.value.count < $1.value.count })?.key ?? .dictation
        }

        var usedTypes: [PracticeType] {
            let used = Set(sessions.map { $0.type })
            return [.dictation, .sectionRepeat, .flashCard].filter { used.contains($0) }
        }
    }

    /// All practiced tracks, sorted by most recently practiced first.
    /// Pass `filterType` to include only sessions of that type.
    func allTrackSummaries(filterType: PracticeType? = nil) -> [TrackSummary] {
        let source = filterType == nil ? allRecords() : allRecords().filter { $0.type == filterType! }
        var dict: [String: [PracticeRecord]] = [:]
        for r in source {
            let key = "\(r.trackTitle)\u{0}\(r.trackArtist)"
            dict[key, default: []].append(r)
        }
        return dict.values.map { sessions in
            TrackSummary(title: sessions[0].trackTitle,
                         artist: sessions[0].trackArtist,
                         sessions: sessions)
        }.sorted { $0.latestDate > $1.latestDate }
    }

    func yearComparison() -> (thisYear: Int, lastYear: Int) {
        let calendar = Calendar.current
        let y        = calendar.component(.year, from: Date())
        var thisCount = 0, lastCount = 0
        for r in allRecords() {
            let ry = calendar.component(.year, from: r.date)
            if ry == y       { thisCount += 1 }
            else if ry == y - 1 { lastCount += 1 }
        }
        return (thisCount, lastCount)
    }

    // MARK: Persistence

    private func loadFromDisk() -> [PracticeRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([PracticeRecord].self, from: data)) ?? []
    }

    private func saveToDisk(_ records: [PracticeRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
