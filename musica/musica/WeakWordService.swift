//
//  WeakWordService.swift
//  musica
//
//  フラッシュカードで「もう一度」を選んだ単語を管理するサービス。
//  - upsert: 既存エントリは track 情報を保持しつつ日付を更新
//  - 覚えた (knownTapped) 時は remove で解除
//

import Foundation

struct WeakWord: Codable {
    let word: String          // lowercased key（重複排除の一意識別子）
    let displayWord: String
    let translation: String?
    let contextLine: String
    let trackTitle: String
    let trackArtist: String
    let addedDate: Date
}

final class WeakWordService {
    static let shared = WeakWordService()
    private init() {}

    private let storageKey = "weak_words_v1"
    private var cache: [WeakWord]?

    func all() -> [WeakWord] {
        if let c = cache { return c }
        let loaded = load()
        cache = loaded
        return loaded
    }

    func upsert(_ word: WeakWord) {
        var current = all()
        let existing = current.first { $0.word == word.word }
        current.removeAll { $0.word == word.word }
        let merged = WeakWord(
            word:        word.word,
            displayWord: word.displayWord,
            translation: word.translation ?? existing?.translation,
            contextLine: word.contextLine,
            trackTitle:  existing.flatMap { $0.trackTitle.isEmpty ? nil : $0.trackTitle } ?? word.trackTitle,
            trackArtist: existing?.trackArtist ?? word.trackArtist,
            addedDate:   Date()
        )
        current.insert(merged, at: 0)
        if current.count > 500 { current = Array(current.prefix(500)) }
        cache = current
        save(current)
    }

    func remove(wordKey: String) {
        var current = all()
        current.removeAll { $0.word == wordKey }
        cache = current
        save(current)
    }

    func clear() {
        cache = []
        save([])
    }

    var count: Int { all().count }

    private func load() -> [WeakWord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([WeakWord].self, from: data)) ?? []
    }

    private func save(_ words: [WeakWord]) {
        guard let data = try? JSONEncoder().encode(words) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
