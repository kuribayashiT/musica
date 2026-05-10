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
    private var loopTimer: Timer?

    // MARK: Region state
    private var startRatio: CGFloat = 0.0
    private var endRatio:   CGFloat = 1.0
    private var isLoopEnabled = true

    private let musicController = MusicController()

    // MARK: Views
    private let songCard        = UIView()
    private let artView         = UIImageView()
    private let titleLabel      = UILabel()
    private let artistLabel     = UILabel()

    private let trackView       = RangeTrackView()
    private let currentTimeLbl  = UILabel()
    private let totalTimeLbl    = UILabel()
    private let loopSwitch      = UISwitch()
    private let loopLabel       = UILabel()

    private let playPauseBtn    = UIButton(type: .system)
    private let rewindBtn       = UIButton(type: .system)
    private let forwardBtn      = UIButton(type: .system)
    private let setStartBtn     = UIButton(type: .system)
    private let setEndBtn       = UIButton(type: .system)

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
        let saved = musicController.getSectionRepeatSetting(url: url)
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

        artView.contentMode       = .scaleAspectFill
        artView.clipsToBounds     = true
        artView.layer.cornerRadius = 10
        artView.backgroundColor   = AppColor.accent.withAlphaComponent(0.15)
        artView.translatesAutoresizingMaskIntoConstraints = false
        if let img = track.artworkImg {
            artView.image = img
        } else {
            artView.image       = UIImage(systemName: "music.note",
                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .thin))
            artView.tintColor   = AppColor.accent
            artView.contentMode = .center
        }

        titleLabel.text          = track.title.isEmpty ? "不明" : track.title
        titleLabel.font          = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        artistLabel.text      = track.artist.isEmpty ? "不明" : track.artist
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

        // セクションタイトル
        let sectionLabel = UILabel()
        sectionLabel.text      = localText(key: "section_repeat_range")
        sectionLabel.font      = UIFont.systemFont(ofSize: 15, weight: .bold)
        sectionLabel.textColor = AppColor.textPrimary
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false

        // ループ ON/OFF
        loopLabel.text      = localText(key: "section_repeat_loop")
        loopLabel.font      = UIFont.systemFont(ofSize: 14)
        loopLabel.textColor = AppColor.textSecondary
        loopLabel.translatesAutoresizingMaskIntoConstraints = false

        loopSwitch.isOn        = isLoopEnabled
        loopSwitch.onTintColor = AppColor.accent
        loopSwitch.addTarget(self, action: #selector(loopSwitchChanged), for: .valueChanged)
        loopSwitch.translatesAutoresizingMaskIntoConstraints = false

        // RangeTrackView
        let duration = audioPlayer?.duration ?? 0
        trackView.duration   = duration
        trackView.startRatio = startRatio
        trackView.endRatio   = endRatio
        trackView.translatesAutoresizingMaskIntoConstraints = false

        trackView.onStartChanged = { [weak self] v in self?.startRatio = v }
        trackView.onEndChanged   = { [weak self] v in self?.endRatio   = v }

        // 端時刻ラベル
        let startTimeLbl = UILabel()
        startTimeLbl.text      = "00:00"
        startTimeLbl.font      = UIFont.systemFont(ofSize: 11)
        startTimeLbl.textColor = AppColor.textSecondary
        startTimeLbl.translatesAutoresizingMaskIntoConstraints = false

        totalTimeLbl.text      = formatTimeString(d: duration)
        totalTimeLbl.font      = UIFont.systemFont(ofSize: 11)
        totalTimeLbl.textColor = AppColor.textSecondary
        totalTimeLbl.translatesAutoresizingMaskIntoConstraints = false

        // 現在位置ラベル
        currentTimeLbl.text      = "現在位置: 00:00"
        currentTimeLbl.font      = UIFont.systemFont(ofSize: 12)
        currentTimeLbl.textColor = AppColor.accent
        currentTimeLbl.textAlignment = .center
        currentTimeLbl.translatesAutoresizingMaskIntoConstraints = false

        // 現在位置セットボタン
        configSetButton(setStartBtn, title: "◀ スタートをここに", action: #selector(setStartTapped))
        configSetButton(setEndBtn,   title: "エンドをここに ▶",   action: #selector(setEndTapped))

        let btnStack = UIStackView(arrangedSubviews: [setStartBtn, setEndBtn])
        btnStack.axis         = .horizontal
        btnStack.distribution = .fillEqually
        btnStack.spacing      = 12
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        let divider = UIView()
        divider.backgroundColor = AppColor.textSecondary.withAlphaComponent(0.15)
        divider.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(sectionLabel)
        card.addSubview(loopLabel)
        card.addSubview(loopSwitch)
        card.addSubview(divider)
        card.addSubview(trackView)
        card.addSubview(startTimeLbl)
        card.addSubview(totalTimeLbl)
        card.addSubview(currentTimeLbl)
        card.addSubview(btnStack)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            sectionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),

            loopLabel.centerYAnchor.constraint(equalTo: sectionLabel.centerYAnchor),
            loopLabel.trailingAnchor.constraint(equalTo: loopSwitch.leadingAnchor, constant: -8),

            loopSwitch.centerYAnchor.constraint(equalTo: sectionLabel.centerYAnchor),
            loopSwitch.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            divider.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            divider.heightAnchor.constraint(equalToConstant: 1),

            trackView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 12),
            trackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            trackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            trackView.heightAnchor.constraint(equalToConstant: RangeTrackView.preferredHeight),

            startTimeLbl.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            startTimeLbl.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),

            totalTimeLbl.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            totalTimeLbl.trailingAnchor.constraint(equalTo: trackView.trailingAnchor),

            currentTimeLbl.topAnchor.constraint(equalTo: startTimeLbl.bottomAnchor, constant: 10),
            currentTimeLbl.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            btnStack.topAnchor.constraint(equalTo: currentTimeLbl.bottomAnchor, constant: 14),
            btnStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            btnStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            btnStack.heightAnchor.constraint(equalToConstant: 44),
            btnStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    private func configSetButton(_ btn: UIButton, title: String, action: Selector) {
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font   = UIFont.systemFont(ofSize: 12, weight: .medium)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth  = 1
        btn.layer.borderColor  = AppColor.accent.withAlphaComponent(0.4).cgColor
        btn.backgroundColor    = AppColor.accent.withAlphaComponent(0.08)
        btn.setTitleColor(AppColor.accent, for: .normal)
        btn.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: Player Card

    private func buildPlayerCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 18

        let cfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let smallCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)

        // ⟲5s
        rewindBtn.setImage(UIImage(systemName: "gobackward.5", withConfiguration: smallCfg), for: .normal)
        rewindBtn.tintColor = AppColor.textPrimary
        rewindBtn.addTarget(self, action: #selector(rewindTapped), for: .touchUpInside)
        rewindBtn.translatesAutoresizingMaskIntoConstraints = false

        // ▶/⏸
        playPauseBtn.setImage(UIImage(systemName: "play.fill", withConfiguration: cfg), for: .normal)
        playPauseBtn.tintColor = AppColor.accent
        playPauseBtn.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        playPauseBtn.translatesAutoresizingMaskIntoConstraints = false

        // 5s⟳
        forwardBtn.setImage(UIImage(systemName: "goforward.5", withConfiguration: smallCfg), for: .normal)
        forwardBtn.tintColor = AppColor.textPrimary
        forwardBtn.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)
        forwardBtn.translatesAutoresizingMaskIntoConstraints = false

        let btnStack = UIStackView(arrangedSubviews: [rewindBtn, playPauseBtn, forwardBtn])
        btnStack.axis         = .horizontal
        btnStack.spacing      = 32
        btnStack.alignment    = .center
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

        let icon = UIImageView(image: UIImage(systemName: "lightbulb.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)))
        icon.tintColor = AppColor.accent
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text          = "ハンドルをドラッグして区間を設定。「スタートをここに」ボタンで再生中の位置をすばやくセットできます。"
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

    // MARK: Actions

    @objc private func playPauseTapped() {
        guard let player = audioPlayer else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            updatePlayButton(playing: false)
        } else {
            // スタート位置より前なら先頭へ
            let startTime = TimeInterval(startRatio) * player.duration
            if player.currentTime < startTime {
                player.currentTime = startTime
            }
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
        startRatio = max(0, min(newRatio, endRatio - 0.01))
        trackView.startRatio = startRatio
        saveRegion()
        FA.log(FA.sectionRepeatSave, params: ["start": Double(startRatio), "end": Double(endRatio)])
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func setEndTapped() {
        guard let player = audioPlayer else { return }
        let newRatio = CGFloat(player.currentTime / player.duration)
        endRatio = max(startRatio + 0.01, min(newRatio, 1))
        trackView.endRatio = endRatio
        saveRegion()
        FA.log(FA.sectionRepeatSave, params: ["start": Double(startRatio), "end": Double(endRatio)])
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func loopSwitchChanged(_ sender: UISwitch) {
        isLoopEnabled = sender.isOn
        FA.log(FA.sectionRepeatToggle, params: ["enabled": sender.isOn])
        saveRegion()
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
        let ratio   = CGFloat(current / duration)

        // RangeTrackView の再生位置を更新
        trackView.positionRatio = ratio

        // 現在位置ラベル更新
        currentTimeLbl.text = "現在位置: \(formatTimeString(d: current))"

        // ループ処理
        if isPlaying && isLoopEnabled {
            let endTime = TimeInterval(endRatio) * duration
            if current >= endTime {
                let startTime = TimeInterval(startRatio) * duration
                player.currentTime = startTime
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func stopAll() {
        audioPlayer?.stop()
        positionUpdateTimer?.invalidate()
        positionUpdateTimer = nil
        loopTimer?.invalidate()
        loopTimer = nil
    }

    // MARK: Helpers

    private func updatePlayButton(playing: Bool) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let name = playing ? "pause.fill" : "play.fill"
        playPauseBtn.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }
}
