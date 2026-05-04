//
//  PlayMusicViewController+PlayerUI.swift
//  musica
//
//  再生画面 UX改善 — プログラマティックUI追加
//
//  ・speedPickerを非表示にし、プリセットボタン行に置き換え
//  ・シャッフル/リピートボタンの下に状態ラベルを追加
//  ・アルバムアート下部グラデーション
//  ・シークバーのスタイリング
//

import UIKit

// MARK: - PlayerUI Setup

extension PlayMusicViewController {

    /// viewDidLoad から呼ぶ
    func setupPlayerUI() {
        buildNewPlayerUI()
    }
}

// MARK: - Speed Preset Actions

extension PlayMusicViewController {

    @objc func speedPresetTapped(_ sender: UIButton) {
        let speed = Double(sender.tag) / 100.0
        applySpeed(speed)
        updateSpeedRowUI(speed: speed)
    }

    @objc func showSpeedSheet() {
        let currentSpeed = speedList[speedRow]
        let sheet = SpeedSheetViewController(currentSpeed: currentSpeed)
        sheet.delegate = self
        present(sheet, animated: false)
    }

    func applySpeed(_ speed: Double) {
        // speedList で最近傍のインデックスを探してグローバル変数を更新
        let nearest = speedList.enumerated().min { abs($0.element - speed) < abs($1.element - speed) }
        speedRow = nearest?.offset ?? 5
        if audioPlayer != nil {
            // AVAudioPlayer.rate の有効範囲は 0.5〜2.0
            // それを超える場合は 2.0 にクランプして再生速度を最大にする
            let clamped = max(0.5, min(2.0, speed))
            let rate = Float((clamped * 10).rounded() / 10)
            audioPlayer.rate = rate
        }
    }

    func updateSpeedRowUI(speed: Double) {
        syncNewUISpeedState()
    }

    /// 起動時・Speed復元時に呼ぶ
    func restoreSpeedUI() {
        syncNewUISpeedState()
    }
}

// MARK: - Shuffle / Repeat State Labels

extension PlayMusicViewController {

    func updateShuffleLabel() {
        guard let label = shuffleBtn.superview?.viewWithTag(PlayerUITag.shuffleLabel) as? UILabel else { return }
        label.text      = SHUFFLE_FLG ? localText(key: "player_state_on") : localText(key: "player_state_off")
        label.textColor = SHUFFLE_FLG ? AppColor.accent : AppColor.textDisabled
    }

    func updateRepeatLabel() {
        guard let label = repeatBtn.superview?.viewWithTag(PlayerUITag.repeatLabel) as? UILabel else { return }
        switch repeatState {
        case REPEAT_STATE_NONE:
            label.text      = localText(key: "player_state_off")
            label.textColor = AppColor.textDisabled
        case REPEAT_STATE_ALL:
            label.text      = localText(key: "player_repeat_all")
            label.textColor = AppColor.accent
        case REPEAT_STATE_ONE:
            label.text      = localText(key: "player_repeat_one")
            label.textColor = AppColor.accent
        default:
            label.text = ""
        }
    }
}

// MARK: - SpeedSheetDelegate

extension PlayMusicViewController: SpeedSheetDelegate {
    func speedSheet(_ vc: SpeedSheetViewController, didSelectSpeed speed: Double) {
        applySpeed(speed)
        updateSpeedRowUI(speed: speed)
    }
}

// MARK: - Tag Constants

enum PlayerUITag {
    static let speedRow        = 9001
    static let speedValueLabel = 9002
    static let shuffleLabel    = 9003
    static let repeatLabel     = 9004
}
