//
//  RemoveADViewController.swift
//  musica
//
//  広告削除 / プレミアムプラン購入画面
//  旧 Storyboard ビューを非表示にしてプログラマティック UI で全面リデザイン
//

import UIKit
import SwiftyStoreKit

class RemoveADViewController: UIViewController {

    // ── Storyboard IBOutlets (非表示にして新 UI に置き換え) ──────────
    @IBOutlet weak var ruleKakin: UITextView!
    @IBOutlet weak var waitView: UIView!
    @IBOutlet weak var optionTextView: UITextView!
    @IBOutlet weak var removeADBtn: UIButton!

    // ── New UI ────────────────────────────────────────────────────
    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    // ── Lifecycle ─────────────────────────────────────────────────
    override func viewDidLoad() {
        super.viewDidLoad()
        title = localText(key: "premium_title")
        view.backgroundColor = AppColor.background
        UserDefaults.standard.set("true", forKey: "kakinn_tap")

        navigationItem.rightBarButtonItem = nil

        // Storyboard の全 subview（outlet 非接続のものも含む）を一括非表示
        view.subviews.forEach { $0.isHidden = true }

        buildUI()

        // waitView を最前面に保持（購入中ローディング用）
        view.bringSubviewToFront(waitView)
        waitView.isHidden = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        selectMusicView.isHidden = true
    }

    // ── UI 構築 ────────────────────────────────────────────────────
    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // ── ヒーローセクション ──────────────────────────────────
        let heroIcon = makeSymbolView(name: "sparkles", size: 44, color: AppColor.accent)

        let heroTitle = makeLabel(
            localText(key: "premium_hero_title"),
            font: .systemFont(ofSize: 22, weight: .bold),
            color: AppColor.textPrimary, lines: 0, align: .center
        )

        let heroSub = makeLabel(
            localText(key: "premium_hero_sub"),
            font: .systemFont(ofSize: 15, weight: .regular),
            color: AppColor.textSecondary, lines: 0, align: .center
        )

        // ── 特典カード ──────────────────────────────────────────
        let benefitsCard = makeSectionCard(title: localText(key: "premium_benefits_header"), items: [
            ("nosign",         localText(key: "premium_benefit1_label"), localText(key: "premium_benefit1_sub")),
            ("waveform",       localText(key: "premium_benefit2_label"), localText(key: "premium_benefit2_sub")),
            ("music.note",     localText(key: "premium_benefit3_label"), localText(key: "premium_benefit3_sub")),
            ("arrow.clockwise",localText(key: "premium_benefit4_label"), localText(key: "premium_benefit4_sub")),
        ])

        // ── 料金カード ─────────────────────────────────────────
        let priceCard = makePriceCard()

        // ── CTA ボタン ─────────────────────────────────────────
        let purchaseBtn = UIButton(type: .system)
        purchaseBtn.setTitle(localText(key: "premium_cta"), for: .normal)
        purchaseBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        purchaseBtn.setTitleColor(.white, for: .normal)
        purchaseBtn.backgroundColor = AppColor.accent
        purchaseBtn.layer.cornerRadius = 16
        purchaseBtn.layer.shadowColor   = AppColor.accent.cgColor
        purchaseBtn.layer.shadowOpacity = 0.35
        purchaseBtn.layer.shadowRadius  = 10
        purchaseBtn.layer.shadowOffset  = CGSize(width: 0, height: 4)
        purchaseBtn.translatesAutoresizingMaskIntoConstraints = false
        purchaseBtn.addTarget(self, action: #selector(removeADBtnTapped(_:)), for: .touchUpInside)

        let restoreBtn = UIButton(type: .system)
        restoreBtn.setTitle(localText(key: "premium_restore"), for: .normal)
        restoreBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        restoreBtn.setTitleColor(AppColor.textSecondary, for: .normal)
        restoreBtn.translatesAutoresizingMaskIntoConstraints = false
        restoreBtn.addTarget(self, action: #selector(restoreBtnTapped(_:)), for: .touchUpInside)

        // ── 利用規約・プライバシーポリシー ─────────────────────
        let termsBtn = UIButton(type: .system)
        termsBtn.setTitle(localText(key: "premium_terms"), for: .normal)
        termsBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)
        termsBtn.setTitleColor(AppColor.textSecondary, for: .normal)
        termsBtn.translatesAutoresizingMaskIntoConstraints = false
        termsBtn.addTarget(self, action: #selector(termsPPBtnTapped(_:)), for: .touchUpInside)

        // ── 法的注記（Apple 必須開示） ─────────────────────────
        let legalLabel = makeLabel(
            localText(key: "premium_legal"),
            font: .systemFont(ofSize: 11, weight: .regular),
            color: AppColor.textSecondary.withAlphaComponent(0.7), lines: 0, align: .left
        )

        // ── スタック組み立て ────────────────────────────────────
        let stack = UIStackView(arrangedSubviews: [
            heroIcon, heroTitle, heroSub,
            benefitsCard,
            priceCard,
            purchaseBtn,
            restoreBtn,
            termsBtn,
            legalLabel,
        ])
        stack.axis    = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(12, after: heroIcon)
        stack.setCustomSpacing(8,  after: heroTitle)
        stack.setCustomSpacing(24, after: heroSub)
        stack.setCustomSpacing(12, after: benefitsCard)
        stack.setCustomSpacing(24, after: priceCard)
        stack.setCustomSpacing(10, after: purchaseBtn)
        stack.setCustomSpacing(4,  after: restoreBtn)
        stack.setCustomSpacing(16, after: termsBtn)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            purchaseBtn.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // ── ファクトリ ────────────────────────────────────────────────

    private func makeLabel(_ text: String, font: UIFont, color: UIColor, lines: Int, align: NSTextAlignment) -> UILabel {
        let l = UILabel()
        l.text          = text
        l.font          = font
        l.textColor     = color
        l.numberOfLines = lines
        l.textAlignment = align
        return l
    }

    private func makeSymbolView(name: String, size: CGFloat, color: UIColor) -> UIView {
        let wrapper = UIView()
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        let iv  = UIImageView(image: UIImage(systemName: name, withConfiguration: cfg)?
            .withTintColor(color, renderingMode: .alwaysOriginal))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
            iv.topAnchor.constraint(equalTo: wrapper.topAnchor),
            iv.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            iv.heightAnchor.constraint(equalToConstant: size + 8),
        ])
        return wrapper
    }

    private func makeSectionCard(title: String, items: [(icon: String, label: String, sub: String)]) -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 18
        card.clipsToBounds      = true

        let headerLabel = makeLabel(title,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: AppColor.textSecondary, lines: 1, align: .left)

        var rows: [UIView] = [headerLabel]
        for (i, item) in items.enumerated() {
            rows.append(makeBenefitRow(icon: item.icon, label: item.label, sub: item.sub))
            if i < items.count - 1 {
                let sep = UIView()
                sep.backgroundColor = AppColor.separator
                sep.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([sep.heightAnchor.constraint(equalToConstant: 0.5)])
                rows.append(sep)
            }
        }

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis    = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(16, after: headerLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    private func makeBenefitRow(icon: String, label: String, sub: String) -> UIView {
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iv  = UIImageView(image: UIImage(systemName: icon, withConfiguration: cfg)?
            .withTintColor(AppColor.accent, renderingMode: .alwaysOriginal))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 28),
            iv.heightAnchor.constraint(equalToConstant: 28),
        ])

        let titleLbl = makeLabel(label, font: .systemFont(ofSize: 15, weight: .semibold),
                                 color: AppColor.textPrimary, lines: 1, align: .left)
        let subLbl   = makeLabel(sub,   font: .systemFont(ofSize: 12, weight: .regular),
                                 color: AppColor.textSecondary, lines: 0, align: .left)

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subLbl])
        textStack.axis    = .vertical
        textStack.spacing = 2

        let row = UIStackView(arrangedSubviews: [iv, textStack])
        row.axis      = .horizontal
        row.spacing   = 14
        row.alignment = .center
        return row
    }

    private func makePriceCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.accentMuted
        card.layer.cornerRadius = 18

        // 価格: App Store から取得した localizedPrice を優先、未取得なら fallback
        let priceText = KAKIN_PRICE_STRING.isEmpty
            ? localText(key: "premium_price_fallback")
            : String(format: localText(key: "premium_price_fmt"), KAKIN_PRICE_STRING)
        let priceLbl = makeLabel(
            priceText,
            font: .systemFont(ofSize: 24, weight: .bold),
            color: AppColor.textPrimary, lines: 1, align: .center
        )

        let subLbl = makeLabel(
            localText(key: "premium_price_sub"),
            font: .systemFont(ofSize: 13, weight: .regular),
            color: AppColor.textSecondary, lines: 1, align: .center
        )

        let stack = UIStackView(arrangedSubviews: [priceLbl, subLbl])
        stack.axis    = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    // ── IBActions (旧ボタンのセグエも含め既存コードと共用) ────────────

    @IBAction func termsPPBtnTapped(_ sender: Any) {
        site = PP_TITLE
        performSegue(withIdentifier: "toPp", sender: "")
    }

    @IBAction func removeADBtnTapped(_ sender: Any) {
        waitView.isHidden = false
        showKakinAlert()
    }

    @IBAction func restoreBtnTapped(_ sender: Any) {
        waitView.isHidden = false
        SwiftyStoreKit.restorePurchases(atomically: true) { result in
            for product in result.restoredPurchases {
                if product.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(product.transaction)
                }
            }
            self.waitView.isHidden = true
            if result.restoredPurchases.count > 0 {
                KAKIN_FLG = true
                UserDefaults.standard.set(KAKIN_FLG, forKey: "kakin")
                UserDefaults.standard.synchronize()
                deleteAD()
                let alert = UIAlertController(
                    title: localText(key: "kakin_restore"),
                    message: "",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default) { _ in softwareReset() })
                getForegroundViewController().present(alert, animated: true)
            } else {
                let alert = UIAlertController(
                    title: localText(key: "kakin_restore_fail_title"),
                    message: localText(key: "kakin_restore_fail_body"),
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: MESSAGE_OK, style: .default))
                getForegroundViewController().present(alert, animated: true)
            }
        }
    }

    // ── 課金処理 ──────────────────────────────────────────────────

    func showKakinAlert() {
        if ADApearFlg() == false {
            purchase(PRODUCT_ID: "kuriFCTmusica")
        } else {
            let priceNote = KAKIN_PRICE_STRING.isEmpty ? "" : String(format: localText(key: "premium_alert_price_fmt"), KAKIN_PRICE_STRING)
            let alert = UIAlertController(
                title: localText(key: "premium_alert_title"),
                message: priceNote,
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: MESSAGE_YES, style: .default) { _ in
                self.purchase(PRODUCT_ID: "kuriFCTmusica")
            })
            alert.addAction(UIAlertAction(title: MESSAGE_CANCEL, style: .default) { _ in
                DispatchQueue.main.async { self.waitView.isHidden = true }
            })
            present(alert, animated: true)
        }
    }

    func purchase(PRODUCT_ID: String) {
        SwiftyStoreKit.purchaseProduct(PRODUCT_ID, quantity: 1, atomically: true) { result in
            switch result {
            case .success:
                self.verifyPurchase(PRODUCT_ID: PRODUCT_ID)
            case .error:
                DispatchQueue.main.async { self.waitView.isHidden = true }
            }
        }
    }

    func verifyPurchase(PRODUCT_ID: String) {
        var successFlg = false
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: SECRET_CODE)
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            switch result {
            case .success(let receipt):
                let purchaseResult = SwiftyStoreKit.verifySubscription(
                    ofType: .autoRenewable,
                    productId: PRODUCT_ID,
                    inReceipt: receipt)
                switch purchaseResult {
                case .purchased:
                    successFlg = true
                    deleteAD()
                    KAKIN_FLG = true
                    settingSectionTitle = settingSectionTitle_kakin
                    settingSectionData  = settingSectionData_kakin
                case .notPurchased:
                    successFlg = false
                default: break
                }
            case .error:
                successFlg = false
            }
            if successFlg {
                KAKIN_FLG = true
                UserDefaults.standard.set(KAKIN_FLG, forKey: "kakin")
                UserDefaults.standard.synchronize()
                deleteAD()
                softwareReset()
            }
            DispatchQueue.main.async { self.waitView.isHidden = true }
        }
    }
}
