//
//  MVHowToViewController.swift
//  musica
//
//  お気に入り動画の使い方をステップ形式で説明するボトムシート。
//  PlayMVViewController の「？」ボタンから表示される。
//

import UIKit

class MVHowToViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        setupScrollView()
        setupContent()
    }

    // MARK: - Layout

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    private func setupContent() {
        // ── タイトル ──────────────────────────────────────────────────
        let titleLabel = makeLabel(
            text: localText(key: "mv_howto_title"),
            font: UIFont.systemFont(ofSize: 20, weight: .bold),
            color: AppColor.textPrimary,
            lines: 1
        )

        let subtitleLabel = makeLabel(
            text: localText(key: "mv_howto_subtitle"),
            font: UIFont.systemFont(ofSize: 14, weight: .regular),
            color: AppColor.textSecondary,
            lines: 0
        )

        // ── ステップカード ────────────────────────────────────────────
        let step1 = makeStepCard(
            number: "1",
            icon: "safari",
            title: localText(key: "mv_howto_step1_title"),
            body: localText(key: "mv_howto_step1_body"),
            accent: AppColor.accent
        )

        let step2 = makeStepCard(
            number: "2",
            icon: "plus",
            title: localText(key: "mv_howto_step2_title"),
            body: localText(key: "mv_howto_step2_body"),
            accent: AppColor.accent
        )

        let step3 = makeStepCard(
            number: "3",
            icon: "text.quote",
            title: localText(key: "mv_howto_step3_title"),
            body: localText(key: "mv_howto_step3_body"),
            accent: AppColor.accent
        )

        let step4 = makeStepCard(
            number: "4",
            icon: "waveform",
            title: localText(key: "mv_howto_step4_title"),
            body: localText(key: "mv_howto_step4_body"),
            accent: AppColor.accent
        )

        // ── ヒントカード ──────────────────────────────────────────────
        let tipCard = makeTipCard(
            text: localText(key: "mv_howto_tip")
        )

        // ── 閉じるボタン ─────────────────────────────────────────────
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle(localText(key: "btn_close"), for: .normal)
        closeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.backgroundColor = AppColor.accent
        closeBtn.layer.cornerRadius = 14
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        // ── スタック組み立て ──────────────────────────────────────────
        let stack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel,
            step1, step2, step3, step4,
            tipCard, closeBtn
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
            closeBtn.heightAnchor.constraint(equalToConstant: 50),
        ])
    }

    // MARK: - Factory Methods

    private func makeLabel(text: String, font: UIFont, color: UIColor, lines: Int) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font
        l.textColor = color
        l.numberOfLines = lines
        return l
    }

    private func makeStepCard(number: String, icon: String, title: String, body: String, accent: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor = AppColor.surface
        card.layer.cornerRadius = 16
        card.layer.masksToBounds = true

        // 左のアクセントバー
        let bar = UIView()
        bar.backgroundColor = accent
        bar.layer.cornerRadius = 2
        bar.translatesAutoresizingMaskIntoConstraints = false

        // 番号バッジ
        let badge = UILabel()
        badge.text = number
        badge.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = accent
        badge.layer.cornerRadius = 12
        badge.layer.masksToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        // アイコン
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // タイトル
        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = AppColor.textPrimary

        // ヘッダーStack（バッジ＋アイコン＋タイトル）
        let headerStack = UIStackView(arrangedSubviews: [badge, iconView, titleLbl])
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center

        // 本文
        let bodyLbl = UILabel()
        bodyLbl.text = body
        bodyLbl.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        bodyLbl.textColor = AppColor.textSecondary
        bodyLbl.numberOfLines = 0

        let contentStack = UIStackView(arrangedSubviews: [headerStack, bodyLbl])
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(bar)
        card.addSubview(contentStack)

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bar.topAnchor.constraint(equalTo: card.topAnchor),
            bar.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            bar.widthAnchor.constraint(equalToConstant: 4),

            badge.widthAnchor.constraint(equalToConstant: 24),
            badge.heightAnchor.constraint(equalToConstant: 24),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeTipCard(text: String) -> UIView {
        let card = UIView()
        card.backgroundColor = AppColor.accentMuted
        card.layer.cornerRadius = 14

        let lbl = UILabel()
        lbl.text = text
        lbl.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        lbl.textColor = AppColor.textPrimary
        lbl.numberOfLines = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)

        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            lbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            lbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        return card
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}
