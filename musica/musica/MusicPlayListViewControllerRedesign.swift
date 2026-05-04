//
//  MusicPlayListViewControllerRedesign.swift
//  musica
//
//  ライブラリ画面の上部ミニプレイヤーをフローティングカードスタイルに刷新。
//  カード内部にアルバムアート＋ブラーを閉じ込め、角丸でクリップする。
//

import UIKit

extension MusicPlayListViewController {

    // MARK: - Entry Point

    func redesignMiniPlayer() {
        // 旧プレイヤーコンテナをまるごと非表示
        // (テーブルの top 制約は NHt.bottom を参照しているため、
        //  isHidden = true でも Auto Layout の位置計算は維持される)
        if let container = oldPlayerContainer() {
            container.isHidden = true
        }
        buildMiniPlayerCard()
    }

    // MARK: - Build Card

    func buildMiniPlayerCard() {
        // ── シャドウラッパー（clipsToBounds=false でシャドウを描画） ────
        let shadowWrap = UIView()
        shadowWrap.backgroundColor = .clear
        shadowWrap.layer.cornerRadius  = 16
        shadowWrap.layer.shadowColor   = UIColor.black.cgColor
        shadowWrap.layer.shadowOpacity = 0.22
        shadowWrap.layer.shadowRadius  = 12
        shadowWrap.layer.shadowOffset  = CGSize(width: 0, height: 4)
        shadowWrap.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shadowWrap)
        miniPlayerCardShadow = shadowWrap

        NSLayoutConstraint.activate([
            shadowWrap.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 7),
            shadowWrap.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            shadowWrap.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            shadowWrap.heightAnchor.constraint(equalToConstant: 76),
        ])

        // ── カード（clipsToBounds=true で角丸クリップ） ────────────────
        let card = UIView()
        card.backgroundColor     = AppColor.surface   // フォールバック
        card.layer.cornerRadius  = 16
        card.clipsToBounds       = true
        card.translatesAutoresizingMaskIntoConstraints = false
        shadowWrap.addSubview(card)
        miniPlayerCard = card

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: shadowWrap.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowWrap.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: shadowWrap.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowWrap.trailingAnchor),
        ])

        // ── 背景: アルバムアート（カード全面） ───────────────────────────
        let bgImg = UIImageView()
        bgImg.contentMode   = .scaleAspectFill
        bgImg.clipsToBounds = true
        bgImg.image         = UIImage(named: "onpu_BL")
        bgImg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bgImg)
        miniPlayerBgImageView = bgImg

        NSLayoutConstraint.activate([
            bgImg.topAnchor.constraint(equalTo: card.topAnchor),
            bgImg.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            bgImg.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bgImg.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])

        // ── ブラーオーバーレイ ────────────────────────────────────────────
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(blur)

        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: card.topAnchor),
            blur.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: card.trailingAnchor),
        ])

        // ── 以下コンテンツはすべてブラーより上（card の subview として追加）──

        // アクセントバー
        let accentBar = UIView()
        accentBar.backgroundColor    = AppColor.accent
        accentBar.layer.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(accentBar)

        // アートワークサムネイル
        let artView = UIImageView()
        artView.contentMode      = .center
        artView.clipsToBounds    = true
        artView.layer.cornerRadius = 10
        artView.backgroundColor  = AppColor.surfaceSecondary
        artView.image            = UIImage(named: "onpu_BL")
        artView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(artView)
        miniPlayerArtView = artView

        // タイトルラベル
        let titleLbl = UILabel()
        titleLbl.font          = .systemFont(ofSize: 14, weight: .semibold)
        titleLbl.textColor     = AppColor.textPrimary
        titleLbl.text          = NOT_PLAYING_TRACK_TITLE
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)
        miniPlayerTitleLabel = titleLbl

        // アーティストラベル
        let artistLbl = UILabel()
        artistLbl.font          = .systemFont(ofSize: 11, weight: .regular)
        artistLbl.textColor     = AppColor.textSecondary
        artistLbl.lineBreakMode = .byTruncatingTail
        artistLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(artistLbl)
        miniPlayerArtistLabel = artistLbl

        // 前へ / 再生・停止 / 次へ
        let prevBtn = makeMiniCtrlBtn(symbol: "backward.end.fill", size: 15,
                                     action: #selector(playBackBtnTapped(_:)))
        let ppBtn   = makeMiniPlayPauseBtn()
        let nextBtn = makeMiniCtrlBtn(symbol: "forward.end.fill",  size: 15,
                                     action: #selector(playNextBtnTapped(_:)))
        miniPlayerPlayPauseBtn = ppBtn

        let btnStack = UIStackView(arrangedSubviews: [prevBtn, ppBtn, nextBtn])
        btnStack.axis      = .horizontal
        btnStack.spacing   = 4
        btnStack.alignment = .center
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(btnStack)

        // Chevron（フルプレイヤーへ）
        let chevron = UIButton(type: .system)
        let chCfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        chevron.setImage(UIImage(systemName: "chevron.right", withConfiguration: chCfg), for: .normal)
        chevron.tintColor = AppColor.textSecondary
        chevron.addTarget(self, action: #selector(allowTapped(_:)), for: .touchUpInside)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(chevron)

        // ── 制約 ──────────────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            accentBar.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 4),
            accentBar.heightAnchor.constraint(equalToConstant: 28),

            artView.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            artView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            artView.widthAnchor.constraint(equalToConstant: 52),
            artView.heightAnchor.constraint(equalToConstant: 52),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 20),
            chevron.heightAnchor.constraint(equalToConstant: 44),

            btnStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -6),
            btnStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            titleLbl.leadingAnchor.constraint(equalTo: artView.trailingAnchor, constant: 12),
            titleLbl.trailingAnchor.constraint(equalTo: btnStack.leadingAnchor, constant: -8),
            titleLbl.bottomAnchor.constraint(equalTo: card.centerYAnchor, constant: 1),

            artistLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            artistLbl.trailingAnchor.constraint(equalTo: titleLbl.trailingAnchor),
            artistLbl.topAnchor.constraint(equalTo: card.centerYAnchor, constant: 4),
        ])
    }

    // MARK: - Button Helpers

    private func makeMiniCtrlBtn(symbol: String, size: CGFloat, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        btn.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
        btn.tintColor = AppColor.textPrimary
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 36),
            btn.heightAnchor.constraint(equalToConstant: 36),
        ])
        return btn
    }

    private func makeMiniPlayPauseBtn() -> UIButton {
        let btn = UIButton(type: .system)
        btn.backgroundColor     = AppColor.accent
        btn.tintColor           = .white
        btn.layer.cornerRadius  = 19
        btn.layer.masksToBounds = true
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        btn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(playBtnTapped(_:)), for: .touchUpInside)
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 38),
            btn.heightAnchor.constraint(equalToConstant: 38),
        ])
        return btn
    }

    // MARK: - Sync

    func syncMiniPlayerCard(artworkImg: UIImage?, title: String, artist: String, isPlaying: Bool) {
        // サムネイル
        if let img = artworkImg {
            miniPlayerArtView?.image       = img
            miniPlayerArtView?.contentMode = .scaleAspectFill
        } else {
            miniPlayerArtView?.image       = UIImage(named: "onpu_BL")
            miniPlayerArtView?.contentMode = .center
        }
        miniPlayerTitleLabel?.text  = title
        miniPlayerArtistLabel?.text = artist

        // 再生/停止アイコン
        let icnCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        miniPlayerPlayPauseBtn?.setImage(
            UIImage(systemName: isPlaying ? "pause.fill" : "play.fill", withConfiguration: icnCfg),
            for: .normal
        )

        // カード内背景アートをクロスフェード
        guard let bgView = miniPlayerBgImageView else { return }
        UIView.transition(with: bgView, duration: 0.35, options: .transitionCrossDissolve) {
            bgView.image = artworkImg ?? UIImage(named: "onpu_BL")
        }
    }

    func resetMiniPlayerCard() {
        syncMiniPlayerCard(artworkImg: nil,
                           title: NOT_PLAYING_TRACK_TITLE,
                           artist: "",
                           isPlaying: false)
    }

    // MARK: - Private Helper

    private func oldPlayerContainer() -> UIVisualEffectView? {
        view.subviews
            .compactMap { $0 as? UIVisualEffectView }
            .first { $0.frame.height > 0 && $0.frame.height <= 100 }
    }
}
