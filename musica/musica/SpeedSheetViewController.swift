//
//  SpeedSheetViewController.swift
//  musica
//
//  再生速度ボトムシート
//  - 0.5x〜2.0x のスライダーで細かく調整
//  - プリセットボタンで素早く選択
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

    // ── UI ────────────────────────────────────────────────────────
    private let containerView  = UIView()
    private let handleBar      = UIView()
    private let titleLabel     = UILabel()
    private let speedLabel     = UILabel()
    private let slider         = UISlider()
    private let presetStack    = UIStackView()
    private let doneButton     = UIButton(type: .system)

    private let presets: [(label: String, value: Double)] = [
        ("0.5×", 0.5), ("0.75×", 0.75), ("1.0×", 1.0),
        ("1.25×", 1.25), ("1.5×", 1.5), ("2.0×", 2.0)
    ]

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
        syncUI(speed: currentSpeed)
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
            containerView.heightAnchor.constraint(equalToConstant: 320),
        ])

        // ドラッグで閉じるジェスチャー
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
        titleLabel.text          = "再生速度"
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

        // ── スライダー ────────────────────────────────────────────
        slider.minimumValue         = 0.5
        slider.maximumValue         = 2.0
        slider.minimumTrackTintColor = AppColor.accent
        slider.maximumTrackTintColor = AppColor.separator
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(slider)

        // ── プリセットボタン群 ────────────────────────────────────
        presetStack.axis         = .horizontal
        presetStack.distribution = .fillEqually
        presetStack.spacing      = 8
        presetStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(presetStack)

        for preset in presets {
            let btn = makePresetButton(title: preset.label, value: preset.value)
            presetStack.addArrangedSubview(btn)
        }

        // ── 完了ボタン ────────────────────────────────────────────
        doneButton.setTitle("完了", for: .normal)
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

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            speedLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            speedLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            slider.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 12),
            slider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            slider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            presetStack.topAnchor.constraint(equalTo: slider.bottomAnchor, constant: 20),
            presetStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            presetStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            presetStack.heightAnchor.constraint(equalToConstant: 40),

            doneButton.topAnchor.constraint(equalTo: presetStack.bottomAnchor, constant: 20),
            doneButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
        ])
    }

    private func makePresetButton(title: String, value: Double) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font   = AppFont.footnote
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth  = 1
        btn.tag = Int(value * 100)   // 速度を整数タグとして保持
        btn.addTarget(self, action: #selector(presetTapped(_:)), for: .touchUpInside)
        return btn
    }

    // ── 状態同期 ──────────────────────────────────────────────────
    private func syncUI(speed: Double) {
        currentSpeed = speed
        speedLabel.text = String(format: "%.2g×", speed)
        slider.value = Float(speed)

        for view in presetStack.arrangedSubviews {
            guard let btn = view as? UIButton else { continue }
            let presetValue = Double(btn.tag) / 100.0
            let isSelected = abs(presetValue - speed) < 0.01
            btn.backgroundColor    = isSelected ? AppColor.accent : AppColor.surfaceSecondary
            btn.setTitleColor(isSelected ? .white : AppColor.textPrimary, for: .normal)
            btn.layer.borderColor  = isSelected ? AppColor.accent.cgColor : AppColor.border.cgColor
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
        delegate?.speedSheet(self, didSelectSpeed: currentSpeed)
        dismiss()
    }

    @objc private func sliderChanged() {
        // 0.05 刻みにスナップ
        let snapped = (Double(slider.value) * 20).rounded() / 20
        syncUI(speed: snapped)
    }

    @objc private func presetTapped(_ sender: UIButton) {
        let speed = Double(sender.tag) / 100.0
        syncUI(speed: speed)
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
