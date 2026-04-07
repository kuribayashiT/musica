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
        hidePickerAndInjectSpeedRow()
        setupShuffleRepeatLabels()
        stylePlaybackControls()
        styleProgressSlider()
        styleLyricSegment()
    }

    // MARK: 1. 速度プリセット行
    private func hidePickerAndInjectSpeedRow() {
        // 既存のUIPickerViewを非表示
        speedPicker.isHidden = true

        // プリセット行を speedPicker の superview に追加
        guard let parent = speedPicker.superview else { return }

        let row = makeSpeedRow()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.tag = PlayerUITag.speedRow
        parent.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: speedPicker.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: speedPicker.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: speedPicker.centerYAnchor),
            row.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func makeSpeedRow() -> UIView {
        let container = UIView()

        // 現在速度ラベル（左端）
        let speedLabel = UILabel()
        speedLabel.tag = PlayerUITag.speedValueLabel
        speedLabel.font = AppFont.footnote
        speedLabel.textColor = AppColor.textSecondary
        speedLabel.setContentHuggingPriority(.required, for: .horizontal)

        // プリセットスタック（右側）
        let presetStack = UIStackView()
        presetStack.axis         = .horizontal
        presetStack.distribution = .fillEqually
        presetStack.spacing      = 6

        let presets: [(String, Double)] = [("0.75×", 0.75), ("1.0×", 1.0), ("1.25×", 1.25), ("1.5×", 1.5)]
        for (label, value) in presets {
            let btn = makeSpeedPresetButton(title: label, speed: value)
            presetStack.addArrangedSubview(btn)
        }

        // 「詳細…」ボタン
        let moreBtn = UIButton(type: .system)
        moreBtn.setTitle("詳細", for: .normal)
        moreBtn.titleLabel?.font = AppFont.caption
        moreBtn.setTitleColor(AppColor.textSecondary, for: .normal)
        moreBtn.setContentHuggingPriority(.required, for: .horizontal)
        moreBtn.addTarget(self, action: #selector(showSpeedSheet), for: .touchUpInside)

        let hStack = UIStackView(arrangedSubviews: [speedLabel, presetStack, moreBtn])
        hStack.axis      = .horizontal
        hStack.spacing   = 8
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hStack.topAnchor.constraint(equalTo: container.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    private func makeSpeedPresetButton(title: String, speed: Double) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font   = AppFont.caption
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth  = 1.5
        btn.tag = Int(speed * 100)
        btn.addTarget(self, action: #selector(speedPresetTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: 2. シャッフル・リピートの状態ラベル
    private func setupShuffleRepeatLabels() {
        attachStateLabel(to: shuffleBtn, tag: PlayerUITag.shuffleLabel)
        attachStateLabel(to: repeatBtn,  tag: PlayerUITag.repeatLabel)
    }

    private func attachStateLabel(to button: UIButton, tag: Int) {
        guard let parent = button.superview else { return }

        let label = UILabel()
        label.tag            = tag
        label.font           = AppFont.caption2
        label.textAlignment  = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            label.topAnchor.constraint(equalTo: button.bottomAnchor, constant: 4),
        ])
    }

    // MARK: 3. 再生コントロールのスタイリング
    private func stylePlaybackControls() {
        // 再生/停止ボタン
        PlayBtn.tintColor      = AppColor.textPrimary
        BeforeBtn.tintColor    = AppColor.textPrimary
        AfterBtn.tintColor     = AppColor.textPrimary

        // 再生時間ラベル
        if let nowTime = musicNowTime {
            nowTime.font      = AppFont.playerTime
            nowTime.textColor = AppColor.textSecondary
        }
        if let totalTime = musicTotalTime {
            totalTime.font      = AppFont.playerTime
            totalTime.textColor = AppColor.textSecondary
        }

        // 曲名（ナビゲーションタイトルフォントはStoryboard依存のためここでは設定しない）
    }

    // MARK: 4. シークバーのスタイリング
    private func styleProgressSlider() {
        musicProgressSlider.minimumTrackTintColor = AppColor.accent
        musicProgressSlider.maximumTrackTintColor = AppColor.separator
    }

    // MARK: 5. 歌詞セグメントのスタイリング
    private func styleLyricSegment() {
        lyricSegmentetion.selectedSegmentTintColor = AppColor.accent
        if #available(iOS 13.0, *) {
            lyricSegmentetion.setTitleTextAttributes(
                [.foregroundColor: AppColor.textPrimary, .font: AppFont.footnote], for: .normal
            )
            lyricSegmentetion.setTitleTextAttributes(
                [.foregroundColor: UIColor.white, .font: AppFont.footnote], for: .selected
            )
        }
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
            let rate = Float((speed * 10).rounded() / 10)
            audioPlayer.rate = rate
        }
    }

    func updateSpeedRowUI(speed: Double) {
        // 速度ラベル更新
        if let label = speedPicker.superview?.viewWithTag(PlayerUITag.speedValueLabel) as? UILabel {
            label.text = speed == 1.0 ? "" : String(format: "%.2g×", speed)
        }

        // プリセットボタンの選択状態更新
        guard let speedRow = speedPicker.superview?.viewWithTag(PlayerUITag.speedRow) else { return }
        for view in speedRow.subviews {
            updatePresetButtons(in: view, selectedSpeed: speed)
        }
    }

    private func updatePresetButtons(in view: UIView, selectedSpeed: Double) {
        if let btn = view as? UIButton, btn.tag > 0 {
            let presetSpeed = Double(btn.tag) / 100.0
            let isSelected = abs(presetSpeed - selectedSpeed) < 0.01
            UIView.animate(withDuration: 0.15) {
                btn.backgroundColor    = isSelected ? AppColor.accent : AppColor.surfaceSecondary
                btn.setTitleColor(isSelected ? .white : AppColor.textPrimary, for: .normal)
                btn.layer.borderColor  = isSelected ? AppColor.accent.cgColor : AppColor.border.cgColor
            }
        }
        for sub in view.subviews {
            updatePresetButtons(in: sub, selectedSpeed: selectedSpeed)
        }
    }

    /// 起動時・Speed復元時に呼ぶ
    func restoreSpeedUI() {
        let speed = speedList[speedRow]
        updateSpeedRowUI(speed: speed)
    }
}

// MARK: - Shuffle / Repeat State Labels

extension PlayMusicViewController {

    func updateShuffleLabel() {
        guard let label = shuffleBtn.superview?.viewWithTag(PlayerUITag.shuffleLabel) as? UILabel else { return }
        label.text      = SHUFFLE_FLG ? "オン" : "オフ"
        label.textColor = SHUFFLE_FLG ? AppColor.accent : AppColor.textDisabled
    }

    func updateRepeatLabel() {
        guard let label = repeatBtn.superview?.viewWithTag(PlayerUITag.repeatLabel) as? UILabel else { return }
        switch repeatState {
        case REPEAT_STATE_NONE:
            label.text      = "オフ"
            label.textColor = AppColor.textDisabled
        case REPEAT_STATE_ALL:
            label.text      = "全曲"
            label.textColor = AppColor.accent
        case REPEAT_STATE_ONE:
            label.text      = "1曲"
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
