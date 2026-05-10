//
//  SpeedSheetViewController.swift
//  musica
//
//  再生速度ボトムシート
//  - 0.5x〜50x の対数スライダーで調整
//  - 低速プリセット行 + 高速プリセット行
//  - iOS 13 以降対応
//

import UIKit

// MARK: - Delegate

protocol SpeedSheetDelegate: AnyObject {
    func speedSheet(_ vc: SpeedSheetViewController, didSelectSpeed speed: Double)
}

// MARK: - SpeedSheetViewController

final class SpeedSheetViewController: UIViewController {

    weak var delegate: SpeedSheetDelegate?
    var currentSpeed: Double = 1.0

    // ── スナップポイント（対数スケールで均等感を出す刻み）─────────────
    private let snapPoints: [Double] = [
        0.5, 0.6, 0.7, 0.75, 0.8, 0.9,
        1.0, 1.1, 1.2, 1.25, 1.3, 1.4, 1.5, 1.6, 1.7, 1.75, 1.8, 1.9,
        2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0,
        6.0, 7.0, 8.0, 9.0, 10.0,
        12.0, 15.0, 17.0, 20.0, 25.0, 30.0, 35.0, 40.0, 45.0, 50.0
    ]

    // ── UI ────────────────────────────────────────────────────────
    private let containerView   = UIView()
    private let handleBar       = UIView()
    private let titleLabel      = UILabel()
    private let speedLabel      = UILabel()
    private let slider          = UISlider()
    private let lowPresetStack  = UIStackView()   // 0.5×〜2.0×
    private let highPresetStack = UIStackView()   // 3×〜50×
    private let doneButton      = UIButton(type: .system)

    private let lowPresets: [(label: String, value: Double)] = [
        ("0.5×", 0.5), ("0.75×", 0.75), ("1.0×", 1.0), ("1.5×", 1.5), ("2.0×", 2.0)
    ]
    private let highPresets: [(label: String, value: Double)] = [
        ("3×", 3.0), ("5×", 5.0), ("10×", 10.0), ("20×", 20.0), ("50×", 50.0)
    ]

    // ── スケール定数 ──────────────────────────────────────────────
    // speed = 0.5 * 100^pos  →  pos ∈ [0, 1] で speed ∈ [0.5, 50]
    private let minSpeed = 0.5
    private let maxSpeed = 50.0

    // ── Init ──────────────────────────────────────────────────────
    init(currentSpeed: Double) {
        self.currentSpeed = currentSpeed
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Lifecycle ─────────────────────────────────────────────────
    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupContainer()
        setupContent()
        syncUI(speed: currentSpeed, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    // ── Setup ─────────────────────────────────────────────────────
    private func setupBackground() {
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tap)
    }

    private func setupContainer() {
        containerView.backgroundColor    = AppColor.surface
        containerView.layer.cornerRadius = 20
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 330),
        ])

        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        containerView.addGestureRecognizer(pan)
    }

    private func setupContent() {
        // ── ハンドルバー ──────────────────────────────────────────
        handleBar.backgroundColor    = AppColor.separator
        handleBar.layer.cornerRadius = 3
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(handleBar)

        // ── タイトル ──────────────────────────────────────────────
        titleLabel.text          = localText(key: "speed_sheet_title")
        titleLabel.font          = AppFont.headline
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // ── 現在速度ラベル ────────────────────────────────────────
        speedLabel.font          = AppFont.title
        speedLabel.textColor     = AppColor.accent
        speedLabel.textAlignment = .center
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(speedLabel)

        // ── スライダー（対数スケール） ─────────────────────────────
        slider.minimumValue         = 0
        slider.maximumValue         = 1
        slider.minimumTrackTintColor = AppColor.accent
        slider.maximumTrackTintColor = AppColor.separator
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(slider)

        // ── スライダー端ラベル ─────────────────────────────────────
        let minLabel = makeScaleLabel("0.5×")
        let maxLabel = makeScaleLabel("50×")

        // ── 低速プリセット行 ──────────────────────────────────────
        setupPresetStack(lowPresetStack)
        for preset in lowPresets {
            lowPresetStack.addArrangedSubview(makePresetButton(title: preset.label, value: preset.value))
        }

        // ── 高速プリセット行 ──────────────────────────────────────
        setupPresetStack(highPresetStack)
        for preset in highPresets {
            highPresetStack.addArrangedSubview(makePresetButton(title: preset.label, value: preset.value))
        }

        // ── 完了ボタン ────────────────────────────────────────────
        doneButton.setTitle(localText(key: "btn_done"), for: .normal)
        doneButton.titleLabel?.font = AppFont.button
        doneButton.setTitleColor(AppColor.accent, for: .normal)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(doneButton)

        // ── 制約 ──────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            handleBar.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 40),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            speedLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            speedLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            // スライダー + 端ラベル
            minLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            minLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),

            slider.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 10),
            slider.leadingAnchor.constraint(equalTo: minLabel.trailingAnchor, constant: 6),
            slider.trailingAnchor.constraint(equalTo: maxLabel.leadingAnchor, constant: -6),

            maxLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            maxLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),

            // 低速プリセット
            lowPresetStack.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 14),
            lowPresetStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            lowPresetStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            lowPresetStack.heightAnchor.constraint(equalToConstant: 36),

            // 高速プリセット
            highPresetStack.topAnchor.constraint(equalTo: lowPresetStack.bottomAnchor, constant: 8),
            highPresetStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            highPresetStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            highPresetStack.heightAnchor.constraint(equalToConstant: 36),

            doneButton.topAnchor.constraint(equalTo: highPresetStack.bottomAnchor, constant: 14),
            doneButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
        ])
    }

    // ── ヘルパー ──────────────────────────────────────────────────
    private func setupPresetStack(_ stack: UIStackView) {
        stack.axis         = .horizontal
        stack.distribution = .fillEqually
        stack.spacing      = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stack)
    }

    private func makePresetButton(title: String, value: Double) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font   = AppFont.footnote
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth  = 1
        // value を整数タグ（×1000）で保持（小数点以下3桁まで対応）
        btn.tag = Int(value * 1000)
        btn.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func makeScaleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text      = text
        label.font      = AppFont.caption2
        label.textColor = AppColor.textSecondary
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)
        return label
    }

    // ── 対数スケール変換 ──────────────────────────────────────────
    /// speed → slider position [0, 1]
    private func speedToSlider(_ speed: Double) -> Float {
        let clamped = max(minSpeed, min(maxSpeed, speed))
        return Float(log(clamped / minSpeed) / log(maxSpeed / minSpeed))
    }

    /// slider position [0, 1] → speed
    private func sliderToSpeed(_ pos: Float) -> Double {
        return minSpeed * pow(maxSpeed / minSpeed, Double(pos))
    }

    /// 最近傍スナップポイントに丸める
    private func snap(_ speed: Double) -> Double {
        return snapPoints.min(by: { abs($0 - speed) < abs($1 - speed) }) ?? speed
    }

    // ── 状態同期 ──────────────────────────────────────────────────
    private func syncUI(speed: Double, animated: Bool = true) {
        currentSpeed = speed

        // ラベル表示: 整数になるなら小数なし、そうでなければ最大2桁
        if speed >= 10 || speed == Double(Int(speed)) {
            speedLabel.text = String(format: "%.4g×", speed)
        } else {
            speedLabel.text = String(format: "%.2g×", speed)
        }

        slider.setValue(speedToSlider(speed), animated: animated)

        // 全プリセットボタンのハイライト更新
        for stack in [lowPresetStack, highPresetStack] {
            for view in stack.arrangedSubviews {
                guard let btn = view as? UIButton else { continue }
                let presetValue = Double(btn.tag) / 1000.0
                let isSelected  = abs(presetValue - speed) < 0.001
                btn.backgroundColor   = isSelected ? AppColor.accent : AppColor.surfaceSecondary
                btn.setTitleColor(isSelected ? .white : AppColor.textPrimary, for: .normal)
                btn.layer.borderColor = isSelected ? AppColor.accent.cgColor : AppColor.border.cgColor
            }
        }
    }

    // ── アニメーション ─────────────────────────────────────────────
    private func animateIn() {
        view.backgroundColor = AppColor.overlay.withAlphaComponent(0)
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.view.backgroundColor = AppColor.overlay
        }
    }

    private func animateOut(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn, animations: {
            self.view.backgroundColor = .clear
            self.containerView.transform = CGAffineTransform(translationX: 0, y: self.containerView.bounds.height)
        }, completion: { _ in completion() })
    }

    // ── Actions ───────────────────────────────────────────────────
    @objc private func backgroundTapped() { dismiss() }

    @objc private func doneTapped() {
        // リアルタイムで速度は適用済みのため、ここは閉じるだけ
        dismiss()
    }

    @objc private func sliderChanged() {
        let raw     = sliderToSpeed(slider.value)
        let snapped = snap(raw)
        syncUI(speed: snapped, animated: false)
        // ドラッグ中にリアルタイムで速度を反映
        delegate?.speedSheet(self, didSelectSpeed: snapped)
    }

    @objc private func presetTapped(_ sender: UIButton) {
        let speed = Double(sender.tag) / 1000.0
        syncUI(speed: speed)
        // タップ直後に速度を反映
        delegate?.speedSheet(self, didSelectSpeed: speed)
    }

    @objc private func panGesture(_ pan: UIPanGestureRecognizer) {
        let translation = pan.translation(in: view).y
        switch pan.state {
        case .changed:
            if translation > 0 {
                containerView.transform = CGAffineTransform(translationX: 0, y: translation)
            }
        case .ended, .cancelled:
            if translation > 100 {
                dismiss()
            } else {
                UIView.animate(withDuration: 0.2) {
                    self.containerView.transform = .identity
                }
            }
        default: break
        }
    }

    private func dismiss() {
        animateOut { [weak self] in
            self?.dismiss(animated: false)
        }
    }
}
