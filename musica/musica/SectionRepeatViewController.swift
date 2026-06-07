//
//  SectionRepeatViewController.swift
//  musica
//
//  練習タブ用の区間リピート画面。
//  RangeTrackView を常時表示し、指定区間をループ再生する。
//

import UIKit
import AVFoundation

final class SectionRepeatViewController: UIViewController {

    // MARK: Input
    var track: TrackData!

    // MARK: Audio
    private var audioPlayer: HighSpeedAudioPlayer?
    private var isPlaying = false

    // MARK: Region state
    private var startRatio: CGFloat = 0.0
    private var endRatio:   CGFloat = 1.0
    private var isLoopEnabled = true

    private let musicController = MusicController()

    // MARK: Views
    private let artView           = UIImageView()
    private let titleLabel        = UILabel()
    private let artistLabel       = UILabel()
    private let trackView         = RangeTrackView()
    private let rangeSummaryLabel = UILabel()   // "0:30  〜  1:15"
    private let startTimeBtnLabel = UILabel()   // セットボタン上の時刻
    private let endTimeBtnLabel   = UILabel()
    private let loopToggleBtn     = UIButton(type: .system)
    private let playPauseBtn      = UIButton(type: .system)
    private let rewindBtn         = UIButton(type: .system)
    private let forwardBtn        = UIButton(type: .system)

    private var positionUpdateTimer: Timer?

    // MARK: Lifecycle

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        FA.logScreen(FA.Screen.sectionRepeat, vc: "SectionRepeatViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        title = localText(key: "region_sheet_title")
        navigationItem.largeTitleDisplayMode = .never

        loadSavedRegion()
        setupAudio()
        setupLayout()
        startPositionUpdate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        saveRegion()
        stopAll()
        PracticeHistoryService.shared.add(PracticeRecord(
            id: UUID(),
            date: Date(),
            type: .sectionRepeat,
            trackTitle: track?.title ?? "",
            trackArtist: track?.artist ?? "",
            correctCount: 0,
            totalCount: 0
        ))
    }

    // MARK: Persistence

    private func loadSavedRegion() {
        guard let url = track.url else { return }
        let saved     = musicController.getSectionRepeatSetting(url: url)
        startRatio    = saved[0]
        endRatio      = saved[1]
        isLoopEnabled = musicController.getSectionRepeatEnabled(url: url)
    }

    private func saveRegion() {
        guard let url = track.url else { return }
        musicController.setSectionRepeatSettings(playData: track, time: [startRatio, endRatio])
        musicController.setSectionRepeatEnabled(url: url, isEnabled: isLoopEnabled)
    }

    // MARK: Audio

    private func setupAudio() {
        guard let url = track.url else { return }
        audioPlayer = try? HighSpeedAudioPlayer(contentsOf: url)
        audioPlayer?.prepareToPlay()
        let rate = Float(speedList[min(speedRow, speedList.count - 1)])
        audioPlayer?.rate = rate
    }

    // MARK: Layout

    private func setupLayout() {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis    = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
        ])

        stack.addArrangedSubview(buildSongCard())
        stack.addArrangedSubview(buildRegionCard())
        stack.addArrangedSubview(buildPlayerCard())
        stack.addArrangedSubview(buildTipsCard())
    }

    // MARK: Song Card

    private func buildSongCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 16

        artView.contentMode        = .scaleAspectFill
        artView.clipsToBounds      = true
        artView.layer.cornerRadius = 10
        artView.backgroundColor    = AppColor.accent.withAlphaComponent(0.15)
        artView.translatesAutoresizingMaskIntoConstraints = false
        if let img = track.artworkImg {
            artView.image = img
        } else {
            artView.image       = UIImage(systemName: "music.note",
                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .thin))
            artView.tintColor   = AppColor.accent
            artView.contentMode = .center
        }

        titleLabel.text          = track.title.isEmpty  ? localText(key: "practice_unknown") : track.title
        titleLabel.font          = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        artistLabel.text      = track.artist.isEmpty ? localText(key: "practice_unknown") : track.artist
        artistLabel.font      = UIFont.systemFont(ofSize: 13)
        artistLabel.textColor = AppColor.textSecondary
        artistLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, artistLabel])
        textStack.axis    = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(artView)
        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            artView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            artView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            artView.widthAnchor.constraint(equalToConstant: 52),
            artView.heightAnchor.constraint(equalToConstant: 52),

            textStack.leadingAnchor.constraint(equalTo: artView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            card.heightAnchor.constraint(equalToConstant: 80),
        ])
        return card
    }

    // MARK: Region Card

    private func buildRegionCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 18

        // ── ヘッダー: タイトル + ループトグルボタン ──
        let sectionLabel = UILabel()
        sectionLabel.text      = localText(key: "section_repeat_range")
        sectionLabel.font      = UIFont.systemFont(ofSize: 15, weight: .bold)
        sectionLabel.textColor = AppColor.textPrimary
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        updateLoopToggleAppearance()
        loopToggleBtn.layer.cornerRadius = 14
        loopToggleBtn.clipsToBounds      = true
        loopToggleBtn.addTarget(self, action: #selector(loopToggleTapped), for: .touchUpInside)
        loopToggleBtn.translatesAutoresizingMaskIntoConstraints = false

        // ── 仕切り線 ──
        let divider = UIView()
        divider.backgroundColor = AppColor.textSecondary.withAlphaComponent(0.15)
        divider.translatesAutoresizingMaskIntoConstraints = false

        // ── RangeTrackView ──
        let duration = audioPlayer?.duration ?? 0
        trackView.duration   = duration
        trackView.startRatio = startRatio
        trackView.endRatio   = endRatio
        trackView.translatesAutoresizingMaskIntoConstraints = false
        trackView.onStartChanged = { [weak self] v in
            guard let self else { return }
            self.startRatio = v
            self.updateRangeDisplay()
        }
        trackView.onEndChanged = { [weak self] v in
            guard let self else { return }
            self.endRatio = v
            self.updateRangeDisplay()
        }

        // ── 端時刻ラベル (00:00 / 総時間) ──
        let startEdgeLbl = UILabel()
        startEdgeLbl.text      = "00:00"
        startEdgeLbl.font      = UIFont.systemFont(ofSize: 11)
        startEdgeLbl.textColor = AppColor.textSecondary
        startEdgeLbl.translatesAutoresizingMaskIntoConstraints = false

        let endEdgeLbl = UILabel()
        endEdgeLbl.text      = formatTimeString(d: duration)
        endEdgeLbl.font      = UIFont.systemFont(ofSize: 11)
        endEdgeLbl.textColor = AppColor.textSecondary
        endEdgeLbl.translatesAutoresizingMaskIntoConstraints = false

        // ── 区間サマリー（大きく中央表示） ──
        rangeSummaryLabel.font                     = UIFont.monospacedDigitSystemFont(ofSize: 26, weight: .bold)
        rangeSummaryLabel.textColor                = AppColor.textPrimary
        rangeSummaryLabel.textAlignment            = .center
        rangeSummaryLabel.adjustsFontSizeToFitWidth = true
        rangeSummaryLabel.minimumScaleFactor        = 0.65
        rangeSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        updateRangeDisplay()

        // ── セットボタン ──
        let startBtnView = makeSetButtonView(
            timeLbl:    startTimeBtnLabel,
            actionText: localText(key: "section_repeat_set_start"),
            isStart:    true,
            action:     #selector(setStartTapped)
        )
        let endBtnView = makeSetButtonView(
            timeLbl:    endTimeBtnLabel,
            actionText: localText(key: "section_repeat_set_end"),
            isStart:    false,
            action:     #selector(setEndTapped)
        )

        let btnStack = UIStackView(arrangedSubviews: [startBtnView, endBtnView])
        btnStack.axis         = .horizontal
        btnStack.distribution = .fillEqually
        btnStack.spacing      = 12
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(sectionLabel)
        card.addSubview(loopToggleBtn)
        card.addSubview(divider)
        card.addSubview(trackView)
        card.addSubview(startEdgeLbl)
        card.addSubview(endEdgeLbl)
        card.addSubview(rangeSummaryLabel)
        card.addSubview(btnStack)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            sectionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            sectionLabel.trailingAnchor.constraint(lessThanOrEqualTo: loopToggleBtn.leadingAnchor, constant: -8),

            loopToggleBtn.centerYAnchor.constraint(equalTo: sectionLabel.centerYAnchor),
            loopToggleBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            loopToggleBtn.heightAnchor.constraint(equalToConstant: 28),

            divider.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            divider.heightAnchor.constraint(equalToConstant: 1),

            trackView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 16),
            trackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            trackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            trackView.heightAnchor.constraint(equalToConstant: RangeTrackView.preferredHeight),

            startEdgeLbl.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            startEdgeLbl.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),

            endEdgeLbl.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            endEdgeLbl.trailingAnchor.constraint(equalTo: trackView.trailingAnchor),

            rangeSummaryLabel.topAnchor.constraint(equalTo: startEdgeLbl.bottomAnchor, constant: 20),
            rangeSummaryLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            rangeSummaryLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            btnStack.topAnchor.constraint(equalTo: rangeSummaryLabel.bottomAnchor, constant: 16),
            btnStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            btnStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            btnStack.heightAnchor.constraint(equalToConstant: 64),
            btnStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    /// 再生位置をスタート/エンドにセットするボタン（時刻＋説明ラベル付き）
    private func makeSetButtonView(timeLbl: UILabel,
                                   actionText: String,
                                   isStart: Bool,
                                   action: Selector) -> UIControl {
        let ctrl = UIControl()
        ctrl.backgroundColor    = AppColor.accent.withAlphaComponent(0.1)
        ctrl.layer.cornerRadius = 14
        ctrl.addTarget(self, action: action, for: .touchUpInside)

        let iconName = isStart ? "arrow.right.to.line" : "arrow.left.to.line"
        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: iconCfg))
        iconView.tintColor   = AppColor.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        timeLbl.font          = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        timeLbl.textColor     = AppColor.accent
        timeLbl.textAlignment = .center
        timeLbl.translatesAutoresizingMaskIntoConstraints = false

        let actionLbl = UILabel()
        actionLbl.text          = actionText
        actionLbl.font          = UIFont.systemFont(ofSize: 10)
        actionLbl.textColor     = AppColor.textSecondary
        actionLbl.textAlignment = .center
        actionLbl.numberOfLines = 1
        actionLbl.adjustsFontSizeToFitWidth = true
        actionLbl.minimumScaleFactor = 0.8
        actionLbl.translatesAutoresizingMaskIntoConstraints = false

        ctrl.addSubview(iconView)
        ctrl.addSubview(timeLbl)
        ctrl.addSubview(actionLbl)

        NSLayoutConstraint.activate([
            timeLbl.centerXAnchor.constraint(equalTo: ctrl.centerXAnchor),
            timeLbl.centerYAnchor.constraint(equalTo: ctrl.centerYAnchor, constant: -9),

            iconView.centerYAnchor.constraint(equalTo: timeLbl.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            actionLbl.topAnchor.constraint(equalTo: timeLbl.bottomAnchor, constant: 4),
            actionLbl.leadingAnchor.constraint(equalTo: ctrl.leadingAnchor, constant: 6),
            actionLbl.trailingAnchor.constraint(equalTo: ctrl.trailingAnchor, constant: -6),
        ])

        if isStart {
            iconView.trailingAnchor.constraint(equalTo: timeLbl.leadingAnchor, constant: -4).isActive = true
        } else {
            iconView.leadingAnchor.constraint(equalTo: timeLbl.trailingAnchor, constant: 4).isActive = true
        }

        return ctrl
    }

    // MARK: Player Card

    private func buildPlayerCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 18

        let cfg      = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let smallCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)

        rewindBtn.setImage(UIImage(systemName: "gobackward.5", withConfiguration: smallCfg), for: .normal)
        rewindBtn.tintColor = AppColor.textPrimary
        rewindBtn.addTarget(self, action: #selector(rewindTapped), for: .touchUpInside)
        rewindBtn.translatesAutoresizingMaskIntoConstraints = false

        playPauseBtn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
        playPauseBtn.tintColor = AppColor.accent
        playPauseBtn.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        playPauseBtn.translatesAutoresizingMaskIntoConstraints = false

        forwardBtn.setImage(UIImage(systemName: "goforward.5", withConfiguration: smallCfg), for: .normal)
        forwardBtn.tintColor = AppColor.textPrimary
        forwardBtn.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)
        forwardBtn.translatesAutoresizingMaskIntoConstraints = false

        let btnStack = UIStackView(arrangedSubviews: [rewindBtn, playPauseBtn, forwardBtn])
        btnStack.axis      = .horizontal
        btnStack.spacing   = 32
        btnStack.alignment = .center
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(btnStack)
        NSLayoutConstraint.activate([
            btnStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            btnStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            btnStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            rewindBtn.widthAnchor.constraint(equalToConstant: 44),
            rewindBtn.heightAnchor.constraint(equalToConstant: 44),
            playPauseBtn.widthAnchor.constraint(equalToConstant: 56),
            playPauseBtn.heightAnchor.constraint(equalToConstant: 56),
            forwardBtn.widthAnchor.constraint(equalToConstant: 44),
            forwardBtn.heightAnchor.constraint(equalToConstant: 44),
        ])
        return card
    }

    // MARK: Tips Card

    private func buildTipsCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.accent.withAlphaComponent(0.08)
        card.layer.cornerRadius = 14

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let icon    = UIImageView(image: UIImage(systemName: "lightbulb.fill", withConfiguration: iconCfg))
        icon.tintColor = AppColor.accent
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text          = localText(key: "section_repeat_tips")
        label.font          = UIFont.systemFont(ofSize: 12)
        label.textColor     = AppColor.accent
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),

            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        return card
    }

    // MARK: Display Updates

    private func updateRangeDisplay() {
        let duration = audioPlayer?.duration ?? 0
        let startT   = TimeInterval(startRatio) * duration
        let endT     = TimeInterval(endRatio)   * duration
        rangeSummaryLabel.text = "\(formatTimeString(d: startT))  〜  \(formatTimeString(d: endT))"
        startTimeBtnLabel.text = formatTimeString(d: startT)
        endTimeBtnLabel.text   = formatTimeString(d: endT)
    }

    private func updateLoopToggleAppearance() {
        let cfg   = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let title = isLoopEnabled
            ? localText(key: "section_repeat_loop_on")
            : localText(key: "section_repeat_loop_off")
        loopToggleBtn.setImage(UIImage(systemName: "repeat", withConfiguration: cfg), for: .normal)
        loopToggleBtn.setTitle(title, for: .normal)
        loopToggleBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        loopToggleBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 12)
        let isOn = isLoopEnabled
        loopToggleBtn.tintColor      = isOn ? AppColor.accent : AppColor.textSecondary
        loopToggleBtn.setTitleColor(isOn ? AppColor.accent : AppColor.textSecondary, for: .normal)
        loopToggleBtn.backgroundColor = isOn
            ? AppColor.accent.withAlphaComponent(0.12)
            : AppColor.textSecondary.withAlphaComponent(0.1)
    }

    // MARK: Actions

    @objc private func playPauseTapped() {
        guard let player = audioPlayer else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            updatePlayButton(playing: false)
        } else {
            let startTime = TimeInterval(startRatio) * player.duration
            if player.currentTime < startTime { player.currentTime = startTime }
            player.play()
            isPlaying = true
            updatePlayButton(playing: true)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func rewindTapped() {
        guard let player = audioPlayer else { return }
        let startTime = TimeInterval(startRatio) * player.duration
        player.currentTime = max(startTime, player.currentTime - 5)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func forwardTapped() {
        guard let player = audioPlayer else { return }
        let endTime = TimeInterval(endRatio) * player.duration
        player.currentTime = min(endTime - 0.1, player.currentTime + 5)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func setStartTapped() {
        guard let player = audioPlayer else { return }
        let newRatio = CGFloat(player.currentTime / player.duration)
        startRatio           = max(0, min(newRatio, endRatio - 0.01))
        trackView.startRatio = startRatio
        updateRangeDisplay()
        saveRegion()
        FA.log(FA.sectionRepeatSave, params: ["start": Double(startRatio), "end": Double(endRatio)])
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func setEndTapped() {
        guard let player = audioPlayer else { return }
        let newRatio = CGFloat(player.currentTime / player.duration)
        endRatio           = max(startRatio + 0.01, min(newRatio, 1))
        trackView.endRatio = endRatio
        updateRangeDisplay()
        saveRegion()
        FA.log(FA.sectionRepeatSave, params: ["start": Double(startRatio), "end": Double(endRatio)])
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func loopToggleTapped() {
        isLoopEnabled = !isLoopEnabled
        updateLoopToggleAppearance()
        saveRegion()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: Position Monitoring

    private func startPositionUpdate() {
        positionUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePosition()
        }
    }

    private func updatePosition() {
        guard let player = audioPlayer else { return }
        let duration = player.duration
        guard duration > 0 else { return }

        let current = player.currentTime
        trackView.positionRatio = CGFloat(current / duration)

        if isPlaying && isLoopEnabled {
            let endTime = TimeInterval(endRatio) * duration
            if current >= endTime {
                player.currentTime = TimeInterval(startRatio) * duration
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func stopAll() {
        audioPlayer?.stop()
        positionUpdateTimer?.invalidate()
        positionUpdateTimer = nil
    }

    private func updatePlayButton(playing: Bool) {
        let cfg  = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let name = playing ? "pause.fill" : "play.fill"
        playPauseBtn.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }
}
