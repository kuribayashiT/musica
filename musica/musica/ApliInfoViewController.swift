//
//  ApliInfoViewController.swift
//  musica
//
//  アプリについて画面 — バージョン情報 + ライセンス表示
//

import UIKit

class ApliInfoViewController: UIViewController {

    // Storyboard IBOutlet（非表示にして新 UI に置き換え）
    @IBOutlet weak var vertionLabel: UILabel!

    private let scrollView  = UIScrollView()
    private let contentView = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = APP_INFO
        view.backgroundColor = AppColor.background
        // Storyboard の全 subview（outlet 未接続含む）を一括非表示
        view.subviews.forEach { $0.isHidden = true }
        buildUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        selectMusicView.isHidden = true
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
            appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: darkModeLabelColor()]
            navigationController?.navigationBar.standardAppearance  = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
            navigationController?.navigationBar.tintColor = AppColor.accent
        } else {
            navigationController?.navigationBar.barTintColor = NAVIGATION_COLOR[NOW_COLOR_THEMA][COLOR_THEMA.SETTING.rawValue]
            navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: darkModeLabelColor()]
            navigationController?.navigationBar.tintColor = AppColor.accent
        }
    }

    // MARK: - UI

    private func buildUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints  = false
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

        // ── ヒーロー ──────────────────────────────────────────────
        let heroCard = makeHeroCard()

        // ── アプリ情報 ────────────────────────────────────────────
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build   = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        let infoCard = makeInfoCard(rows: [
            ("バージョン",    "\(version) (\(build))"),
            ("対応OS",        "iOS 13.0 以上"),
            ("カテゴリ",      "教育 / 語学学習"),
        ])

        // ── オープンソースライセンス ───────────────────────────────
        let licenseHeader = makeSectionHeader("オープンソースライセンス")
        let licenseCard   = makeLicenseCard()

        // ── スタック ─────────────────────────────────────────────
        let stack = UIStackView(arrangedSubviews: [heroCard, infoCard, licenseHeader, licenseCard])
        stack.axis    = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(20, after: heroCard)
        stack.setCustomSpacing(4,  after: infoCard)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
        ])
    }

    // MARK: - Factory

    private func makeHeroCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 20

        // アイコン（AppIcon があれば使用、なければ SF Symbol）
        let iconView = UIImageView()
        if let icon = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") {
            iconView.image           = icon
            iconView.layer.cornerRadius = 18
            iconView.clipsToBounds   = true
        } else {
            let cfg = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
            iconView.image     = UIImage(systemName: "music.note", withConfiguration: cfg)?
                .withTintColor(AppColor.accent, renderingMode: .alwaysOriginal)
            iconView.contentMode = .scaleAspectFit
        }
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text      = "musica"
        nameLabel.font      = .systemFont(ofSize: 22, weight: .bold)
        nameLabel.textColor = AppColor.textPrimary

        let subLabel = UILabel()
        subLabel.text      = "英語ディクテーション練習"
        subLabel.font      = .systemFont(ofSize: 13, weight: .regular)
        subLabel.textColor = AppColor.textSecondary

        let textStack = UIStackView(arrangedSubviews: [nameLabel, subLabel])
        textStack.axis    = .vertical
        textStack.spacing = 3

        let row = UIStackView(arrangedSubviews: [iconView, textStack])
        row.axis      = .horizontal
        row.spacing   = 16
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])
        return card
    }

    private func makeInfoCard(rows: [(String, String)]) -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 16

        var views: [UIView] = []
        for (i, row) in rows.enumerated() {
            let rowView = makeInfoRow(label: row.0, value: row.1)
            views.append(rowView)
            if i < rows.count - 1 {
                let sep = UIView()
                sep.backgroundColor = AppColor.separator
                sep.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([sep.heightAnchor.constraint(equalToConstant: 0.5)])
                views.append(sep)
            }
        }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis    = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func makeInfoRow(label: String, value: String) -> UIView {
        let lbl = UILabel()
        lbl.text      = label
        lbl.font      = .systemFont(ofSize: 14, weight: .regular)
        lbl.textColor = AppColor.textSecondary

        let val = UILabel()
        val.text          = value
        val.font          = .systemFont(ofSize: 14, weight: .medium)
        val.textColor     = AppColor.textPrimary
        val.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [lbl, val])
        row.axis         = .horizontal
        row.distribution = .equalSpacing
        row.layoutMargins = UIEdgeInsets(top: 13, left: 16, bottom: 13, right: 16)
        row.isLayoutMarginsRelativeArrangement = true
        return row
    }

    private func makeSectionHeader(_ text: String) -> UIView {
        let label = UILabel()
        label.text      = text.uppercased()
        label.font      = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = AppColor.textSecondary
        let wrapper = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -4),
        ])
        return wrapper
    }

    private func makeLicenseCard() -> UIView {
        let libraries: [(name: String, license: String)] = [
            // Swift Package Manager
            ("WhisperKit",                    "MIT"),
            ("swift-transformers",            "Apache 2.0"),
            ("swift-jinja",                   "Apache 2.0"),
            ("swift-collections",             "Apache 2.0"),
            ("swift-crypto",                  "Apache 2.0"),
            ("swift-asn1",                    "Apache 2.0"),
            ("swift-argument-parser",         "Apache 2.0"),
            ("yyjson",                        "MIT"),
            // CocoaPods
            ("Alamofire",                     "MIT"),
            ("BubbleTransition",              "MIT"),
            ("DGElasticPullToRefresh",        "MIT"),
            ("Firebase (Google)",             "Apache 2.0"),
            ("Google Mobile Ads SDK",         "Google Terms"),
            ("Instructions",                  "Apache 2.0"),
            ("MultiSlider",                   "MIT"),
            ("RAMAnimatedTabBarController",   "MIT"),
            ("ReachabilitySwift",             "MIT"),
            ("SDWebImage",                    "MIT"),
            ("SlideMenuControllerSwift",      "MIT"),
            ("SwiftEntryKit",                 "MIT"),
            ("SwiftyJSON",                    "MIT"),
            ("SwiftyStoreKit",                "MIT"),
            ("SWTableViewCell",               "MIT"),
            ("TransitionableTab",             "MIT"),
            ("XCDYouTubeKit",                 "MIT"),
            ("YoutubePlayer-in-WKWebView",    "MIT"),
        ]

        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 16
        card.clipsToBounds      = true

        var views: [UIView] = []
        for (i, lib) in libraries.enumerated() {
            let row = makeLicenseRow(name: lib.name, license: lib.license)
            views.append(row)
            if i < libraries.count - 1 {
                let sep = UIView()
                sep.backgroundColor = AppColor.separator
                sep.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([sep.heightAnchor.constraint(equalToConstant: 0.5)])
                views.append(sep)
            }
        }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis    = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
        return card
    }

    private func makeLicenseRow(name: String, license: String) -> UIView {
        let nameLbl = UILabel()
        nameLbl.text      = name
        nameLbl.font      = .systemFont(ofSize: 13, weight: .regular)
        nameLbl.textColor = AppColor.textPrimary

        let badge = UILabel()
        badge.text            = license
        badge.font            = .systemFont(ofSize: 11, weight: .medium)
        badge.textColor       = AppColor.textSecondary
        badge.textAlignment   = .right

        let row = UIStackView(arrangedSubviews: [nameLbl, badge])
        row.axis         = .horizontal
        row.distribution = .equalSpacing
        row.alignment    = .center
        row.layoutMargins = UIEdgeInsets(top: 11, left: 16, bottom: 11, right: 16)
        row.isLayoutMarginsRelativeArrangement = true
        return row
    }
}
