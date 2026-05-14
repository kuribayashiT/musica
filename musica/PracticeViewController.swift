//
//  PracticeViewController.swift
//  musica
//
//  語学学習・音楽練習ダッシュボード。
//  練習モード選択 / 再生スピード / 今すぐ再開 を一画面に集約。
//

import UIKit
import NaturalLanguage

// MARK: - PracticeViewController

final class PracticeViewController: UIViewController, UIAdaptivePresentationControllerDelegate {

    // MARK: Models

    private enum FeatureStatus { case available, comingSoon }

    private struct PracticeFeature {
        let symbol: String
        let title: String
        let description: String
        let status: FeatureStatus
        let action: () -> Void
    }

    // MARK: Speed Card Config

    private let speedSnapPoints: [Double] = [
        0.5, 0.6, 0.7, 0.75, 0.8, 0.9,
        1.0, 1.1, 1.2, 1.25, 1.3, 1.4, 1.5, 1.6, 1.7, 1.75, 1.8, 1.9,
        2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0,
        6.0, 7.0, 8.0, 10.0, 15.0, 20.0, 30.0, 40.0, 50.0
    ]
    private let speedMin: Double = 0.5
    private let speedMax: Double = 50.0
    private let lowSpeedPills:  [(String, Double)] = [
        ("0.5×", 0.5), ("0.75×", 0.75), ("1.0×", 1.0), ("1.5×", 1.5), ("2.0×", 2.0)
    ]
    private let highSpeedPills: [(String, Double)] = [
        ("8×", 8.0), ("10×", 10.0), ("20×", 20.0), ("30×", 30.0), ("50×", 50.0)
    ]

    // lazy で self 参照
    private lazy var features: [PracticeFeature] = [
        PracticeFeature(
            symbol: "repeat",
            title: localText(key: "practice_mode_loop"),
            description: localText(key: "practice_mode_loop_sub"),
            status: .available,
            action: { [weak self] in self?.openSectionRepeat() }
        ),
        PracticeFeature(
            symbol: "rectangle.on.rectangle.angled",
            title: "フラッシュカード",
            description: "歌詞から単語を学習",
            status: .available,
            action: { [weak self] in self?.openFlashCard() }
        ),
        PracticeFeature(
            symbol: "bookmark.fill",
            title: localText(key: "practice_weak_words_title"),
            description: localText(key: "practice_weak_words_sub"),
            status: .available,
            action: { [weak self] in self?.openWeakWords() }
        ),
    ]

    // MARK: Views

    private let scrollView = UIScrollView()
    private let stack     = UIStackView()
    private var speedPillButtons: [UIButton] = []
    private weak var speedCardSlider: UISlider?
    private weak var speedCardLabel:  UILabel?

    // MARK: Lifecycle

    // 再生ボタン参照（状態更新用）
    private weak var nowPlayingPlayBtn: UIButton?
    private var isReturningFromPush = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        navigationItem.largeTitleDisplayMode = .always
        title = localText(key: "practice_title")
        setupScrollView()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlaybackStateChanged(_:)),
            name: .musicaPlaybackStateChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onTrackChanged),
            name: .musicaTrackChanged,
            object: nil
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isReturningFromPush = navigationController?.viewControllers.last != self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        if let naviBar = navigationController?.navigationBar {
            setContentNavigationBarStyle(naviBar: naviBar)
        }
        buildContent()
        if !isReturningFromPush {
            resetScrollForLargeTitle()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        FA.logScreen(FA.Screen.practice, vc: "PracticeViewController")
        if !isReturningFromPush {
            resetScrollForLargeTitle()
        }
        isReturningFromPush = false
    }

    @objc private func onPlaybackStateChanged(_ notification: Notification) {
        let isPlaying = notification.userInfo?["isPlaying"] as? Bool ?? false
        updateNowPlayingButton(isPlaying: isPlaying)
    }

    @objc private func onTrackChanged() {
        buildContent()
    }

    private func updateNowPlayingButton(isPlaying: Bool) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        nowPlayingPlayBtn?.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill", withConfiguration: cfg), for: .normal)
    }

    // MARK: Layout

    private func resetScrollForLargeTitle() {
        let topInset = scrollView.adjustedContentInset.top
        guard topInset > 0 else { return }
        // Nav bar height: 44pt compact, 96pt large title.
        // When compact, push content 52pt past the compact top so the nav bar expands.
        let navBarHeight = navigationController?.navigationBar.frame.height ?? 44
        let targetY = navBarHeight <= 55 ? -(topInset + 52) : -topInset
        scrollView.setContentOffset(CGPoint(x: 0, y: targetY), animated: false)
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        stack.axis    = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),
        ])
    }

    private func buildContent() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        buildNowPlayingSection()

        stack.addArrangedSubview(sectionHeader(localText(key: "practice_mode_header")))
        stack.addArrangedSubview(buildDictationCard())
        if !features.isEmpty {
            stack.addArrangedSubview(buildFeatureGrid())
        }

        stack.addArrangedSubview(sectionHeader(localText(key: "practice_speed_header")))
        stack.addArrangedSubview(buildSpeedCard())

        stack.addArrangedSubview(sectionHeader("練習履歴"))
        stack.addArrangedSubview(buildHistorySection())
    }

    // MARK: Now Playing Card

    private func buildNowPlayingSection() {
        let hasTrack = NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING
            && !NowPlayingMusicLibraryData.trackData.isEmpty

        if hasTrack {
            let idx   = min(NowPlayingMusicLibraryData.nowPlaying,
                            NowPlayingMusicLibraryData.trackData.count - 1)
            let track = NowPlayingMusicLibraryData.trackData[idx]
            stack.addArrangedSubview(
                buildResumeCard(track: track, library: NowPlayingMusicLibraryData.nowPlayingLibrary)
            )
        } else {
            stack.addArrangedSubview(buildNoTrackBanner())
        }
    }

    private func buildNoTrackBanner() -> UIView {
        let card = UIView()
        card.backgroundColor  = AppColor.surface
        card.layer.cornerRadius = 16

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: "music.note.list", withConfiguration: iconCfg))
        iconView.tintColor   = AppColor.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text          = localText(key: "practice_no_track_hint")
        label.font          = UIFont.systemFont(ofSize: 14)
        label.textColor     = AppColor.textSecondary
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.translatesAutoresizingMaskIntoConstraints = false

        let goBtn = UIButton(type: .system)
        goBtn.setTitle(localText(key: "practice_go_home_btn"), for: .normal)
        goBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        goBtn.setTitleColor(AppColor.accent, for: .normal)
        goBtn.addTarget(self, action: #selector(goHomeTapped), for: .touchUpInside)
        goBtn.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(label)
        card.addSubview(goBtn)
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: goBtn.leadingAnchor, constant: -8),

            goBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            goBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            card.heightAnchor.constraint(equalToConstant: 60),
        ])
        return card
    }

    @objc private func goHomeTapped() {
        tabBarController?.selectedIndex = 0
    }

    private func buildResumeCard(track: TrackData, library: String) -> UIView {
        let shadowWrap = UIView()
        shadowWrap.backgroundColor = .clear
        shadowWrap.layer.cornerRadius = 16
        shadowWrap.layer.shadowColor = UIColor.black.cgColor
        shadowWrap.layer.shadowOpacity = 0.22
        shadowWrap.layer.shadowRadius = 12
        shadowWrap.layer.shadowOffset = CGSize(width: 0, height: 4)

        let card = UIView()
        card.backgroundColor = AppColor.surface
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        shadowWrap.addSubview(card)

        let bgImg = UIImageView()
        bgImg.contentMode = .scaleAspectFill
        bgImg.image = track.artworkImg ?? makeDefaultArtwork()
        bgImg.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bgImg)

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(blur)

        let accentBar = UIView()
        accentBar.backgroundColor = AppColor.accent
        accentBar.layer.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(accentBar)

        let artView = UIImageView()
        artView.clipsToBounds = true
        artView.layer.cornerRadius = 10
        artView.backgroundColor = AppColor.surfaceSecondary
        artView.contentMode = .scaleAspectFill
        artView.image = track.artworkImg ?? makeDefaultArtwork()
        artView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(artView)

        let titleLbl = UILabel()
        titleLbl.text = track.title.isEmpty ? localText(key: "practice_unknown") : track.title
        titleLbl.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLbl.textColor = AppColor.textPrimary
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)

        let artistLbl = UILabel()
        artistLbl.text = library.isEmpty ? localText(key: "practice_library") : library
        artistLbl.font = .systemFont(ofSize: 11)
        artistLbl.textColor = AppColor.textSecondary
        artistLbl.lineBreakMode = .byTruncatingTail
        artistLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(artistLbl)

        let prevBtn = UIButton(type: .system)
        let prevCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        prevBtn.setImage(UIImage(systemName: "backward.end.fill", withConfiguration: prevCfg), for: .normal)
        prevBtn.tintColor = AppColor.textPrimary
        prevBtn.addTarget(self, action: #selector(prevTrackTapped), for: .touchUpInside)
        prevBtn.translatesAutoresizingMaskIntoConstraints = false

        let isPlaying = audioPlayer?.isPlaying ?? false
        let ppBtn = UIButton(type: .system)
        ppBtn.backgroundColor = AppColor.accent
        ppBtn.tintColor = .white
        ppBtn.layer.cornerRadius = 19
        ppBtn.layer.masksToBounds = true
        let ppCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        ppBtn.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill", withConfiguration: ppCfg), for: .normal)
        ppBtn.addTarget(self, action: #selector(resumeTapped), for: .touchUpInside)
        ppBtn.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingPlayBtn = ppBtn

        let nextBtn = UIButton(type: .system)
        let nextCfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        nextBtn.setImage(UIImage(systemName: "forward.end.fill", withConfiguration: nextCfg), for: .normal)
        nextBtn.tintColor = AppColor.textPrimary
        nextBtn.addTarget(self, action: #selector(nextTrackTapped), for: .touchUpInside)
        nextBtn.translatesAutoresizingMaskIntoConstraints = false

        let btnStack = UIStackView(arrangedSubviews: [prevBtn, ppBtn, nextBtn])
        btnStack.axis = .horizontal
        btnStack.spacing = 4
        btnStack.alignment = .center
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(btnStack)

        NSLayoutConstraint.activate([
            shadowWrap.heightAnchor.constraint(equalToConstant: 76),

            card.topAnchor.constraint(equalTo: shadowWrap.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowWrap.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: shadowWrap.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowWrap.trailingAnchor),

            bgImg.topAnchor.constraint(equalTo: card.topAnchor),
            bgImg.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            bgImg.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            bgImg.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            blur.topAnchor.constraint(equalTo: card.topAnchor),
            blur.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            blur.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            accentBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            accentBar.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 4),
            accentBar.heightAnchor.constraint(equalToConstant: 28),

            artView.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            artView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            artView.widthAnchor.constraint(equalToConstant: 52),
            artView.heightAnchor.constraint(equalToConstant: 52),

            btnStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            btnStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            prevBtn.widthAnchor.constraint(equalToConstant: 36),
            prevBtn.heightAnchor.constraint(equalToConstant: 36),
            ppBtn.widthAnchor.constraint(equalToConstant: 38),
            ppBtn.heightAnchor.constraint(equalToConstant: 38),
            nextBtn.widthAnchor.constraint(equalToConstant: 36),
            nextBtn.heightAnchor.constraint(equalToConstant: 36),

            titleLbl.leadingAnchor.constraint(equalTo: artView.trailingAnchor, constant: 12),
            titleLbl.trailingAnchor.constraint(equalTo: btnStack.leadingAnchor, constant: -8),
            titleLbl.bottomAnchor.constraint(equalTo: card.centerYAnchor, constant: 1),

            artistLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            artistLbl.trailingAnchor.constraint(equalTo: titleLbl.trailingAnchor),
            artistLbl.topAnchor.constraint(equalTo: card.centerYAnchor, constant: 4),
        ])
        return shadowWrap
    }

    @objc private func resumeTapped() {
        NotificationCenter.default.post(name: .musicaRemotePlayPause, object: nil)
    }

    @objc private func prevTrackTapped() {
        NotificationCenter.default.post(name: .musicaRemotePrev, object: nil)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func nextTrackTapped() {
        NotificationCenter.default.post(name: .musicaRemoteNext, object: nil)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: Feature Grid (2×2)

    private func buildFeatureGrid() -> UIView {
        let col1 = UIStackView()
        col1.axis    = .vertical
        col1.spacing = 12
        col1.translatesAutoresizingMaskIntoConstraints = false

        let col2 = UIStackView()
        col2.axis    = .vertical
        col2.spacing = 12
        col2.translatesAutoresizingMaskIntoConstraints = false

        for (i, feature) in features.enumerated() {
            let card = buildFeatureCard(feature: feature, index: i)
            (i % 2 == 0 ? col1 : col2).addArrangedSubview(card)
        }

        let hStack = UIStackView(arrangedSubviews: [col1, col2])
        hStack.axis         = .horizontal
        hStack.spacing      = 12
        hStack.distribution = .fillEqually
        hStack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(hStack)
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: container.topAnchor),
            hStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func buildFeatureCard(feature: PracticeFeature, index: Int) -> UIView {
        let isAvailable = feature.status == .available

        let card = UIView()
        card.backgroundColor = AppColor.surface
        card.layer.cornerRadius  = 18
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset  = CGSize(width: 0, height: 2)
        card.layer.shadowRadius  = 8
        card.alpha = isAvailable ? 1.0 : 0.85
        card.tag   = index

        // アイコン
        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: feature.symbol, withConfiguration: iconCfg))
        iconView.tintColor     = isAvailable ? AppColor.accent : AppColor.textSecondary
        iconView.contentMode   = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        // タイトル
        let titleLabel = UILabel()
        titleLabel.text          = feature.title
        titleLabel.font          = UIFont.systemFont(ofSize: 14, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // 説明
        let descLabel = UILabel()
        descLabel.text          = feature.description
        descLabel.font          = UIFont.systemFont(ofSize: 11)
        descLabel.textColor     = AppColor.textSecondary
        descLabel.numberOfLines = 1
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(titleLabel)
        card.addSubview(descLabel)

        var constraints: [NSLayoutConstraint] = [
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),

            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            descLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            descLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            descLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            card.heightAnchor.constraint(equalToConstant: 130),
        ]

        // 「近日公開」バッジ
        if !isAvailable {
            let badge = UILabel()
            badge.text          = localText(key: "practice_coming_soon")
            badge.font          = UIFont.systemFont(ofSize: 9, weight: .bold)
            badge.textColor     = AppColor.accent
            badge.backgroundColor = AppColor.accent.withAlphaComponent(0.12)
            badge.textAlignment = .center
            badge.layer.cornerRadius = 6
            badge.clipsToBounds = true
            badge.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(badge)
            constraints += [
                badge.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
                badge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
                badge.heightAnchor.constraint(equalToConstant: 18),
                badge.widthAnchor.constraint(equalToConstant: 48),
            ]
        }

        NSLayoutConstraint.activate(constraints)

        let tap = UITapGestureRecognizer(target: self, action: #selector(featureTapped(_:)))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true
        return card
    }

    @objc private func featureTapped(_ sender: UITapGestureRecognizer) {
        guard let tag = sender.view?.tag, tag < features.count else { return }
        UIView.animate(withDuration: 0.1, animations: {
            sender.view?.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) { sender.view?.transform = .identity }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        features[tag].action()
    }

    // MARK: Speed Card

    private func buildSpeedCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 16

        // 速度ラベル
        let speedLabel = UILabel()
        speedLabel.font          = AppFont.title
        speedLabel.textColor     = AppColor.accent
        speedLabel.textAlignment = .center
        speedCardLabel = speedLabel

        // スライダー（対数スケール）
        let slider = UISlider()
        slider.minimumValue          = 0
        slider.maximumValue          = 1
        slider.minimumTrackTintColor = AppColor.accent
        slider.maximumTrackTintColor = AppColor.separator
        slider.addTarget(self, action: #selector(practiceSliderChanged(_:)), for: .valueChanged)
        speedCardSlider = slider

        let minLabel = UILabel()
        minLabel.text      = "0.5×"
        minLabel.font      = AppFont.caption2
        minLabel.textColor = AppColor.textSecondary

        let maxLabel = UILabel()
        maxLabel.text      = "50×"
        maxLabel.font      = AppFont.caption2
        maxLabel.textColor = AppColor.textSecondary

        let sliderRow = UIStackView(arrangedSubviews: [minLabel, slider, maxLabel])
        sliderRow.axis      = .horizontal
        sliderRow.spacing   = 6
        sliderRow.alignment = .center

        // 低速ピル行
        let lowStack = UIStackView()
        lowStack.axis         = .horizontal
        lowStack.distribution = .fillEqually
        lowStack.spacing      = 6

        // 高速ピル行
        let highStack = UIStackView()
        highStack.axis         = .horizontal
        highStack.distribution = .fillEqually
        highStack.spacing      = 6

        speedPillButtons.removeAll()
        for (label, value) in lowSpeedPills {
            let btn = makeSpeedPillButton(label: label, value: value)
            lowStack.addArrangedSubview(btn)
            speedPillButtons.append(btn)
        }
        for (label, value) in highSpeedPills {
            let btn = makeSpeedPillButton(label: label, value: value)
            highStack.addArrangedSubview(btn)
            speedPillButtons.append(btn)
        }

        let vStack = UIStackView(arrangedSubviews: [speedLabel, sliderRow, lowStack, highStack])
        vStack.axis      = .vertical
        vStack.spacing   = 12
        vStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vStack)
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            lowStack.heightAnchor.constraint(equalToConstant: 34),
            highStack.heightAnchor.constraint(equalToConstant: 34),
        ])

        // 現在の速度でUIを初期化
        let currentSpeed = max(speedMin, min(speedMax, speedList[speedRow]))
        syncSpeedCard(speed: currentSpeed)
        return card
    }

    private func makeSpeedPillButton(label: String, value: Double) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(label, for: .normal)
        btn.titleLabel?.font   = AppFont.footnote
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth  = 1
        btn.tag = Int(value * 1000)
        btn.addTarget(self, action: #selector(practicePillTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func practiceSliderChanged(_ slider: UISlider) {
        let raw     = speedMin * pow(speedMax / speedMin, Double(slider.value))
        let snapped = speedSnapPoints.min(by: { abs($0 - raw) < abs($1 - raw) }) ?? raw
        applyPracticeSpeed(snapped, updateSlider: false)
    }

    @objc private func practicePillTapped(_ sender: UIButton) {
        let speed = Double(sender.tag) / 1000.0
        applyPracticeSpeed(speed, updateSlider: true)
    }

    private func applyPracticeSpeed(_ speed: Double, updateSlider: Bool) {
        let nearest = speedList.enumerated().min { abs($0.element - speed) < abs($1.element - speed) }
        speedRow = nearest?.offset ?? 5
        audioPlayer?.rate = Float((speed * 10).rounded() / 10)
        syncSpeedCard(speed: speed, updateSlider: updateSlider)
        FA.log(FA.speedChange, params: ["speed": speed, "source": "practice_tab"])
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func syncSpeedCard(speed: Double, updateSlider: Bool = true) {
        if speed >= 10 || speed == Double(Int(speed)) {
            speedCardLabel?.text = String(format: "%.4g×", speed)
        } else {
            speedCardLabel?.text = String(format: "%.2g×", speed)
        }
        if updateSlider {
            let pos = Float(log(speed / speedMin) / log(speedMax / speedMin))
            speedCardSlider?.setValue(max(0, min(1, pos)), animated: false)
        }
        for btn in speedPillButtons {
            let val = Double(btn.tag) / 1000.0
            let on  = abs(val - speed) < 0.001
            btn.backgroundColor   = on ? AppColor.accent : AppColor.surfaceSecondary
            btn.setTitleColor(on ? .white : AppColor.textPrimary, for: .normal)
            btn.layer.borderColor = on ? AppColor.accent.cgColor : AppColor.border.cgColor
        }
    }


    // MARK: Dictation Card (動的)

    private func buildDictationCard() -> UIView {
        let hasTrack = NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING
            && !NowPlayingMusicLibraryData.trackData.isEmpty

        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 18
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset  = CGSize(width: 0, height: 2)
        card.layer.shadowRadius  = 8

        // ── ヘッダー行（アイコン＋タイトル） ──
        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: "waveform.and.mic", withConfiguration: iconCfg))
        iconView.tintColor   = AppColor.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text      = localText(key: "practice_dictation_title")
        titleLabel.font      = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = AppColor.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descLabel = UILabel()
        descLabel.text      = localText(key: "practice_dictation_desc")
        descLabel.font      = UIFont.systemFont(ofSize: 12)
        descLabel.textColor = AppColor.textSecondary
        descLabel.translatesAutoresizingMaskIntoConstraints = false

        let headerTextStack = UIStackView(arrangedSubviews: [titleLabel, descLabel])
        headerTextStack.axis    = .vertical
        headerTextStack.spacing = 2
        headerTextStack.translatesAutoresizingMaskIntoConstraints = false

        // ── 区切り線 ──
        let divider = UIView()
        divider.backgroundColor = AppColor.textSecondary.withAlphaComponent(0.15)
        divider.translatesAutoresizingMaskIntoConstraints = false

        // ── 状態アイコン ──
        let stateCfg  = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let stateIcon = UIImageView()
        stateIcon.contentMode = .scaleAspectFit
        stateIcon.translatesAutoresizingMaskIntoConstraints = false
        stateIcon.widthAnchor.constraint(equalToConstant: 24).isActive  = true
        stateIcon.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let stateMain = UILabel()
        stateMain.font          = UIFont.systemFont(ofSize: 14, weight: .semibold)
        stateMain.textColor     = AppColor.textPrimary
        stateMain.numberOfLines = 1

        let stateSub = UILabel()
        stateSub.font          = UIFont.systemFont(ofSize: 11)
        stateSub.textColor     = AppColor.textSecondary
        stateSub.numberOfLines = 2

        let stateTextStack = UIStackView(arrangedSubviews: [stateMain, stateSub])
        stateTextStack.axis    = .vertical
        stateTextStack.spacing = 2

        let stateStack = UIStackView(arrangedSubviews: [stateIcon, stateTextStack])
        stateStack.axis      = .horizontal
        stateStack.spacing   = 10
        stateStack.alignment = .center
        stateStack.translatesAutoresizingMaskIntoConstraints = false

        // ── CTAボタン（全幅） ──
        let ctaBtn = UIButton(type: .system)
        ctaBtn.titleLabel?.font   = UIFont.systemFont(ofSize: 15, weight: .semibold)
        ctaBtn.setTitleColor(.white, for: .normal)
        ctaBtn.backgroundColor    = AppColor.accent
        ctaBtn.layer.cornerRadius = 12
        ctaBtn.translatesAutoresizingMaskIntoConstraints = false

        // 歌詞ありのときだけ表示する「テキスト・言語を変更」リンク
        let settingsLink = UIButton(type: .system)
        settingsLink.setTitle(localText(key: "practice_change_settings"), for: .normal)
        settingsLink.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        settingsLink.setTitleColor(AppColor.textSecondary, for: .normal)
        settingsLink.contentHorizontalAlignment = .trailing
        settingsLink.addTarget(self, action: #selector(dictationSettings), for: .touchUpInside)
        settingsLink.translatesAutoresizingMaskIntoConstraints = false
        settingsLink.isHidden = true

        if !hasTrack {
            // State 1: 曲なし
            stateIcon.image    = UIImage(systemName: "music.note.list", withConfiguration: stateCfg)
            stateIcon.tintColor = AppColor.textSecondary
            stateMain.text     = localText(key: "practice_no_track_state")
            stateSub.text      = localText(key: "practice_no_track_state_sub")
            ctaBtn.setTitle(localText(key: "practice_go_home_short"), for: .normal)
            ctaBtn.addTarget(self, action: #selector(dictationGoHome), for: .touchUpInside)
        } else {
            let idx   = min(NowPlayingMusicLibraryData.nowPlaying,
                            NowPlayingMusicLibraryData.trackData.count - 1)
            let track = NowPlayingMusicLibraryData.trackData[idx]
            let hasLyrics = !track.lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            stateMain.text = track.title.isEmpty ? localText(key: "practice_unknown") : track.title

            if hasLyrics {
                // State 3: 歌詞あり → ActionSheet なしで即練習開始
                stateIcon.image     = UIImage(systemName: "checkmark.circle.fill", withConfiguration: stateCfg)
                stateIcon.tintColor = UIColor.systemGreen
                stateSub.text       = localText(key: "practice_lyrics_ready")
                ctaBtn.setTitle(localText(key: "practice_start_btn"), for: .normal)
                ctaBtn.addTarget(self, action: #selector(dictationStart), for: .touchUpInside)
                settingsLink.isHidden = false
            } else {
                // State 2: 歌詞なし
                stateIcon.image     = UIImage(systemName: "exclamationmark.circle.fill", withConfiguration: stateCfg)
                stateIcon.tintColor = UIColor.systemOrange
                stateSub.text       = localText(key: "practice_no_lyrics_hint")
                ctaBtn.setTitle(localText(key: "practice_prepare_text_btn"), for: .normal)
                ctaBtn.addTarget(self, action: #selector(dictationFetch), for: .touchUpInside)
            }
        }

        card.addSubview(iconView)
        card.addSubview(headerTextStack)
        card.addSubview(divider)
        card.addSubview(stateStack)
        card.addSubview(ctaBtn)
        card.addSubview(settingsLink)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            headerTextStack.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            headerTextStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            headerTextStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            divider.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            divider.heightAnchor.constraint(equalToConstant: 1),

            stateStack.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 14),
            stateStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stateStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            ctaBtn.topAnchor.constraint(equalTo: stateStack.bottomAnchor, constant: 14),
            ctaBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            ctaBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            ctaBtn.heightAnchor.constraint(equalToConstant: 46),

            settingsLink.topAnchor.constraint(equalTo: ctaBtn.bottomAnchor, constant: 8),
            settingsLink.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            settingsLink.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            settingsLink.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        return card
    }

    @objc private func dictationGoHome() {
        tabBarController?.selectedIndex = 0
    }

    @objc private func dictationFetch() {
        // 歌詞なし → セットアップ画面へ
        guard let (track, idx) = currentTrackInfo() else { return }
        let setupVC = DictationSetupViewController()
        setupVC.track       = track
        setupVC.trackIndex  = idx
        setupVC.libraryName = NowPlayingMusicLibraryData.nowPlayingLibrary
        navigationController?.pushViewController(setupVC, animated: true)
    }

    @objc private func dictationStart() {
        // 歌詞あり → ActionSheet なしで即練習開始
        guard let (track, _) = currentTrackInfo() else { return }
        let lyrics = track.lyric.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lyrics.isEmpty else { return }
        startDictation(track: track, lyrics: lyrics)
    }

    @objc private func dictationSettings() {
        // 歌詞ありでも設定を変えたい場合
        guard let (track, idx) = currentTrackInfo() else { return }
        let setupVC = DictationSetupViewController()
        setupVC.track       = track
        setupVC.trackIndex  = idx
        setupVC.libraryName = NowPlayingMusicLibraryData.nowPlayingLibrary
        navigationController?.pushViewController(setupVC, animated: true)
    }

    // MARK: Dictation Entry

    /// 現在再生中のトラック情報を返す。なければ nil。
    private func currentTrackInfo() -> (TrackData, Int)? {
        let hasTrack = NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING
            && !NowPlayingMusicLibraryData.trackData.isEmpty
        guard hasTrack else { return nil }
        let idx = min(NowPlayingMusicLibraryData.nowPlaying,
                      NowPlayingMusicLibraryData.trackData.count - 1)
        return (NowPlayingMusicLibraryData.trackData[idx], idx)
    }

    private func startDictation(track: TrackData, lyrics: String) {
        FA.log(FA.dictationStart, params: ["track": track.title ?? ""])
        let vc = DictationViewController()
        vc.track  = track
        vc.lyrics = lyrics
        // SetupVCを経由しない場合、歌詞全体の支配的言語を検出してフィルタ
        // （nil = "すべて" という DictationVC の意味論を壊さないよう呼び出し元で解決）
        let rec = NLLanguageRecognizer()
        rec.processString(lyrics)
        if let dominant = rec.dominantLanguage, dominant != .undetermined {
            vc.selectedLyricLang = dominant
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: Section Repeat Entry

    private func openSectionRepeat() {
        let hasTrack = NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING
            && !NowPlayingMusicLibraryData.trackData.isEmpty
        guard hasTrack else {
            let alert = UIAlertController(
                title: localText(key: "practice_no_track_alert_title"),
                message: localText(key: "practice_no_track_alert_msg"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: localText(key: "practice_go_home_short"), style: .default) { [weak self] _ in
                self?.tabBarController?.selectedIndex = 0
            })
            alert.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
            present(alert, animated: true)
            return
        }

        let idx   = min(NowPlayingMusicLibraryData.nowPlaying,
                        NowPlayingMusicLibraryData.trackData.count - 1)
        let track = NowPlayingMusicLibraryData.trackData[idx]

        let vc    = SectionRepeatViewController()
        vc.track  = track
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openFlashCard() {
        let hasTrack = NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING
            && !NowPlayingMusicLibraryData.trackData.isEmpty
        guard hasTrack else {
            let alert = UIAlertController(
                title: localText(key: "practice_no_track_alert_title"),
                message: localText(key: "practice_no_track_alert_msg"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: localText(key: "practice_go_home_short"), style: .default) { [weak self] _ in
                self?.tabBarController?.selectedIndex = 0
            })
            alert.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
            present(alert, animated: true)
            return
        }

        let idx   = min(NowPlayingMusicLibraryData.nowPlaying, NowPlayingMusicLibraryData.trackData.count - 1)
        let track = NowPlayingMusicLibraryData.trackData[idx]

        guard !track.lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let alert = UIAlertController(
                title: "歌詞が登録されていません",
                message: "フラッシュカードを使うには歌詞を先に登録してください。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        FA.log(FA.flashCardStart, params: ["track": track.title ?? ""])
        let vc    = FlashCardViewController()
        vc.track  = track
        vc.onDismiss = { [weak self] in self?.buildContent() }
        let nav   = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *),
           let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        nav.presentationController?.delegate = self
        present(nav, animated: true)
    }

    private func openWeakWords() {
        let vc  = WeakWordListViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: Practice History Section

    private func buildHistorySection() -> UIView {
        let service = PracticeHistoryService.shared
        let records = service.allRecords()

        if records.isEmpty {
            return buildHistoryEmptyCard()
        }

        let container = UIStackView()
        container.axis    = .vertical
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        container.addArrangedSubview(buildActivityCard(service: service))
        container.addArrangedSubview(buildMonthlyChartCard(service: service))

        let recent = Array(records.prefix(5))
        container.addArrangedSubview(buildRecentSessionsCard(records: recent))

        // 詳細ボタン
        let detailBtn = UIButton(type: .system)
        detailBtn.setTitle("詳細な練習記録を見る →", for: .normal)
        detailBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        detailBtn.setTitleColor(AppColor.accent, for: .normal)
        detailBtn.addTarget(self, action: #selector(openHistoryDetail), for: .touchUpInside)
        container.addArrangedSubview(detailBtn)

        let wrapper = UIView()
        wrapper.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: wrapper.topAnchor),
            container.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])
        return wrapper
    }

    private func buildHistoryEmptyCard() -> UIView {
        let card = makeHistoryCard()

        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: "chart.bar.fill", withConfiguration: iconCfg))
        iconView.tintColor   = AppColor.textSecondary.withAlphaComponent(0.5)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text          = "まだ練習記録がありません\n今日から始めましょう！"
        label.font          = UIFont.systemFont(ofSize: 14)
        label.textColor     = AppColor.textSecondary
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            label.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
        return card
    }

    private func buildActivityCard(service: PracticeHistoryService) -> UIView {
        let card = makeHistoryCard()
        let s    = service.summary()
        let week = service.weekActivity()

        let streakEmoji = UILabel()
        streakEmoji.text = s.streak >= 1 ? "🔥" : "📅"
        streakEmoji.font = UIFont.systemFont(ofSize: 22)
        streakEmoji.translatesAutoresizingMaskIntoConstraints = false

        let streakLabel = UILabel()
        streakLabel.text      = s.streak >= 1 ? "\(s.streak)日連続練習中！" : "今日から練習を始めよう！"
        streakLabel.font      = UIFont.systemFont(ofSize: 16, weight: .bold)
        streakLabel.textColor = s.streak >= 1 ? AppColor.accent : AppColor.textPrimary
        streakLabel.translatesAutoresizingMaskIntoConstraints = false

        let statsLabel = UILabel()
        statsLabel.text      = "今月 \(s.thisMonthCount)回  今年 \(s.thisYearCount)回"
        statsLabel.font      = UIFont.systemFont(ofSize: 11)
        statsLabel.textColor = AppColor.textSecondary
        statsLabel.translatesAutoresizingMaskIntoConstraints = false

        let streakRow = UIStackView(arrangedSubviews: [streakEmoji, streakLabel])
        streakRow.axis      = .horizontal
        streakRow.spacing   = 8
        streakRow.alignment = .center
        streakRow.translatesAutoresizingMaskIntoConstraints = false

        // Week dots row
        let calendar    = Calendar.current
        let today       = calendar.startOfDay(for: Date())
        let daySymbols  = ["日", "月", "火", "水", "木", "金", "土"]

        let dotsStack = UIStackView()
        dotsStack.axis         = .horizontal
        dotsStack.spacing      = 0
        dotsStack.distribution = .fillEqually
        dotsStack.translatesAutoresizingMaskIntoConstraints = false

        for offset in 0..<7 {
            let dayDate = calendar.date(byAdding: .day, value: -(6 - offset), to: today) ?? today
            let weekdayIndex = calendar.component(.weekday, from: dayDate) - 1
            let practiced = week[offset]

            let dot = UIView()
            dot.backgroundColor   = practiced ? AppColor.accent : AppColor.accent.withAlphaComponent(0.15)
            dot.layer.cornerRadius = 6
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 12).isActive  = true
            dot.heightAnchor.constraint(equalToConstant: 12).isActive = true

            let dayLbl = UILabel()
            dayLbl.text          = daySymbols[weekdayIndex]
            dayLbl.font          = UIFont.systemFont(ofSize: 10)
            dayLbl.textColor     = practiced ? AppColor.accent : AppColor.textSecondary
            dayLbl.textAlignment = .center

            let cell = UIStackView(arrangedSubviews: [dot, dayLbl])
            cell.axis      = .vertical
            cell.spacing   = 4
            cell.alignment = .center
            dotsStack.addArrangedSubview(cell)
        }

        card.addSubview(streakRow)
        card.addSubview(statsLabel)
        card.addSubview(dotsStack)
        NSLayoutConstraint.activate([
            streakRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            streakRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            statsLabel.centerYAnchor.constraint(equalTo: streakRow.centerYAnchor),
            statsLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            dotsStack.topAnchor.constraint(equalTo: streakRow.bottomAnchor, constant: 14),
            dotsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            dotsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            dotsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            dotsStack.heightAnchor.constraint(equalToConstant: 38),
        ])
        return card
    }

    private func buildMonthlyChartCard(service: PracticeHistoryService) -> UIView {
        let card         = makeHistoryCard()
        let currentYear  = Calendar.current.component(.year,  from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let monthly      = service.monthlyBreakdown(year: currentYear)
        let maxCount     = monthly.map { $0.count }.max() ?? 0
        let total        = monthly.reduce(0) { $0 + $1.count }

        let header = UILabel()
        header.text      = "\(currentYear)年"
        header.font      = UIFont.systemFont(ofSize: 14, weight: .semibold)
        header.textColor = AppColor.textSecondary
        header.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(header)

        let totalLabel = UILabel()
        totalLabel.text      = "計 \(total)回"
        totalLabel.font      = UIFont.systemFont(ofSize: 12)
        totalLabel.textColor = AppColor.textSecondary
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(totalLabel)

        let chartStack = UIStackView()
        chartStack.axis         = .horizontal
        chartStack.distribution = .fillEqually
        chartStack.alignment    = .fill
        chartStack.spacing      = 2
        chartStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(chartStack)

        let barAreaH: CGFloat = 48
        let labelH:   CGFloat = 14

        for item in monthly {
            let colView = UIView()
            colView.translatesAutoresizingMaskIntoConstraints = false

            let bar = UIView()
            let isCurrent = item.month == currentMonth
            bar.backgroundColor = isCurrent
                ? AppColor.accent
                : AppColor.accent.withAlphaComponent(item.count > 0 ? 0.45 : 0.12)
            bar.layer.cornerRadius = 3
            bar.translatesAutoresizingMaskIntoConstraints = false
            colView.addSubview(bar)

            let barH: CGFloat = maxCount > 0 ? max(4, barAreaH * CGFloat(item.count) / CGFloat(maxCount)) : 4

            let lbl = UILabel()
            lbl.text          = "\(item.month)"
            lbl.font          = UIFont.systemFont(ofSize: 9)
            lbl.textColor     = isCurrent ? AppColor.accent : AppColor.textSecondary
            lbl.textAlignment = .center
            lbl.translatesAutoresizingMaskIntoConstraints = false
            colView.addSubview(lbl)

            NSLayoutConstraint.activate([
                lbl.bottomAnchor.constraint(equalTo: colView.bottomAnchor),
                lbl.leadingAnchor.constraint(equalTo: colView.leadingAnchor),
                lbl.trailingAnchor.constraint(equalTo: colView.trailingAnchor),
                lbl.heightAnchor.constraint(equalToConstant: labelH),

                bar.bottomAnchor.constraint(equalTo: lbl.topAnchor, constant: -4),
                bar.centerXAnchor.constraint(equalTo: colView.centerXAnchor),
                bar.widthAnchor.constraint(equalToConstant: 14),
                bar.heightAnchor.constraint(equalToConstant: barH),
            ])
            chartStack.addArrangedSubview(colView)
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            totalLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            totalLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            chartStack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            chartStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            chartStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chartStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            chartStack.heightAnchor.constraint(equalToConstant: barAreaH + 4 + labelH),
        ])
        return card
    }

    private func buildRecentSessionsCard(records: [PracticeRecord]) -> UIView {
        let card = makeHistoryCard()

        let header = UILabel()
        header.text      = "最近の練習"
        header.font      = UIFont.systemFont(ofSize: 14, weight: .semibold)
        header.textColor = AppColor.textSecondary
        header.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(header)

        let divider = UIView()
        divider.backgroundColor = AppColor.separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(divider)

        var lastView: UIView = divider
        for record in records {
            let row = buildSessionRow(record: record)
            card.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 10),
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            ])
            lastView = row
        }

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            divider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            lastView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func buildSessionRow(record: PracticeRecord) -> UIView {
        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: record.type.symbolName, withConfiguration: iconCfg))
        iconView.tintColor   = AppColor.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 18).isActive  = true
        iconView.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let typeLabel = UILabel()
        typeLabel.text      = record.type.displayName
        typeLabel.font      = UIFont.systemFont(ofSize: 12, weight: .medium)
        typeLabel.textColor = AppColor.textSecondary

        let titleLabel = UILabel()
        titleLabel.text          = record.trackTitle.isEmpty ? "不明な曲" : record.trackTitle
        titleLabel.font          = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.lineBreakMode = .byTruncatingTail

        let infoStack = UIStackView(arrangedSubviews: [typeLabel, titleLabel])
        infoStack.axis    = .vertical
        infoStack.spacing = 1

        let scoreLabel = UILabel()
        if let pct = record.scorePercent {
            scoreLabel.text      = "\(pct)%"
            scoreLabel.font      = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            scoreLabel.textColor = pct >= 70 ? AppColor.accent : AppColor.textSecondary
        }
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [iconView, infoStack, scoreLabel])
        row.axis      = .horizontal
        row.spacing   = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        infoStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        return row
    }

    private func makeHistoryCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 18
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset  = CGSize(width: 0, height: 2)
        card.layer.shadowRadius  = 8
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    @objc private func openHistoryDetail() {
        navigationController?.pushViewController(PracticeHistoryViewController(), animated: true)
    }

    // MARK: UIAdaptivePresentationControllerDelegate

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        buildContent()
    }

    // MARK: Coming Soon

    private func showComingSoon(title: String, detail: String) {
        let alert = UIAlertController(title: title, message: detail, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: localText(key: "practice_coming_soon_ok"), style: .default))
        present(alert, animated: true)
    }

    // MARK: Helpers

    private func sectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.text      = text
        label.font      = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = AppColor.textPrimary
        return label
    }
}
