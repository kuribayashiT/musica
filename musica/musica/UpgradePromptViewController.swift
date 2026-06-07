//
//  UpgradePromptViewController.swift
//  musica
//
//  機能制限・完了後に表示するアップグレード促進ボトムシート。
//  RemoveADViewController へ誘導する軽量モーダル。
//

import UIKit

enum UpgradePromptContext {
    case dictationLimitReached   // 制限到達
    case dictationCompleted      // 完了後の促進（初回）
    case flashCardLimitReached   // フラッシュカード制限
    case flashCardCompleted      // フラッシュカード完了後
}

final class UpgradePromptViewController: UIViewController {

    var context: UpgradePromptContext = .dictationCompleted
    var onDismiss: (() -> Void)?

    // MARK: - UI

    private let grabber     = UIView()
    private let iconLabel   = UILabel()
    private let titleLabel  = UILabel()
    private let subLabel    = UILabel()
    private let benefitStack = UIStackView()
    private let upgradeBtn  = UIButton(type: .system)
    private let laterBtn    = UIButton(type: .system)
    private let card        = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        setupLayout()
        configureForContext()

        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        card.transform = CGAffineTransform(translationX: 0, y: 300)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5) {
            self.card.transform = .identity
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        // Card
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 24
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Grabber
        grabber.backgroundColor    = AppColor.separator
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(grabber)
        NSLayoutConstraint.activate([
            grabber.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            grabber.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
        ])

        // Icon
        iconLabel.font          = .systemFont(ofSize: 48)
        iconLabel.textAlignment = .center
        iconLabel.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.font          = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Sub
        subLabel.font          = .systemFont(ofSize: 14, weight: .regular)
        subLabel.textColor     = AppColor.textSecondary
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 0
        subLabel.translatesAutoresizingMaskIntoConstraints = false

        // Benefits stack
        benefitStack.axis    = .vertical
        benefitStack.spacing = 10
        benefitStack.translatesAutoresizingMaskIntoConstraints = false

        // Upgrade button
        upgradeBtn.titleLabel?.font  = .systemFont(ofSize: 17, weight: .bold)
        upgradeBtn.setTitleColor(.white, for: .normal)
        upgradeBtn.backgroundColor   = AppColor.accent
        upgradeBtn.layer.cornerRadius = 16
        upgradeBtn.layer.shadowColor   = AppColor.accent.cgColor
        upgradeBtn.layer.shadowOpacity = 0.35
        upgradeBtn.layer.shadowRadius  = 8
        upgradeBtn.layer.shadowOffset  = CGSize(width: 0, height: 4)
        upgradeBtn.translatesAutoresizingMaskIntoConstraints = false
        upgradeBtn.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)

        // Later button
        laterBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        laterBtn.setTitleColor(AppColor.textSecondary, for: .normal)
        laterBtn.setTitle(localText(key: "upgrade_later"), for: .normal)
        laterBtn.translatesAutoresizingMaskIntoConstraints = false
        laterBtn.addTarget(self, action: #selector(laterTapped), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [
            iconLabel, titleLabel, subLabel, benefitStack, upgradeBtn, laterBtn
        ])
        contentStack.axis    = .vertical
        contentStack.spacing = 14
        contentStack.setCustomSpacing(8,  after: iconLabel)
        contentStack.setCustomSpacing(6,  after: titleLabel)
        contentStack.setCustomSpacing(20, after: subLabel)
        contentStack.setCustomSpacing(24, after: benefitStack)
        contentStack.setCustomSpacing(10, after: upgradeBtn)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: card.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            upgradeBtn.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func configureForContext() {
        switch context {
        case .dictationLimitReached:
            iconLabel.text = "⏰"
            titleLabel.text = localText(key: "upgrade_dict_limit_title")
            subLabel.text   = localText(key: "upgrade_dict_limit_sub")
            upgradeBtn.setTitle(localText(key: "upgrade_dict_cta"), for: .normal)
            addBenefit(icon: "waveform.and.mic", text: localText(key: "upgrade_benefit_dict_unlimited"))
            addBenefit(icon: "rectangle.stack",  text: localText(key: "upgrade_benefit_flash_unlimited"))
            addBenefit(icon: "nosign",            text: localText(key: "upgrade_benefit_no_ads"))

        case .dictationCompleted:
            iconLabel.text = "🎉"
            titleLabel.text = localText(key: "upgrade_dict_done_title")
            subLabel.text   = localText(key: "upgrade_dict_done_sub")
            upgradeBtn.setTitle(localText(key: "upgrade_dict_done_cta"), for: .normal)
            let remaining = SubscriptionGate.shared.remainingDictations
            addBenefit(icon: "waveform.and.mic",
                       text: remaining > 0
                           ? String(format: localText(key: "upgrade_remaining_fmt"), remaining)
                           : localText(key: "upgrade_benefit_dict_unlimited"))
            addBenefit(icon: "rectangle.stack",  text: localText(key: "upgrade_benefit_flash_unlimited"))
            addBenefit(icon: "nosign",            text: localText(key: "upgrade_benefit_no_ads"))

        case .flashCardLimitReached:
            iconLabel.text = "🃏"
            titleLabel.text = localText(key: "upgrade_flash_limit_title")
            subLabel.text   = localText(key: "upgrade_flash_limit_sub")
            upgradeBtn.setTitle(localText(key: "upgrade_dict_cta"), for: .normal)
            addBenefit(icon: "rectangle.stack",  text: localText(key: "upgrade_benefit_flash_unlimited"))
            addBenefit(icon: "waveform.and.mic", text: localText(key: "upgrade_benefit_dict_unlimited"))
            addBenefit(icon: "nosign",            text: localText(key: "upgrade_benefit_no_ads"))

        case .flashCardCompleted:
            iconLabel.text = "✨"
            titleLabel.text = localText(key: "upgrade_flash_done_title")
            subLabel.text   = localText(key: "upgrade_flash_done_sub")
            upgradeBtn.setTitle(localText(key: "upgrade_dict_done_cta"), for: .normal)
            addBenefit(icon: "rectangle.stack",  text: localText(key: "upgrade_benefit_flash_unlimited"))
            addBenefit(icon: "waveform.and.mic", text: localText(key: "upgrade_benefit_dict_unlimited"))
            addBenefit(icon: "chart.bar.fill",   text: localText(key: "upgrade_benefit_history"))
        }
    }

    private func addBenefit(icon: String, text: String) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        let iv  = UIImageView(image: UIImage(systemName: icon, withConfiguration: cfg)?
            .withTintColor(AppColor.accent, renderingMode: .alwaysOriginal))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 22),
            iv.heightAnchor.constraint(equalToConstant: 22),
        ])

        let lbl = UILabel()
        lbl.text          = text
        lbl.font          = .systemFont(ofSize: 14, weight: .medium)
        lbl.textColor     = AppColor.textPrimary
        lbl.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [iv, lbl])
        row.axis      = .horizontal
        row.spacing   = 10
        row.alignment = .center
        benefitStack.addArrangedSubview(row)
    }

    // MARK: - Actions

    @objc private func upgradeTapped() {
        dismiss(animated: true) { [weak self] in
            let removeVC = RemoveADViewController()
            getForegroundViewController().navigationController?.pushViewController(removeVC, animated: true)
            self?.onDismiss?()
        }
    }

    @objc private func laterTapped() {
        dismiss(animated: true) { [weak self] in self?.onDismiss?() }
    }

    @objc private func backgroundTapped() {
        dismiss(animated: true) { [weak self] in self?.onDismiss?() }
    }
}

extension UpgradePromptViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == view
    }
}

// MARK: - Convenience

extension UIViewController {
    /// アップグレード促進シートをモーダル表示する
    func showUpgradePrompt(context: UpgradePromptContext, onDismiss: (() -> Void)? = nil) {
        guard !KAKIN_FLG else {
            onDismiss?()
            return
        }
        let vc = UpgradePromptViewController()
        vc.context   = context
        vc.onDismiss = onDismiss
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle   = .crossDissolve
        present(vc, animated: true)
    }
}
