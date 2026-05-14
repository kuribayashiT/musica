//
//  DictationSetupViewController.swift
//  musica
//
//  ディクテーション開始前のセットアップ画面。
//  テキストがなければ WhisperKit（Small・全自動）で文字起こしする。
//

import UIKit
import GoogleMobileAds
import MediaPlayer
import Speech
import NaturalLanguage
import WebKit
import PhotosUI
import Vision

// MARK: - DictationSetupViewController

final class DictationSetupViewController: UIViewController {

    // MARK: Input

    var track: TrackData!
    var trackIndex: Int = 0
    var libraryName: String = ""

    // YouTube ルート（videoID が設定されている場合は字幕取得モードになる）
    var youtubeVideoID: String? = nil

    private var captionFetcher: YouTubeCaptionFetcher?

    // MARK: Private

    private var rewardedAd: RewardedAd?
    private var currentLyrics: String = ""

    // MARK: Language Selection

    /// nil = すべての言語を対象（初期値: 英語）
    private var selectedLyricLang: NLLanguage? = .english
    private var detectedLanguages: [NLLanguage] = []
    private let langScrollView = UIScrollView()
    private let langStack      = UIStackView()
    private let langSectionCard = UIView()

    // MARK: Views

    private let scrollView = UIScrollView()
    private let stack      = UIStackView()

    private let statusCard  = UIView()
    private let statusIcon  = UIImageView()
    private let statusLabel = UILabel()
    private let statusSub   = UILabel()

    private let fetchBtn          = UIButton(type: .system)
    private let transcribeBtn     = UIButton(type: .system)
    private let whisperBtn        = UIButton(type: .system)
    private let imageOCRBtn       = UIButton(type: .system)
    private let cameraOCRBtn      = UIButton(type: .system)
    private let manualInputBtn    = UIButton(type: .system)   // 手動入力
    private let ocrSectionLabel   = UILabel()                 // OCR系のセクション見出し（非表示・後方互換）
    private let otherMethodsToggle = UIButton(type: .system)  // 折りたたみトグル
    private var isOtherMethodsExpanded = false
    private let youtubeCaptionBtn = UIButton(type: .system)
    private let openYoutubeBtn    = UIButton(type: .system)
    private let startBtn          = UIButton(type: .system)
    private let loadingIndicator  = UIActivityIndicatorView(style: .medium) // 後方互換・非表示
    private let progressLabel     = UILabel()                               // 後方互換・非表示

    private var transcriptionOverlay: TranscriptionLoadingOverlay?
    private var cancelTranscription: (() -> Void)?
    private var whisperTask: Task<Void, Never>?

    // MARK: Lifecycle

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        FA.logScreen(FA.Screen.dictationSetup, vc: "DictationSetupViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        title = localText(key: "dictation_title")
        navigationItem.largeTitleDisplayMode = .never

        setupLayout()
        if youtubeVideoID != nil {
            setupYoutubeRoute()
        } else {
            refresh(with: track.lyric)
            preloadRewardedAd()
        }
    }

    // MARK: Layout

    private func setupLayout() {
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
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
        ])

        // 曲情報カード
        stack.addArrangedSubview(buildSongCard())

        // ステータスカード
        setupStatusCard()
        stack.addArrangedSubview(statusCard)

        // 言語選択カード（歌詞があるときだけ表示）
        setupLangSectionCard()
        stack.addArrangedSubview(langSectionCard)

        // YouTube字幕入力ボタン（YouTubeルートのみ表示）
        setupYoutubeCaptionButton()
        stack.addArrangedSubview(youtubeCaptionBtn)

        // YouTubeを開くボタン（YouTubeルートのみ表示）
        setupOpenYoutubeButton()
        stack.addArrangedSubview(openYoutubeBtn)

        // WhisperKit 文字起こしボタン（iOS 16以上のみ表示）
        setupWhisperButton()
        stack.addArrangedSubview(whisperBtn)

        // OCRセクション見出し（非表示・後方互換のため残す）
        ocrSectionLabel.isHidden = true
        stack.addArrangedSubview(ocrSectionLabel)

        // 「その他の方法」折りたたみトグル
        setupOtherMethodsToggle()
        stack.addArrangedSubview(otherMethodsToggle)

        // 画像OCRボタン（折りたたみ内・初期非表示）
        setupImageOCRButton()
        stack.addArrangedSubview(imageOCRBtn)

        // カメラOCRボタン（折りたたみ内・初期非表示）
        setupCameraOCRButton()
        stack.addArrangedSubview(cameraOCRBtn)

        // 手動入力ボタン（折りたたみ内・初期非表示）
        setupManualInputButton()
        stack.addArrangedSubview(manualInputBtn)

        // 練習開始ボタン
        setupStartButton()
        stack.addArrangedSubview(startBtn)

        // 中間結果ラベル
        progressLabel.font          = UIFont.systemFont(ofSize: 12)
        progressLabel.textColor     = AppColor.textSecondary
        progressLabel.numberOfLines = 3
        progressLabel.textAlignment = .center
        progressLabel.isHidden      = true
        stack.addArrangedSubview(progressLabel)

        // ローディング（TranscriptionService 用・従来のスピナー）
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        // WhisperKit 文字起こしオーバーレイ（全画面）
        let overlay = TranscriptionLoadingOverlay()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.alpha    = 0
        overlay.isHidden = true
        overlay.cancelAction = { [weak self] in self?.cancelWhisperTapped() }
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        transcriptionOverlay = overlay
    }

    // MARK: Song Card

    private func buildSongCard() -> UIView {
        let card = UIView()
        card.backgroundColor  = AppColor.surface
        card.layer.cornerRadius = 16
        card.clipsToBounds    = true

        let artView = UIImageView()
        artView.contentMode  = .scaleAspectFill
        artView.clipsToBounds = true
        artView.layer.cornerRadius = 10
        artView.backgroundColor = AppColor.accent.withAlphaComponent(0.15)
        artView.translatesAutoresizingMaskIntoConstraints = false
        if let img = track.artworkImg {
            artView.image = img
        } else {
            artView.image = UIImage(systemName: "music.note",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .thin))
            artView.tintColor    = AppColor.accent
            artView.contentMode  = .center
        }

        let titleLabel = UILabel()
        titleLabel.text          = track.title.isEmpty ? localText(key: "practice_unknown") : track.title
        titleLabel.font          = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.numberOfLines = 2

        let artistLabel = UILabel()
        artistLabel.text      = track.artist.isEmpty ? localText(key: "practice_unknown") : track.artist
        artistLabel.font      = UIFont.systemFont(ofSize: 13)
        artistLabel.textColor = AppColor.textSecondary

        let textStack = UIStackView(arrangedSubviews: [titleLabel, artistLabel])
        textStack.axis    = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(artView)
        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            artView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            artView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            artView.widthAnchor.constraint(equalToConstant: 56),
            artView.heightAnchor.constraint(equalToConstant: 56),

            textStack.leadingAnchor.constraint(equalTo: artView.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            card.heightAnchor.constraint(equalToConstant: 88),
        ])
        return card
    }

    // MARK: Status Card

    private func setupStatusCard() {
        statusCard.backgroundColor  = AppColor.surface
        statusCard.layer.cornerRadius = 16

        statusIcon.contentMode = .scaleAspectFit
        statusIcon.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font          = UIFont.systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor     = AppColor.textPrimary
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        statusSub.font          = UIFont.systemFont(ofSize: 13)
        statusSub.textColor     = AppColor.textSecondary
        statusSub.numberOfLines = 0
        statusSub.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [statusLabel, statusSub])
        textStack.axis    = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        statusCard.addSubview(statusIcon)
        statusCard.addSubview(textStack)
        NSLayoutConstraint.activate([
            statusIcon.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 20),
            statusIcon.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 18),
            statusIcon.widthAnchor.constraint(equalToConstant: 32),
            statusIcon.heightAnchor.constraint(equalToConstant: 32),

            textStack.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 20),
            textStack.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -18),
            textStack.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -20),
        ])
    }

    // MARK: Buttons

    private func setupFetchButton() {
        fetchBtn.setTitle(localText(key: "dictsetup_fetch_btn"), for: .normal)
        fetchBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 16, weight: .semibold)
        fetchBtn.backgroundColor   = AppColor.accent
        fetchBtn.setTitleColor(.white, for: .normal)
        fetchBtn.layer.cornerRadius = 14
        fetchBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        fetchBtn.addTarget(self, action: #selector(fetchTapped), for: .touchUpInside)
    }

    private func setupTranscribeButton() {
        transcribeBtn.setTitle(localText(key: "dictsetup_transcribe_btn"), for: .normal)
        transcribeBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 16, weight: .semibold)
        transcribeBtn.backgroundColor   = AppColor.surface
        transcribeBtn.setTitleColor(AppColor.accent, for: .normal)
        transcribeBtn.layer.cornerRadius = 14
        transcribeBtn.layer.borderWidth  = 1.5
        transcribeBtn.layer.borderColor  = AppColor.accent.cgColor
        transcribeBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        transcribeBtn.addTarget(self, action: #selector(transcribeTapped), for: .touchUpInside)
    }

    private func setupWhisperButton() {
        whisperBtn.setTitle(localText(key: "dictsetup_whisper_btn"), for: .normal)
        whisperBtn.titleLabel?.font   = UIFont.systemFont(ofSize: 16, weight: .semibold)
        whisperBtn.backgroundColor    = UIColor.systemIndigo
        whisperBtn.setTitleColor(.white, for: .normal)
        whisperBtn.layer.cornerRadius = 14
        whisperBtn.heightAnchor.constraint(equalToConstant: 56).isActive = true
        whisperBtn.addTarget(self, action: #selector(whisperTapped), for: .touchUpInside)

        // 「おすすめ」バッジ
        let badge = UILabel()
        badge.text            = localText(key: "dictsetup_recommended_badge")
        badge.font            = UIFont.systemFont(ofSize: 10, weight: .bold)
        badge.textColor       = UIColor.systemIndigo
        badge.backgroundColor = .white
        badge.textAlignment   = .center
        badge.layer.cornerRadius = 8
        badge.clipsToBounds   = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        whisperBtn.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: whisperBtn.topAnchor, constant: -8),
            badge.trailingAnchor.constraint(equalTo: whisperBtn.trailingAnchor, constant: -12),
            badge.heightAnchor.constraint(equalToConstant: 18),
            badge.widthAnchor.constraint(equalToConstant: 52),
        ])

        // iOS 16 未満は非表示
        if #available(iOS 16, *) { } else {
            whisperBtn.isHidden = true
        }
    }

    private func setupImageOCRButton() {
        imageOCRBtn.setTitle(localText(key: "dictsetup_image_ocr_btn"), for: .normal)
        imageOCRBtn.titleLabel?.font   = UIFont.systemFont(ofSize: 16, weight: .semibold)
        imageOCRBtn.backgroundColor    = AppColor.surfaceSecondary
        imageOCRBtn.setTitleColor(AppColor.textPrimary, for: .normal)
        imageOCRBtn.layer.cornerRadius = 14
        imageOCRBtn.layer.borderWidth  = 1.5
        imageOCRBtn.layer.borderColor  = AppColor.accent.withAlphaComponent(0.4).cgColor
        imageOCRBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        imageOCRBtn.addTarget(self, action: #selector(imageOCRTapped), for: .touchUpInside)
        imageOCRBtn.isHidden = true
    }

    private func setupCameraOCRButton() {
        cameraOCRBtn.setTitle(localText(key: "dictsetup_camera_ocr_btn"), for: .normal)
        cameraOCRBtn.titleLabel?.font   = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cameraOCRBtn.backgroundColor    = AppColor.surfaceSecondary
        cameraOCRBtn.setTitleColor(AppColor.textPrimary, for: .normal)
        cameraOCRBtn.layer.cornerRadius = 14
        cameraOCRBtn.layer.borderWidth  = 1.5
        cameraOCRBtn.layer.borderColor  = AppColor.accent.withAlphaComponent(0.4).cgColor
        cameraOCRBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        cameraOCRBtn.addTarget(self, action: #selector(cameraOCRTapped), for: .touchUpInside)
        // カメラが使えない端末は非表示
        cameraOCRBtn.isHidden = !UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    private func setupManualInputButton() {
        manualInputBtn.setTitle(localText(key: "dictsetup_manual_btn"), for: .normal)
        manualInputBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        manualInputBtn.setTitleColor(AppColor.textSecondary, for: .normal)
        manualInputBtn.addTarget(self, action: #selector(manualInputTapped), for: .touchUpInside)
        manualInputBtn.isHidden = true
    }

    @objc private func cancelWhisperTapped() {
        whisperTask?.cancel()
        cancelTranscription?()
        cancelTranscription = nil
        setWhisperLoading(false)
    }

    private func setupOtherMethodsToggle() {
        updateOtherMethodsToggleTitle()
        otherMethodsToggle.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        otherMethodsToggle.setTitleColor(AppColor.textSecondary, for: .normal)
        otherMethodsToggle.addTarget(self, action: #selector(toggleOtherMethods), for: .touchUpInside)
        otherMethodsToggle.isHidden = true
    }

    private func updateOtherMethodsToggleTitle() {
        let arrow = isOtherMethodsExpanded ? "chevron.up" : "chevron.down"
        let title = isOtherMethodsExpanded ? localText(key: "dictsetup_other_methods_close") : localText(key: "dictsetup_other_methods_open")
        let img   = UIImage(systemName: arrow,
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        otherMethodsToggle.setTitle("  " + title, for: .normal)
        otherMethodsToggle.setImage(img, for: .normal)
        otherMethodsToggle.tintColor = AppColor.textSecondary
        otherMethodsToggle.semanticContentAttribute = .forceRightToLeft
    }

    @objc private func toggleOtherMethods() {
        isOtherMethodsExpanded.toggle()
        updateOtherMethodsToggleTitle()
        UIView.animate(withDuration: 0.22) {
            self.imageOCRBtn.isHidden  = !self.isOtherMethodsExpanded
            self.cameraOCRBtn.isHidden = !(self.isOtherMethodsExpanded
                                           && UIImagePickerController.isSourceTypeAvailable(.camera))
            self.manualInputBtn.isHidden = !self.isOtherMethodsExpanded
            self.stack.layoutIfNeeded()
        }
    }

    private func setupStartButton() {
        startBtn.setTitle(localText(key: "practice_start_btn"), for: .normal)
        startBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 16, weight: .semibold)
        startBtn.backgroundColor   = AppColor.accent
        startBtn.setTitleColor(.white, for: .normal)
        startBtn.layer.cornerRadius = 14
        startBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        startBtn.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
    }

    private func setupYoutubeCaptionButton() {
        youtubeCaptionBtn.setTitle(localText(key: "dictsetup_caption_input_btn"), for: .normal)
        youtubeCaptionBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 16, weight: .semibold)
        youtubeCaptionBtn.backgroundColor   = AppColor.accent
        youtubeCaptionBtn.setTitleColor(.white, for: .normal)
        youtubeCaptionBtn.layer.cornerRadius = 14
        youtubeCaptionBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        youtubeCaptionBtn.addTarget(self, action: #selector(youtubeCaptionTapped), for: .touchUpInside)
        youtubeCaptionBtn.isHidden = true
    }

    private func setupOpenYoutubeButton() {
        openYoutubeBtn.setTitle(localText(key: "dictsetup_youtube_open_btn"), for: .normal)
        openYoutubeBtn.setImage(UIImage(systemName: "arrow.up.right.square"), for: .normal)
        openYoutubeBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 15, weight: .medium)
        openYoutubeBtn.backgroundColor   = AppColor.surfaceSecondary
        openYoutubeBtn.setTitleColor(AppColor.textPrimary, for: .normal)
        openYoutubeBtn.tintColor         = AppColor.textPrimary
        openYoutubeBtn.imageEdgeInsets   = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        openYoutubeBtn.titleEdgeInsets   = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        openYoutubeBtn.layer.cornerRadius = 14
        openYoutubeBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        openYoutubeBtn.addTarget(self, action: #selector(openYoutubeTapped), for: .touchUpInside)
        openYoutubeBtn.isHidden = true
    }

    // MARK: YouTube Route

    private func setupYoutubeRoute() {
        guard let videoID = youtubeVideoID else { return }

        fetchBtn.isHidden           = true
        transcribeBtn.isHidden      = true
        whisperBtn.isHidden         = true
        ocrSectionLabel.isHidden    = true
        otherMethodsToggle.isHidden = true
        imageOCRBtn.isHidden        = true
        cameraOCRBtn.isHidden       = true
        manualInputBtn.isHidden     = true
        youtubeCaptionBtn.isHidden  = false
        openYoutubeBtn.isHidden     = true  // 字幕登録画面内に移動

        if let saved = YoutubeCaptionStore.load(for: videoID) {
            // 保存済み字幕あり → そのまま練習できる状態に
            refresh(with: saved)
            youtubeCaptionBtn.setTitle(localText(key: "dictsetup_caption_edit_btn"), for: .normal)
            youtubeCaptionBtn.backgroundColor = AppColor.surfaceSecondary
            youtubeCaptionBtn.setTitleColor(AppColor.textPrimary, for: .normal)
        } else {
            // 未保存 → 入力を促す
            let iconCfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            statusIcon.image     = UIImage(systemName: "text.bubble.fill", withConfiguration: iconCfg)
            statusIcon.tintColor = AppColor.accent
            statusLabel.text     = localText(key: "dictsetup_caption_hint")
            statusSub.text       = localText(key: "dictsetup_caption_instruction")
            startBtn.isHidden = true
            youtubeCaptionBtn.setTitle(localText(key: "dictsetup_caption_input_btn"), for: .normal)
            youtubeCaptionBtn.backgroundColor = AppColor.accent
            youtubeCaptionBtn.setTitleColor(.white, for: .normal)
        }
    }

    @objc private func youtubeCaptionTapped() {
        guard let videoID = youtubeVideoID else { return }
        let existing = YoutubeCaptionStore.load(for: videoID) ?? ""
        let editorVC = CaptionTextEditorViewController()
        editorVC.videoID     = videoID
        editorVC.initialText = existing
        editorVC.onSave = { [weak self] text in
            guard let self else { return }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                YoutubeCaptionStore.delete(for: videoID)
            } else {
                YoutubeCaptionStore.save(text, for: videoID)
            }
            self.setupYoutubeRoute()
        }
        let nav = UINavigationController(rootViewController: editorVC)
        if #available(iOS 15, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
            }
        }
        present(nav, animated: true)
    }

    @objc private func openYoutubeTapped() {
        guard let videoID = youtubeVideoID else { return }
        // YouTube アプリがあればアプリで開く（文字起こし機能が使いやすい）
        if let appURL = URL(string: "youtube://watch?v=\(videoID)"),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)") {
            UIApplication.shared.open(webURL)
        }
    }

    // MARK: Language Section

    private func setupLangSectionCard() {
        langSectionCard.backgroundColor  = AppColor.surface
        langSectionCard.layer.cornerRadius = 16
        langSectionCard.isHidden = true   // 歌詞が揃うまで非表示

        let headerLabel = UILabel()
        headerLabel.text      = localText(key: "dictsetup_lang_header")
        headerLabel.font      = UIFont.systemFont(ofSize: 14, weight: .semibold)
        headerLabel.textColor = AppColor.textSecondary
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        langScrollView.showsHorizontalScrollIndicator = false
        langScrollView.translatesAutoresizingMaskIntoConstraints = false

        langStack.axis    = .horizontal
        langStack.spacing = 8
        langStack.translatesAutoresizingMaskIntoConstraints = false
        langScrollView.addSubview(langStack)

        langSectionCard.addSubview(headerLabel)
        langSectionCard.addSubview(langScrollView)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: langSectionCard.topAnchor, constant: 14),
            headerLabel.leadingAnchor.constraint(equalTo: langSectionCard.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: langSectionCard.trailingAnchor, constant: -16),

            langScrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            langScrollView.leadingAnchor.constraint(equalTo: langSectionCard.leadingAnchor),
            langScrollView.trailingAnchor.constraint(equalTo: langSectionCard.trailingAnchor),
            langScrollView.heightAnchor.constraint(equalToConstant: 40),
            langScrollView.bottomAnchor.constraint(equalTo: langSectionCard.bottomAnchor, constant: -14),

            langStack.topAnchor.constraint(equalTo: langScrollView.contentLayoutGuide.topAnchor),
            langStack.bottomAnchor.constraint(equalTo: langScrollView.contentLayoutGuide.bottomAnchor),
            langStack.leadingAnchor.constraint(equalTo: langScrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            langStack.trailingAnchor.constraint(equalTo: langScrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            langStack.heightAnchor.constraint(equalTo: langScrollView.frameLayoutGuide.heightAnchor),
        ])
    }

    private func detectAndShowLanguages(from lyrics: String) {
        let lines = lyrics
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var counts: [NLLanguage: Int] = [:]
        for line in lines {
            let rec = NLLanguageRecognizer()
            rec.processString(line)
            if let lang = rec.dominantLanguage, lang != .undetermined {
                counts[lang, default: 0] += 1
            }
        }

        // 2行以上 or 全行の10%以上で登場した言語だけ採用
        let threshold = max(2, lines.count / 10)
        detectedLanguages = counts
            .filter { $0.value >= threshold }
            .sorted { $0.value > $1.value }
            .map { $0.key }

        guard !detectedLanguages.isEmpty else { return }

        // 選択中の言語が未検出なら英語 → 最初の言語 → nil にフォールバック
        if let cur = selectedLyricLang, !detectedLanguages.contains(cur) {
            selectedLyricLang = detectedLanguages.first
        }

        // ピルボタンを再構築
        langStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 「すべて」ボタン
        langStack.addArrangedSubview(makeLangPill(title: localText(key: "dictsetup_lang_all"), tag: -1))

        for (i, lang) in detectedLanguages.enumerated() {
            let name = langDisplayName(lang)
            langStack.addArrangedSubview(makeLangPill(title: name, tag: i))
        }

        refreshLangPills()
        langSectionCard.isHidden = false
    }

    private func makeLangPill(title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = tag
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        btn.layer.cornerRadius = 14
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(langPillTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func refreshLangPills() {
        for view in langStack.arrangedSubviews {
            guard let btn = view as? UIButton else { continue }
            let isAll      = btn.tag == -1
            let isSelected = isAll
                ? selectedLyricLang == nil
                : (btn.tag < detectedLanguages.count && detectedLanguages[btn.tag] == selectedLyricLang)
            btn.backgroundColor = isSelected ? AppColor.accent : AppColor.surfaceSecondary
            btn.setTitleColor(isSelected ? .white : AppColor.textPrimary, for: .normal)
        }
    }

    @objc private func langPillTapped(_ sender: UIButton) {
        if sender.tag == -1 {
            selectedLyricLang = nil
        } else if sender.tag < detectedLanguages.count {
            selectedLyricLang = detectedLanguages[sender.tag]
        }
        refreshLangPills()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func langDisplayName(_ lang: NLLanguage) -> String {
        if let name = Locale.current.localizedString(forLanguageCode: lang.rawValue) {
            return name
        }
        switch lang {
        case .japanese:           return localText(key: "lang_japanese")
        case .english:            return localText(key: "lang_english")
        case .simplifiedChinese:  return localText(key: "lang_chinese_simplified")
        case .traditionalChinese: return localText(key: "lang_chinese_traditional")
        case .korean:             return localText(key: "lang_korean")
        case .spanish:            return localText(key: "lang_spanish")
        case .french:             return localText(key: "lang_french")
        case .german:             return localText(key: "lang_german")
        default:                  return lang.rawValue
        }
    }

    // MARK: State update

    private func refresh(with lyrics: String) {
        currentLyrics = lyrics
        let hasLyrics = !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasLyrics {
            let iconCfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            statusIcon.image     = UIImage(systemName: "checkmark.circle.fill", withConfiguration: iconCfg)
            statusIcon.tintColor = UIColor.systemGreen
            statusLabel.text     = localText(key: "dictsetup_text_registered")
            statusSub.text       = localText(key: "dictsetup_text_registered_sub")
            fetchBtn.isHidden        = true
            transcribeBtn.isHidden   = true
            whisperBtn.isHidden      = true
            ocrSectionLabel.isHidden = true
            otherMethodsToggle.isHidden = true
            imageOCRBtn.isHidden     = true
            cameraOCRBtn.isHidden    = true
            manualInputBtn.isHidden  = true
            startBtn.isHidden        = false
            // 言語を検出してピルを表示（バックグラウンドで処理）
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let lyricsSnapshot = lyrics
                DispatchQueue.main.async {
                    self.detectAndShowLanguages(from: lyricsSnapshot)
                }
            }
        } else {
            langSectionCard.isHidden = true
            let iconCfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            statusIcon.image     = UIImage(systemName: "text.badge.plus", withConfiguration: iconCfg)
            statusIcon.tintColor = AppColor.accent
            statusLabel.text     = localText(key: "dictsetup_text_empty")
            statusSub.text       = localText(key: "dictsetup_text_empty_sub")
            fetchBtn.isHidden      = true
            transcribeBtn.isHidden = true
            let whisperAvailable: Bool
            if #available(iOS 16, *) { whisperAvailable = true } else { whisperAvailable = false }
            whisperBtn.isHidden      = !whisperAvailable
            ocrSectionLabel.isHidden = true  // 常に非表示（トグルに置き換え）
            // OCR系は折りたたみ状態でリセット
            isOtherMethodsExpanded   = false
            updateOtherMethodsToggleTitle()
            otherMethodsToggle.isHidden = false
            imageOCRBtn.isHidden     = true
            cameraOCRBtn.isHidden    = true
            manualInputBtn.isHidden  = true
            startBtn.isHidden        = true
        }
    }

    // MARK: Actions

    @objc private func fetchTapped() {
        guard rewardedAd != nil else {
            showAlert(title: localText(key: "dictsetup_alert_ad_loading"), message: localText(key: "dictsetup_alert_ad_wait"))
            preloadRewardedAd()
            return
        }
        rewardedAd?.present(from: self) { [weak self] in
            // 報酬獲得 → API で歌詞を取得
            self?.searchLyricsViaAPI()
        }
    }

    @objc private func whisperTapped() {
        guard #available(iOS 16, *) else { return }
        guard let url = track.url else {
            showAlert(title: localText(key: "err"), message: localText(key: "dictsetup_alert_no_url_msg"))
            return
        }
        // Small モデル固定（他モデルは実用上動作しないため選択肢を廃止）
        showWhisperLanguagePicker(url: url, modelName: "openai_whisper-small")
    }

    @available(iOS 16, *)
    private func showWhisperLanguagePicker(url: URL, modelName: String) {
        // 全自動（言語自動検出）固定で即開始
        startWhisperTranscription(url: url, modelName: modelName, languages: [])
    }

    @available(iOS 16, *)
    private func startWhisperTranscription(url: URL, modelName: String, languages: [String]) {
        whisperTask?.cancel()
        cancelTranscription?()
        cancelTranscription = nil

        // 再生中の音声を停止してExport/文字起こしの競合を防ぐ
        MPMusicPlayerController.applicationMusicPlayer.pause()
        if audioTestPlayer != nil && audioTestPlayer.isPlaying {
            audioTestPlayer.stop()
        }

        setWhisperLoading(true)

        whisperTask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await WhisperKitService.shared.transcribe(
                    url: url,
                    modelName: modelName,
                    languages: languages,
                    onProgress: { msg in
                        Task { @MainActor in
                            self.transcriptionOverlay?.update(step: msg)
                        }
                    }
                )
                await MainActor.run {
                    self.setWhisperLoading(false)
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.showAlert(title: localText(key: "dictsetup_alert_no_result"), message: localText(key: "dictsetup_alert_no_result_msg"))
                    } else {
                        self.showLyricsEditor(with: text, mode: .audio)
                    }
                }
            } catch {
                await MainActor.run {
                    self.setWhisperLoading(false)
                    let msg = error.localizedDescription.contains("model execution plan")
                        ? localText(key: "dictsetup_alert_incompatible")
                        : error.localizedDescription
                    self.showAlert(title: localText(key: "dictsetup_alert_whisper_error"), message: msg)
                }
            }
        }
    }

    private func setWhisperLoading(_ loading: Bool) {
        if loading {
            transcriptionOverlay?.show()
            whisperBtn.isHidden         = true
            otherMethodsToggle.isHidden = true
            imageOCRBtn.isHidden        = true
            cameraOCRBtn.isHidden       = true
            manualInputBtn.isHidden     = true
            progressLabel.isHidden      = true
        } else {
            transcriptionOverlay?.hide()
            // refresh() が表示状態を再構築するので個別復元は不要
        }
    }

    // MARK: - 画像OCR

    @objc private func manualInputTapped() {
        showLyricsEditor(with: "", mode: .ocr)
    }

    @objc private func imageOCRTapped() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func cameraOCRTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    private func runOCR(on image: UIImage) {
        guard let cgImage = image.cgImage else {
            showAlert(title: localText(key: "err"), message: localText(key: "dictsetup_alert_image_load_error_msg"))
            return
        }

        loadingIndicator.startAnimating()
        imageOCRBtn.isEnabled  = false
        cameraOCRBtn.isEnabled = false
        whisperBtn.isEnabled   = false
        progressLabel.text     = localText(key: "dictsetup_reading_image")
        progressLabel.isHidden = false

        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self else { return }
            let lines = (req.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()
                self.imageOCRBtn.isEnabled  = true
                self.cameraOCRBtn.isEnabled = true
                self.whisperBtn.isEnabled   = true
                self.progressLabel.isHidden = true

                if lines.isEmpty {
                    self.showAlert(title: localText(key: "dictsetup_alert_no_text_title"),
                                   message: localText(key: "dictsetup_alert_no_text_msg"))
                } else {
                    self.showLyricsEditor(with: lines.joined(separator: "\n"))
                }
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["ja-JP", "en-US", "ko-KR"]
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - テキスト編集エディタ

    private func showLyricsEditor(with text: String, mode: LyricsTextEditorViewController.SourceMode = .ocr) {
        let editorVC = LyricsTextEditorViewController()
        editorVC.initialText = text
        editorVC.sourceMode = mode
        editorVC.onSave = { [weak self] savedText in
            self?.confirmAndSaveTranscription(savedText)
        }
        let nav = UINavigationController(rootViewController: editorVC)
        if #available(iOS 15, *) {
            if let sheet = nav.sheetPresentationController {
                sheet.detents = [.large()]
            }
        }
        present(nav, animated: true)
    }

    @objc private func transcribeTapped() {
        guard let url = track.url else {
            showAlert(title: localText(key: "err"), message: localText(key: "dictsetup_alert_no_url_msg"))
            return
        }
        showLanguagePicker(url: url)
    }

    private func showLanguagePicker(url: URL) {
        let sheet = UIAlertController(
            title: localText(key: "dictsetup_lang_select_title"),
            message: localText(key: "dictsetup_lang_select_msg"),
            preferredStyle: .actionSheet
        )
        for lang in TranscriptionService.languages {
            sheet.addAction(UIAlertAction(title: lang.label, style: .default) { [weak self] _ in
                self?.showChunkPicker(url: url, locales: lang.locales)
            })
        }
        sheet.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = transcribeBtn
            popover.sourceRect = transcribeBtn.bounds
        }
        present(sheet, animated: true)
    }

    private func showChunkPicker(url: URL, locales: [Locale]) {
        let options: [(label: String, seconds: TimeInterval)] = [
            (localText(key: "dictsetup_chunk_10s"), 10),
            (localText(key: "dictsetup_chunk_20s"), 20),
            (localText(key: "dictsetup_chunk_30s"), 30),
            (localText(key: "dictsetup_chunk_45s"), 45),
            (localText(key: "dictsetup_chunk_55s"), 55),
        ]
        let sheet = UIAlertController(
            title: localText(key: "dictsetup_chunk_select_title"),
            message: localText(key: "dictsetup_chunk_select_msg"),
            preferredStyle: .actionSheet
        )
        for opt in options {
            sheet.addAction(UIAlertAction(title: opt.label, style: .default) { [weak self] _ in
                self?.startTranscription(url: url, locales: locales, chunkSec: opt.seconds)
            })
        }
        sheet.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = transcribeBtn
            popover.sourceRect = transcribeBtn.bounds
        }
        present(sheet, animated: true)
    }

    private func startTranscription(url: URL, locales: [Locale], chunkSec: TimeInterval) {
        cancelTranscription?()
        cancelTranscription = nil

        let duration    = TranscriptionService.audioDuration(url: url) ?? 0
        let totalChunks = max(1, Int(ceil(duration / chunkSec)))
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        let langNote = locales.count > 1 ? String(format: localText(key: "dictsetup_auto_detect_note"), locales.count) : ""

        let alert = UIAlertController(
            title: localText(key: "dictsetup_transcribe_confirm_title"),
            message: String(format: localText(key: "dictsetup_transcribe_confirm_msg"), mins, secs, Int(chunkSec), totalChunks, langNote),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: localText(key: "dictsetup_start_btn"), style: .default) { [weak self] _ in
            self?.runTranscription(url: url, locales: locales, chunkSec: chunkSec, totalChunks: totalChunks)
        })
        alert.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        present(alert, animated: true)
    }

    private func runTranscription(url: URL, locales: [Locale], chunkSec: TimeInterval, totalChunks: Int) {
        setTranscribing(true, totalChunks: totalChunks)
        cancelTranscription = TranscriptionService.transcribe(
            url: url,
            locales: locales,
            chunkDuration: chunkSec,
            onChunkProgress: { [weak self] partial, chunk, total in
                self?.progressLabel.text = "(\(chunk + 1)/\(total)) \(partial.suffix(80))"
            },
            completion: { [weak self] result in
                guard let self else { return }
                self.setTranscribing(false, totalChunks: totalChunks)
                switch result {
                case .success(let text):
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.showAlert(title: localText(key: "dictsetup_alert_no_result"), message: localText(key: "dictsetup_no_result_alt_msg"))
                    } else {
                        self.confirmAndSaveTranscription(text)
                    }
                case .failure(let error):
                    self.showAlert(title: localText(key: "dictsetup_transcribe_fail_title"), message: error.localizedDescription)
                }
            }
        )
    }

    private func confirmAndSaveTranscription(_ text: String) {
        // エディタでユーザーがすでに確認・保存を選んでいるので、ここでは直接保存する
        if let url = track.url {
            LyricsService.saveFetchedLyrics(
                text,
                trackURL: url,
                libraryName: libraryName,
                trackIndex: trackIndex
            )
        }
        refresh(with: text)
        showToastMsg(messege: localText(key: "dictsetup_lyrics_saved"), time: 2, tab: 0)
    }

    private func setTranscribing(_ transcribing: Bool, totalChunks: Int = 1) {
        if transcribing {
            loadingIndicator.startAnimating()
            transcribeBtn.isEnabled  = false
            fetchBtn.isEnabled       = false
            progressLabel.text       = totalChunks > 1
                ? String(format: localText(key: "dictsetup_transcribing_fmt"), totalChunks)
                : localText(key: "dictsetup_transcribing")
            progressLabel.isHidden   = false
        } else {
            loadingIndicator.stopAnimating()
            transcribeBtn.isEnabled  = true
            fetchBtn.isEnabled       = true
            progressLabel.isHidden   = true
        }
    }

    @objc private func startTapped() {
        let lyrics = currentLyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lyrics.isEmpty else { return }

        let dictationVC              = DictationViewController()
        dictationVC.track            = track
        dictationVC.lyrics           = lyrics
        dictationVC.selectedLyricLang = selectedLyricLang
        navigationController?.pushViewController(dictationVC, animated: true)
    }

    // MARK: Rewarded Ad

    private func preloadRewardedAd() {
        let adUnitID = DEBUG_FLG ? ADMOB_REWARD_AD : ADMOB_REWARD_AD
        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            if let error {
                dlog("[DictationSetup] RewardedAd load failed: \(error)")
                return
            }
            self?.rewardedAd = ad
            self?.rewardedAd?.fullScreenContentDelegate = self
        }
    }

    // MARK: API Search

    private func searchLyricsViaAPI() {
        setLoading(true)
        LyricsService.fetch(title: track.title, artist: track.artist) { [weak self] lyrics in
            guard let self else { return }
            self.setLoading(false)

            if let lyrics {
                // 保存して UI を更新
                if let url = self.track.url {
                    LyricsService.saveFetchedLyrics(
                        lyrics,
                        trackURL: url,
                        libraryName: self.libraryName,
                        trackIndex: self.trackIndex
                    )
                }
                self.refresh(with: lyrics)
            } else {
                self.showAlert(
                    title: localText(key: "dictsetup_alert_lyrics_not_found_title"),
                    message: String(format: localText(key: "dictsetup_alert_lyrics_not_found_msg"), self.track.title)
                )
            }
        }
    }

    // MARK: Helpers

    private func setLoading(_ loading: Bool) {
        if loading {
            loadingIndicator.startAnimating()
            fetchBtn.isEnabled = false
        } else {
            loadingIndicator.stopAnimating()
            fetchBtn.isEnabled = true
        }
    }

    private func showAlert(title: String, message: String, copyable: Bool = false) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if copyable {
            alert.addAction(UIAlertAction(title: localText(key: "dictsetup_ocr_copy_btn"), style: .default) { _ in
                UIPasteboard.general.string = message
            })
        }
        alert.addAction(UIAlertAction(title: "OK", style: copyable ? .cancel : .default))
        present(alert, animated: true)
    }
}

// MARK: - WaveformBarsView

private final class WaveformBarsView: UIView {
    private var bars: [UIView] = []
    private var isCurrentlyAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBars()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && isCurrentlyAnimating {
            addAnimations()
        }
    }

    private func setupBars() {
        let barHeights: [CGFloat] = [18, 32, 24, 36, 20]
        for h in barHeights {
            let bar = UIView()
            bar.backgroundColor    = AppColor.accent
            bar.layer.cornerRadius = 3
            bar.translatesAutoresizingMaskIntoConstraints = false
            addSubview(bar)
            bars.append(bar)
            bar.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            bar.widthAnchor.constraint(equalToConstant: 5).isActive = true
            bar.heightAnchor.constraint(equalToConstant: h).isActive = true
        }
        for (i, bar) in bars.enumerated() {
            if i == 0 {
                bar.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
            } else {
                bar.leadingAnchor.constraint(equalTo: bars[i - 1].trailingAnchor, constant: 5).isActive = true
            }
        }
    }

    func startAnimating() {
        isCurrentlyAnimating = true
        addAnimations()
    }

    func stopAnimating() {
        isCurrentlyAnimating = false
        bars.forEach { $0.layer.removeAllAnimations() }
    }

    private func addAnimations() {
        let durations: [Double]  = [0.55, 0.38, 0.48, 0.33, 0.52]
        let offsets:   [Double]  = [0.00, 0.20, 0.10, 0.35, 0.15]
        let minScales: [CGFloat] = [0.22, 0.18, 0.28, 0.14, 0.30]

        for (i, bar) in bars.enumerated() {
            bar.layer.removeAnimation(forKey: "wave")
            let anim            = CABasicAnimation(keyPath: "transform.scale.y")
            anim.fromValue      = 1.0
            anim.toValue        = minScales[i]
            anim.duration       = durations[i]
            // timeOffset でずらすことで beginTime を現在時刻に依存させない
            anim.timeOffset     = offsets[i]
            anim.repeatCount    = .infinity
            anim.autoreverses   = true
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bar.layer.add(anim, forKey: "wave")
        }
    }
}

// MARK: - TranscriptionLoadingOverlay

final class TranscriptionLoadingOverlay: UIView {
    var cancelAction: (() -> Void)?

    private let blurView    = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let card        = UIView()
    private let waveform    = WaveformBarsView()
    private let titleLabel  = UILabel()
    private let stepLabel   = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private let chunkLabel  = UILabel()
    private let cancelBtn   = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        card.backgroundColor     = AppColor.surface
        card.layer.cornerRadius  = 28
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.14
        card.layer.shadowOffset  = CGSize(width: 0, height: 8)
        card.layer.shadowRadius  = 24
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -16),
            card.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.84),
        ])

        waveform.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text          = localText(key: "dictsetup_overlay_title")
        titleLabel.font          = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2

        stepLabel.text           = localText(key: "dictsetup_loading_model")
        stepLabel.font           = UIFont.systemFont(ofSize: 14)
        stepLabel.textColor      = AppColor.textSecondary
        stepLabel.textAlignment  = .center
        stepLabel.numberOfLines  = 2

        progressBar.progressTintColor  = AppColor.accent
        progressBar.trackTintColor     = AppColor.surfaceSecondary
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds      = true
        progressBar.isHidden           = true
        progressBar.setProgress(0, animated: false)

        chunkLabel.font          = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        chunkLabel.textColor     = AppColor.accent
        chunkLabel.textAlignment = .center
        chunkLabel.isHidden      = true

        cancelBtn.setTitle(localText(key: "btn_cancel"), for: .normal)
        cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        cancelBtn.setTitleColor(AppColor.textSecondary, for: .normal)
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let contentStack = UIStackView(arrangedSubviews: [
            waveform, titleLabel, stepLabel, progressBar, chunkLabel, cancelBtn
        ])
        contentStack.axis      = .vertical
        contentStack.spacing   = 16
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(contentStack)

        NSLayoutConstraint.activate([
            waveform.widthAnchor.constraint(equalToConstant: 45),
            waveform.heightAnchor.constraint(equalToConstant: 44),
            progressBar.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 36),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28),
        ])
    }

    func show() {
        isHidden = false
        waveform.startAnimating()
        UIView.animate(withDuration: 0.28) { self.alpha = 1 }
    }

    func hide() {
        waveform.stopAnimating()
        UIView.animate(withDuration: 0.22, animations: { self.alpha = 0 }) { _ in
            self.isHidden = true
            self.progressBar.isHidden = true
            self.chunkLabel.isHidden  = true
            self.progressBar.setProgress(0, animated: false)
            self.stepLabel.text = localText(key: "dictsetup_loading_model")
        }
    }

    func update(step msg: String) {
        stepLabel.text = msg
        let pattern = #"[\[\(](\d+)/(\d+)[\]\)]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: msg, range: NSRange(msg.startIndex..., in: msg)),
              let curRange = Range(match.range(at: 1), in: msg),
              let totRange = Range(match.range(at: 2), in: msg),
              let current  = Int(msg[curRange]),
              let total    = Int(msg[totRange]),
              total > 0 else { return }
        progressBar.isHidden = false
        chunkLabel.isHidden  = false
        chunkLabel.text      = "\(current) / \(total)"
        progressBar.setProgress(Float(current) / Float(total), animated: true)
    }

    @objc private func cancelTapped() { cancelAction?() }
}

// MARK: - PHPickerViewControllerDelegate

extension DictationSetupViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            DispatchQueue.main.async { self.runOCR(on: image) }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension DictationSetupViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage else { return }
        runOCR(on: image)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - FullScreenContentDelegate

extension DictationSetupViewController: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // 広告が閉じられた後に再ロード
        preloadRewardedAd()
    }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        dlog("[DictationSetup] Ad presentation failed: \(error)")
        showAlert(title: localText(key: "dictsetup_alert_ad_failed"), message: localText(key: "dictsetup_alert_ad_failed_msg"))
    }
}
