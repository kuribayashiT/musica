//
//  PlayMusicViewControllerNewUI.swift
//  musica
//
//  再生画面 完全リデザイン — Apple Music テイスト
//

import UIKit

// MARK: - Spring Animation + Haptics Helper

extension UIView {
    /// Apple Music 風のスプリングタップアニメーション
    func springTap(scale: CGFloat = 0.88, completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.12,
            delay: 0,
            options: [.curveEaseIn, .allowUserInteraction]
        ) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.45,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 0.8,
                options: [.allowUserInteraction]
            ) {
                self.transform = .identity
            } completion: { _ in
                completion?()
            }
        }
    }
}

// MARK: - New Player UI

extension PlayMusicViewController {

    func buildNewPlayerUI() {
        hideOldUI()
        addBackgroundLayer()
        addPlayerCard()
        view.bringSubviewToFront(banner)
        // storyboard の adRemoveBtn は非表示にし nav bar で代替
        adRemoveBtn.isHidden = true
        setupAdRemoveBarItem()
    }

    private func setupAdRemoveBarItem() {
        let btn = UIButton(type: .system)
        btn.setTitle(localText(key: "ad_reward_title"), for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        btn.setTitleColor(AppColor.accent, for: .normal)
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        btn.addTarget(self, action: #selector(adRemoveBtnTapped(_:)), for: .touchUpInside)
        btn.sizeToFit()
        adRemoveBarItem = UIBarButtonItem(customView: btn)
        let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        space.width = 16
        adRemoveSpaceItem = space
        // 初期状態では追加しない — setAdRemoveBarItemVisible で動的に追加/削除する
    }

    func setAdRemoveBarItemVisible(_ visible: Bool) {
        guard let item = adRemoveBarItem, let space = adRemoveSpaceItem else { return }
        var items = navigationItem.rightBarButtonItems ?? []
        let alreadyShown = items.contains(item)
        if visible && !alreadyShown {
            items.append(space)
            items.append(item)
            navigationItem.rightBarButtonItems = items
        } else if !visible && alreadyShown {
            items.removeAll { $0 === item || $0 === space }
            navigationItem.rightBarButtonItems = items
        }
    }

    func hideOldUI() {
        musicControllerView.isHidden = true
        MusicArtWorkView.isHidden = true
        LyricView.isHidden = true
        LyricBGView.isHidden = true
        lyricSegmentetion.isHidden = true
        // banner は非表示にしない（広告は常に最前面に残す）
        shadowView.isHidden = true
    }

    func addBackgroundLayer() {
        let bgImageView = UIImageView()
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.clipsToBounds = true
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bgImageView, at: 0)
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: view.topAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        newBgImageView = bgImageView

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blurView, aboveSubview: bgImageView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func addPlayerCard() {
        // ── カード ────────────────────────────────────────────────
        let card = UIView()
        card.backgroundColor = AppColor.surface.withAlphaComponent(0.95)
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        newPlayerCard = card
        let cardTop = card.topAnchor.constraint(equalTo: view.topAnchor, constant: 0)
        newCardTopConstraint = cardTop
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            cardTop,
        ])

        // ── アートワーク/歌詞コンテナ ──────────────────────────────
        let contentContainer = UIView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentContainer)
        newContentContainer = contentContainer
        let contentTop = contentContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 0)
        newContentContainerTopConstraint = contentTop
        NSLayoutConstraint.activate([
            contentTop,
            contentContainer.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            contentContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            contentContainer.heightAnchor.constraint(equalTo: contentContainer.widthAnchor, multiplier: 1.15),
        ])

        // アートワーク（影あり）
        let shadowContainer = UIView()
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.layer.shadowColor  = UIColor.black.cgColor
        shadowContainer.layer.shadowOpacity = 0.5
        shadowContainer.layer.shadowRadius  = 24
        shadowContainer.layer.shadowOffset  = CGSize(width: 0, height: 8)
        contentContainer.addSubview(shadowContainer)
        NSLayoutConstraint.activate([
            shadowContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            shadowContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            shadowContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            shadowContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])

        let artworkView = UIImageView()
        artworkView.contentMode  = .scaleAspectFill
        artworkView.clipsToBounds = true
        artworkView.layer.cornerRadius = 18
        artworkView.backgroundColor = AppColor.surfaceSecondary
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.addSubview(artworkView)
        newArtworkView = artworkView
        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            artworkView.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor),
            artworkView.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            artworkView.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
        ])

        // 歌詞ビュー
        let lyricsView = UITextView()
        lyricsView.layer.cornerRadius = 18
        lyricsView.isHidden = true
        lyricsView.backgroundColor = AppColor.surfaceSecondary
        lyricsView.font = AppFont.body
        lyricsView.textColor = AppColor.textPrimary
        lyricsView.isEditable = false
        lyricsView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
        lyricsView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(lyricsView)
        newLyricsView = lyricsView
        NSLayoutConstraint.activate([
            lyricsView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            lyricsView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            lyricsView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            lyricsView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
        ])

        // ── 曲名/アーティスト + モードセグメント ─────────────────
        let titleLabel = UILabel()
        titleLabel.font          = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        newTitleLabel = titleLabel

        let artistLabel = UILabel()
        artistLabel.font      = .systemFont(ofSize: 16, weight: .medium)
        artistLabel.textColor = AppColor.textSecondary
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(artistLabel)
        newArtistLabel = artistLabel

        let modeSegment = UISegmentedControl(items: ["♩", "歌詞"])
        modeSegment.selectedSegmentIndex = 0
        modeSegment.selectedSegmentTintColor = AppColor.accent
        modeSegment.setTitleTextAttributes([.foregroundColor: AppColor.textPrimary], for: .normal)
        modeSegment.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        modeSegment.addTarget(self, action: #selector(newModeSwitched(_:)), for: .valueChanged)
        modeSegment.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(modeSegment)
        newModeSegment = modeSegment

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: modeSegment.leadingAnchor, constant: -12),

            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            artistLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            artistLabel.trailingAnchor.constraint(equalTo: modeSegment.leadingAnchor, constant: -12),

            modeSegment.centerYAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
            modeSegment.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            modeSegment.widthAnchor.constraint(equalToConstant: 80),
            modeSegment.heightAnchor.constraint(equalToConstant: 32),
        ])

        // ── プログレスバー（Apple Music スタイル） ────────────────
        let progressSlider = AMProgressSlider()
        progressSlider.minimumTrackTintColor = AppColor.accent
        progressSlider.maximumTrackTintColor = AppColor.textSecondary.withAlphaComponent(0.3)
        let thumbImg: UIImage = {
            let size = CGSize(width: 14, height: 14)
            return UIGraphicsImageRenderer(size: size).image { _ in
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            }
        }()
        let thumbImgLarge: UIImage = {
            let size = CGSize(width: 22, height: 22)
            return UIGraphicsImageRenderer(size: size).image { _ in
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
            }
        }()
        progressSlider.setThumbImage(thumbImg, for: .normal)
        progressSlider.setThumbImage(thumbImgLarge, for: .highlighted)
        progressSlider.addTarget(self, action: #selector(newProgressChanged(_:)), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(progressDragBegan(_:)), for: .touchDown)
        progressSlider.addTarget(self, action: #selector(progressDragEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        progressSlider.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(progressSlider)
        newProgressSlider = progressSlider

        let nowTimeLabel = UILabel()
        nowTimeLabel.font      = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        nowTimeLabel.textColor = AppColor.textSecondary
        nowTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nowTimeLabel)
        newNowTimeLabel = nowTimeLabel

        let totalTimeLabel = UILabel()
        totalTimeLabel.font      = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalTimeLabel.textColor = AppColor.textSecondary
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(totalTimeLabel)
        newTotalTimeLabel = totalTimeLabel

        // スクラブ中に中央表示する時刻ラベル（通常は非表示）
        let scrubTimeLabel = UILabel()
        scrubTimeLabel.font          = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        scrubTimeLabel.textColor     = AppColor.textPrimary
        scrubTimeLabel.textAlignment = .center
        scrubTimeLabel.alpha         = 1
        scrubTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(scrubTimeLabel)
        newScrubTimeLabel = scrubTimeLabel

        NSLayoutConstraint.activate([
            progressSlider.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 22),
            progressSlider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 28),
            progressSlider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -28),
            progressSlider.heightAnchor.constraint(equalToConstant: 44),

            nowTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 6),
            nowTimeLabel.leadingAnchor.constraint(equalTo: progressSlider.leadingAnchor),

            totalTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 6),
            totalTimeLabel.trailingAnchor.constraint(equalTo: progressSlider.trailingAnchor),

            scrubTimeLabel.centerXAnchor.constraint(equalTo: progressSlider.centerXAnchor),
            scrubTimeLabel.topAnchor.constraint(equalTo: progressSlider.bottomAnchor, constant: 4),
        ])

        // ── メインコントロール ─────────────────────────────────────
        let prevBtn = makeControlButton(
            symbol: "backward.end.fill", size: 26, weight: .medium,
            action: #selector(newPrevTapped)
        )
        newPrevBtn = prevBtn

        let playPauseBtn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)
        playPauseBtn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
        playPauseBtn.tintColor = .white
        playPauseBtn.backgroundColor = AppColor.accent
        playPauseBtn.layer.cornerRadius = 38
        playPauseBtn.layer.shadowColor  = AppColor.accent.cgColor
        playPauseBtn.layer.shadowOpacity = 0.4
        playPauseBtn.layer.shadowRadius  = 12
        playPauseBtn.layer.shadowOffset  = CGSize(width: 0, height: 4)
        playPauseBtn.translatesAutoresizingMaskIntoConstraints = false
        playPauseBtn.addTarget(self, action: #selector(newPlayPauseTapped), for: .touchUpInside)
        newPlayPauseBtn = playPauseBtn
        NSLayoutConstraint.activate([
            playPauseBtn.widthAnchor.constraint(equalToConstant: 76),
            playPauseBtn.heightAnchor.constraint(equalToConstant: 76),
        ])

        let nextBtn = makeControlButton(
            symbol: "forward.end.fill", size: 26, weight: .medium,
            action: #selector(newNextTapped)
        )
        newNextBtn = nextBtn

        let controlsStack = UIStackView(arrangedSubviews: [prevBtn, playPauseBtn, nextBtn])
        controlsStack.axis         = .horizontal
        controlsStack.distribution = .equalSpacing
        controlsStack.alignment    = .center
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(controlsStack)
        NSLayoutConstraint.activate([
            controlsStack.topAnchor.constraint(equalTo: nowTimeLabel.bottomAnchor, constant: 18),
            controlsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 36),
            controlsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -36),
            controlsStack.heightAnchor.constraint(equalToConstant: 80),
        ])

        // ── セカンダリツールバー（Apple Music アイコンスタイル） ────
        let shuffleBtn = makeSecondaryButton(
            symbol: "shuffle", label: localText(key: "player_shuffle_label"),
            tag: 1, action: #selector(newShuffleTapped)
        )
        let repeatBtn = makeSecondaryButton(
            symbol: "repeat", label: localText(key: "player_repeat_label"),
            tag: 2, action: #selector(newRepeatTapped)
        )
        let speedBtn = makeSecondaryButton(
            symbol: "gauge.with.dots.needle.33percent", label: "1.0×",
            tag: 3, action: #selector(newSpeedTapped)
        )
        let regionBtn = makeSecondaryButton(
            symbol: "scissors", label: localText(key: "player_region_label"),
            tag: 4, action: #selector(newRegionTapped)
        )
        let dictationBtn = makeSecondaryButton(
            symbol: "headphones", label: localText(key: "player_dictation_label"),
            tag: 5, action: #selector(newDictationTapped)
        )
        newShufflePill = shuffleBtn
        newRepeatPill  = repeatBtn
        newSpeedPill   = speedBtn
        newRegionPill  = regionBtn

        let secondaryStack = UIStackView(arrangedSubviews: [shuffleBtn, repeatBtn, speedBtn, regionBtn, dictationBtn])
        secondaryStack.axis         = .horizontal
        secondaryStack.distribution = .fillEqually
        secondaryStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(secondaryStack)
        let secondaryBottom = secondaryStack.bottomAnchor.constraint(lessThanOrEqualTo: card.safeAreaLayoutGuide.bottomAnchor, constant: -68)
        newSecondaryStackBottomConstraint = secondaryBottom
        NSLayoutConstraint.activate([
            secondaryStack.topAnchor.constraint(equalTo: controlsStack.bottomAnchor, constant: 14),
            secondaryStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            secondaryStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            secondaryStack.heightAnchor.constraint(equalToConstant: 56),
            secondaryBottom,
        ])
    }

    // MARK: - ボタン生成ヘルパー

    private func makeControlButton(symbol: String, size: CGFloat, weight: UIImage.SymbolWeight, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: weight)
        btn.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
        btn.tintColor = AppColor.textPrimary
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 54),
            btn.heightAnchor.constraint(equalToConstant: 54),
        ])
        return btn
    }

    /// Apple Music スタイルのセカンダリボタン（アイコン＋ラベル、iOS 13対応）
    private func makeSecondaryButton(symbol: String, label: String, tag: Int, action: Selector) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = tag

        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let img = UIImage(systemName: symbol, withConfiguration: cfg)?
            .withTintColor(AppColor.textSecondary, renderingMode: .alwaysOriginal)

        let iconView = UIImageView(image: img)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text      = label
        lbl.font      = .systemFont(ofSize: 10, weight: .medium)
        lbl.textColor = AppColor.textSecondary
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, lbl])
        stack.axis      = .vertical
        stack.spacing   = 4
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        btn.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            iconView.heightAnchor.constraint(equalToConstant: 22),
        ])

        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
}

// MARK: - AMProgressSlider (ドラッグ時にトラックが太くなり、サムが出現)

final class AMProgressSlider: UISlider {

    private var isDragging = false

    // ドラッグ状態に応じてトラック高さを切り替え（transform の代わりに使用）
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let h: CGFloat = isDragging ? 5 : 3
        return CGRect(x: bounds.minX,
                      y: (bounds.height - h) / 2,
                      width: bounds.width,
                      height: h)
    }

    // 上下 20pt 拡張してタップ・ドラッグを確実に拾う
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.insetBy(dx: 0, dy: -20).contains(point)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        // バー上のどこをタップしても即座にその位置にシーク
        let trackR  = trackRect(forBounds: bounds)
        let touchX  = touch.location(in: self).x
        let ratio   = (touchX - trackR.minX) / trackR.width
        value = minimumValue + (maximumValue - minimumValue) * Float(max(0, min(1, ratio)))
        sendActions(for: .valueChanged)

        isDragging = true
        UIView.animate(withDuration: 0.15) { self.layoutIfNeeded() }
        return true   // サム位置に関わらず常にトラッキング開始
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        finishDragging()
    }

    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        finishDragging()
    }

    private func finishDragging() {
        isDragging = false
        UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
    }
}

// MARK: - Default Artwork

extension PlayMusicViewController {

    /// サムネイルが未設定の場合に使うグラデーション＋音符アイコン画像を生成する
    func makeDefaultArtwork(size: CGSize = CGSize(width: 600, height: 600)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)

            // グレー系グラデーション背景
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: 0.20, alpha: 1).cgColor,
                    UIColor(white: 0.32, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end:   CGPoint(x: size.width, y: size.height),
                options: []
            )

            // 音符アイコン（SF Symbol）を中央に描画
            let symbolSize = size.width * 0.38
            let cfg = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .thin)
            if let symbol = UIImage(systemName: "music.note", withConfiguration: cfg)?
                .withTintColor(UIColor(white: 1.0, alpha: 0.18), renderingMode: .alwaysOriginal) {
                let origin = CGPoint(
                    x: (size.width  - symbol.size.width)  / 2,
                    y: (size.height - symbol.size.height) / 2
                )
                symbol.draw(at: origin)
            }
        }
    }
}

// MARK: - New Player UI Sync

extension PlayMusicViewController {

    func syncNewUITrack(playData: TrackData) {
        newTitleLabel?.text  = playData.title
        newArtistLabel?.text = playData.artist
        newLyricsView?.text  = playData.lyric
        newLyricsView?.setContentOffset(.zero, animated: false)
        let img = playData.artworkImg ?? makeDefaultArtwork()
        newArtworkView?.image  = img
        newBgImageView?.image  = img

        // アートワーク切り替えアニメーション
        guard let artwork = newArtworkView else { return }
        UIView.transition(with: artwork, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }

    func syncNewUIProgress() {
        guard let player = audioPlayer, player.duration > 0 else { return }
        newProgressSlider?.value = Float(player.currentTime / player.duration)
        newNowTimeLabel?.text    = formatTimeString(d: player.currentTime)
        newTotalTimeLabel?.text  = formatTimeString(d: player.duration)
        newScrubTimeLabel?.text  = formatTimeString(d: player.currentTime)
    }

    func syncNewUIPlayState() {
        let isPlaying = audioPlayer?.isPlaying ?? false
        let cfg = UIImage.SymbolConfiguration(pointSize: 32, weight: .bold)
        let name = isPlaying ? "pause.fill" : "play.fill"
        newPlayPauseBtn?.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    func syncNewUIShuffleState() {
        setSecondaryButtonColor(newShufflePill, active: SHUFFLE_FLG)
    }

    func syncNewUIRepeatState() {
        guard let btn = newRepeatPill else { return }
        let (symbol, active): (String, Bool)
        switch repeatState {
        case REPEAT_STATE_ALL: symbol = "repeat";   active = true
        case REPEAT_STATE_ONE: symbol = "repeat.1"; active = true
        default:               symbol = "repeat";   active = false
        }
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let color: UIColor = active ? AppColor.accent : AppColor.textSecondary
        if let iv = btn.subviews.compactMap({ $0 as? UIStackView }).first?
            .arrangedSubviews.compactMap({ $0 as? UIImageView }).first {
            iv.image = UIImage(systemName: symbol, withConfiguration: cfg)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
        }
        setSecondaryButtonColor(btn, active: active)
    }

    func syncNewUISpeedState() {
        guard let btn = newSpeedPill else { return }
        let s = speedList[speedRow]
        let text: String
        if s >= 10 || s == Double(Int(s)) { text = String(format: "%.4g×", s) }
        else { text = String(format: "%.2g×", s) }
        if let lbl = btn.subviews.compactMap({ $0 as? UIStackView }).first?
            .arrangedSubviews.compactMap({ $0 as? UILabel }).first {
            lbl.text = text
        }
    }

    func syncNewUIRegionState() {
        guard let btn = newRegionPill else { return }
        let on = sectionRepeatStatus == SECTION_REPEAT_ON
        if let lbl = btn.subviews.compactMap({ $0 as? UIStackView }).first?
            .arrangedSubviews.compactMap({ $0 as? UILabel }).first {
            lbl.text = on ? localText(key: "player_region_on") : localText(key: "player_region_label")
        }
        setSecondaryButtonColor(btn, active: on)
    }

    private func setSecondaryButtonColor(_ btn: UIButton?, active: Bool) {
        let color: UIColor = active ? AppColor.accent : AppColor.textSecondary
        btn?.subviews.compactMap { $0 as? UIStackView }.first?.arrangedSubviews.forEach { v in
            if let iv = v as? UIImageView, let img = iv.image {
                iv.image = img.withTintColor(color, renderingMode: .alwaysOriginal)
            }
            if let lbl = v as? UILabel { lbl.textColor = color }
        }
    }
}

// MARK: - New Player UI Actions

extension PlayMusicViewController {

    @objc func newPlayPauseTapped() {
        newPlayPauseBtn?.springTap(scale: 0.90)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        PlayBtnTapped(PlayBtn)
    }

    @objc func newPrevTapped() {
        newPrevBtn?.springTap(scale: 0.82)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        BeforeBtnTapped(BeforeBtn)
    }

    @objc func newNextTapped() {
        newNextBtn?.springTap(scale: 0.82)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AfterBtnTapped(AfterBtn)
    }

    @objc func newShuffleTapped() {
        newShufflePill?.springTap(scale: 0.85)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        shuffleBtnTapped(shuffleBtn)
    }

    @objc func newRepeatTapped() {
        newRepeatPill?.springTap(scale: 0.85)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        repeatBtnTapped(repeatBtn)
    }

    @objc func newSpeedTapped() {
        newSpeedPill?.springTap(scale: 0.85)
        showSpeedSheet()
    }

    @objc func newRegionTapped() {
        newRegionPill?.springTap(scale: 0.85)
        showRegionSheet()
    }

    @objc func newDictationTapped() {
        tabBarController?.selectedIndex = 1
    }

    @objc func newModeSwitched(_ sender: UISegmentedControl) {
        isShowingLyrics = sender.selectedSegmentIndex == 1
        UIView.transition(with: newContentContainer ?? UIView(), duration: 0.28, options: .transitionCrossDissolve) {
            self.newArtworkView?.isHidden  = self.isShowingLyrics
            self.newLyricsView?.isHidden   = !self.isShowingLyrics
        }
    }

    @objc func newProgressChanged(_ sender: UISlider) {
        if let player = audioPlayer {
            player.currentTime = TimeInterval(sender.value) * player.duration
            musicProgressSlider.value = sender.value
            syncNewUIProgress()
            newScrubTimeLabel?.text = formatTimeString(d: player.currentTime)
        } else {
            // 再生前のシーク: 位置を記憶して再生開始時に適用
            pendingSeekRatio = sender.value
        }
    }

    @objc func progressDragBegan(_ sender: UISlider) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc func progressDragEnded(_ sender: UISlider) {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func showRegionSheet() {
        let rawValues: [CGFloat] = multiRepeatSlider?.value ?? [0, 1]
        let start   = rawValues.count >= 2 ? rawValues[0] : 0
        let end     = rawValues.count >= 2 ? rawValues[1] : 1
        let dur     = audioPlayer?.duration ?? 0
        let curTime = audioPlayer?.currentTime ?? 0
        let enabled = sectionRepeatStatus == SECTION_REPEAT_ON

        let sheet = RegionRepeatSheetViewController(
            isEnabled: enabled, start: start, end: end,
            duration: dur, currentTime: curTime
        )
        sheet.onConfirm = { [weak self] (isOn: Bool, newStart: CGFloat, newEnd: CGFloat) in
            guard let self else { return }
            self.multiRepeatSlider?.value = [newStart, newEnd]
            self.repeatMinTime.text = formatTimeString(d: TimeInterval(newStart) * dur)
            self.repeatMaxTime.text = formatTimeString(d: TimeInterval(newEnd)   * dur)
            sectionRepeatStatus = isOn ? SECTION_REPEAT_ON : SECTION_REPEAT_OFF
            self.setSectionRepeatStatus()
            self.syncNewUIRegionState()
            // 設定をUserDefaultsに保存（区間・ON/OFF）
            let trackData = SHUFFLE_FLG
                ? NowPlayingMusicLibraryData.trackDataShuffled
                : NowPlayingMusicLibraryData.trackData
            if newSelectPlayNum < trackData.count {
                let playData = trackData[newSelectPlayNum]
                self.mMusicController.setSectionRepeatSettings(playData: playData, time: [newStart, newEnd])
                self.mMusicController.setSectionRepeatEnabled(url: playData.url!, isEnabled: isOn)
            }
        }
        present(sheet, animated: false)
    }
}
