//
//  SubscriptionGate.swift
//  musica
//
//  無課金ユーザーへの練習機能制限を一元管理する。
//  KAKIN_FLG == true のときはすべての制限を解除する。
//

import UIKit
import StoreKit

final class SubscriptionGate {

    static let shared = SubscriptionGate()

    // ── UserDefaults keys ──────────────────────────────────────────
    private let kDictDateKey    = "sg_dict_date"
    private let kDictCountKey   = "sg_dict_count"
    private let kFlashDateKey   = "sg_flash_date"
    private let kFlashCountKey  = "sg_flash_count"
    private let kFirstDictDone  = "sg_first_dict_done"
    private let kFirstFlashDone = "sg_first_flash_done"
    private let kTotalSessions  = "sg_total_sessions"
    private let kReviewRequested = "sg_review_requested"

    // ── 無料ティア制限値 ─────────────────────────────────────────
    let freeDictPerDay  = 3   // ディクテーション 1日3回まで
    let freeFlashPerDay = 10  // フラッシュカード 1日10枚まで

    private let defaults = UserDefaults.standard
    private init() {}

    // MARK: - Dictation

    /// 本日残りディクテーション回数（Pro は Int.max）
    var remainingDictations: Int {
        guard !KAKIN_FLG else { return Int.max }
        resetIfNewDay(dateKey: kDictDateKey, countKey: kDictCountKey)
        return max(0, freeDictPerDay - defaults.integer(forKey: kDictCountKey))
    }

    var canStartDictation: Bool { remainingDictations > 0 }

    /// ディクテーション開始を記録（呼び出し元は開始時に1回だけ呼ぶ）
    func recordDictationStarted() {
        guard !KAKIN_FLG else { return }
        resetIfNewDay(dateKey: kDictDateKey, countKey: kDictCountKey)
        defaults.set(defaults.integer(forKey: kDictCountKey) + 1, forKey: kDictCountKey)
    }

    // MARK: - FlashCard

    var remainingFlashCards: Int {
        guard !KAKIN_FLG else { return Int.max }
        resetIfNewDay(dateKey: kFlashDateKey, countKey: kFlashCountKey)
        return max(0, freeFlashPerDay - defaults.integer(forKey: kFlashCountKey))
    }

    var canUseFlashCard: Bool { remainingFlashCards > 0 }

    func recordFlashCardViewed() {
        guard !KAKIN_FLG else { return }
        resetIfNewDay(dateKey: kFlashDateKey, countKey: kFlashCountKey)
        defaults.set(defaults.integer(forKey: kFlashCountKey) + 1, forKey: kFlashCountKey)
    }

    // MARK: - First completion tracking (upgrade prompt triggers)

    var hasCompletedFirstDictation: Bool {
        get { defaults.bool(forKey: kFirstDictDone) }
        set { defaults.set(newValue, forKey: kFirstDictDone) }
    }

    var hasCompletedFirstFlash: Bool {
        get { defaults.bool(forKey: kFirstFlashDone) }
        set { defaults.set(newValue, forKey: kFirstFlashDone) }
    }

    // MARK: - App Review Request

    /// 練習セッション完了時に呼ぶ。適切なタイミングでシステムレビューダイアログを表示する。
    func recordSessionCompleted() {
        let total = defaults.integer(forKey: kTotalSessions) + 1
        defaults.set(total, forKey: kTotalSessions)

        // 3セッション目・10セッション目・30セッション目にリクエスト（1デバイス1回まで）
        let triggers = [3, 10, 30]
        guard triggers.contains(total),
              !defaults.bool(forKey: kReviewRequested) else { return }

        defaults.set(true, forKey: kReviewRequested)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }

    // MARK: - Private

    private func resetIfNewDay(dateKey: String, countKey: String) {
        let today = Calendar.current.startOfDay(for: Date())
        let saved = defaults.object(forKey: dateKey) as? Date ?? .distantPast
        if saved < today {
            defaults.set(today, forKey: dateKey)
            defaults.set(0, forKey: countKey)
        }
    }
}
