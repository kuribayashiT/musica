//
//  DictationViewController.swift
//  musica
//
//  歌詞穴埋めディクテーション本体。
//  歌詞を解析して空欄を生成し、1問ずつ入力・採点する。
//

import UIKit
import AVFoundation
import NaturalLanguage
import Speech

// MARK: - DictationViewController

final class DictationViewController: UIViewController {

    // MARK: Input

    var track: TrackData!
    var lyrics: String = ""
    /// nil = すべての言語を対象（DictationSetupViewController から渡される）
    var selectedLyricLang: NLLanguage? = nil

    // MARK: Model

    private struct BlankItem {
        let answer: String        // 正解（小文字・記号除去済み）
        let lineWithBlank: String // 表示用（正解を____に置換）
        let originalLine: String  // TTS 読み上げ用（元の行）
        let prevLine: String      // 前行（コンテキスト）
        let nextLine: String      // 次行（コンテキスト）
    }

    private var blanks:      [BlankItem] = []
    private var currentIndex = 0
    private var correctCount = 0
    private var userAnswers: [String]   = []   // 入力履歴（採点画面用）

    // MARK: Audio

    private var pausedForRecording = false

    // MARK: TTS
    private let synthesizer = AVSpeechSynthesizer()
    private var detectedLangCode: String = "en-US"

    // MARK: Voice Input
    private var sfRecognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var isRecording = false
    private var silenceTimer: Timer?
    private let micBtn = UIButton(type: .system)

    // MARK: Views

    private let progressLabel = UILabel()
    private let progressBar   = UIProgressView(progressViewStyle: .bar)

    private let prevLineLabel     = UILabel()
    private let currentLineLabel  = UILabel()
    private let nextLineLabel     = UILabel()
    private let speakBtn          = UIButton(type: .system)
    private let speakBubble       = UIView()
    private let speakHintLabel    = UILabel()

    private let answerField = UITextField()
    private let checkBtn    = UIButton(type: .system)
    private let skipBtn     = UIButton(type: .system)

    private let playPauseBtn   = UIButton(type: .system)
    private let miniPlayerCard = UIView()
    private weak var miniPlayerArtView: UIImageView?
    private weak var miniPlayerTitleLabel: UILabel?
    private var bottomInputConstraint: NSLayoutConstraint!
    private var prevLineTopConstraint: NSLayoutConstraint?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        title = localText(key: "dictation_title")
        navigationItem.largeTitleDisplayMode = .never

        parseLyrics()
        detectLanguage()
        setupLayout()
        showQuestion()
        NotificationCenter.default.addObserver(self, selector: #selector(onPlaybackStateChanged(_:)), name: .musicaPlaybackStateChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onTrackChanged), name: .musicaTrackChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        synthesizer.stopSpeaking(at: .immediate)
        stopRecording()
    }

    // MARK: Lyrics Parsing

    private func parseLyrics() {
        let allLines = lyrics
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // 言語フィルタ：選択言語がある場合は該当行だけを使う
        let lines: [String]
        if let targetLang = selectedLyricLang {
            let filtered = allLines.filter { line in
                let rec = NLLanguageRecognizer()
                rec.processString(line)
                return rec.dominantLanguage == targetLang
            }
            // フィルタ後が極端に少ない場合は全行にフォールバック
            lines = filtered.count >= 3 ? filtered : allLines
        } else {
            lines = allLines
        }

        let maxBlanks = min(15, max(5, lines.count / 2))
        var candidates: [(lineIdx: Int, word: String)] = []

        for (lineIdx, line) in lines.enumerated() {
            // CJK 対応: NLTokenizer で単語境界を検出
            let tokens = tokenizeWords(in: line)
            // 2文字以上を候補に、3文字以上を優先
            let long3 = tokens.filter { cleaned($0).count >= 3 }
            let long2 = tokens.filter { cleaned($0).count >= 2 }
            let pool = long3.isEmpty ? long2 : long3
            if let pick = pool.randomElement() {
                candidates.append((lineIdx, pick))
            }
        }

        // シャッフルして上限数に絞る
        candidates.shuffle()
        let selected = Array(candidates.prefix(maxBlanks))
            .sorted { $0.lineIdx < $1.lineIdx }

        blanks = selected.map { item in
            let line = lines[item.lineIdx]
            let word = item.word
            let blank = String(repeating: "_", count: max(4, word.count))
            // 元の文字列の中で単語を空欄に置換（CJK の空白なし結合も保持）
            let lineWithBlank: String
            if let range = line.range(of: word) {
                lineWithBlank = line.replacingCharacters(in: range, with: blank)
            } else {
                lineWithBlank = line
            }
            return BlankItem(
                answer:        cleaned(word),
                lineWithBlank: lineWithBlank,
                originalLine:  line,
                prevLine:      item.lineIdx > 0 ? lines[item.lineIdx - 1] : "",
                nextLine:      item.lineIdx < lines.count - 1 ? lines[item.lineIdx + 1] : ""
            )
        }

        userAnswers = Array(repeating: "", count: blanks.count)
    }

    /// CJK 文字が含まれる行は NLTokenizer で単語分割、それ以外はスペース分割
    private func tokenizeWords(in line: String) -> [String] {
        let hasCJK = line.unicodeScalars.contains {
            ($0.value >= 0x4E00 && $0.value <= 0x9FFF) ||  // CJK 統一漢字
            ($0.value >= 0x3040 && $0.value <= 0x309F) ||  // ひらがな
            ($0.value >= 0x30A0 && $0.value <= 0x30FF)     // カタカナ
        }
        if hasCJK {
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = line
            var tokens: [String] = []
            tokenizer.enumerateTokens(in: line.startIndex..<line.endIndex) { range, _ in
                let token = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !token.isEmpty { tokens.append(String(line[range])) }
                return true
            }
            return tokens.isEmpty ? [line] : tokens
        } else {
            return line.components(separatedBy: CharacterSet(charactersIn: " 　"))
                       .filter { !$0.isEmpty }
        }
    }

    /// 記号・空白を除去して小文字化
    private func cleaned(_ word: String) -> String {
        word.components(separatedBy: CharacterSet.punctuationCharacters.union(.symbols))
            .joined()
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: Language Detection

    private func detectLanguage() {
        // 選択言語があればそれをそのまま使う
        let lang: NLLanguage
        if let selected = selectedLyricLang {
            lang = selected
        } else {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(lyrics)
            lang = recognizer.dominantLanguage ?? .undetermined
        }

        // NLLanguage → BCP-47 + AVSpeechSynthesisVoice のコードにマップ
        let map: [NLLanguage: String] = [
            .japanese:            "ja-JP",
            .english:             "en-US",
            .simplifiedChinese:   "zh-CN",
            .traditionalChinese:  "zh-TW",
            .korean:              "ko-KR",
            .spanish:             "es-ES",
            .french:              "fr-FR",
            .german:              "de-DE",
            .italian:             "it-IT",
            .portuguese:          "pt-BR",
            .russian:             "ru-RU",
            .arabic:              "ar-SA",
            .hindi:               "hi-IN",
            .thai:                "th-TH",
            .indonesian:          "id-ID",
            .vietnamese:          "vi-VN",
            .turkish:             "tr-TR",
        ]
        detectedLangCode = map[lang] ?? "en-US"
    }

    // MARK: TTS

    private func speakCurrentLine() {
        synthesizer.stopSpeaking(at: .immediate)
        guard currentIndex < blanks.count else { return }
        let text = blanks[currentIndex].originalLine
        let langCode = perLineLangCode(for: text)
        guard let voice = AVSpeechSynthesisVoice(language: langCode) else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate  = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.delegate = self
        synthesizer.speak(utterance)
        updateSpeakBtn(speaking: true)
    }

    /// 1行のテキストから適切な BCP-47 言語コードを返す。
    /// selectedLyricLang が指定されている場合はそれを優先し、
    /// なければ行ごとに NLLanguageRecognizer で判定する。
    private func perLineLangCode(for text: String) -> String {
        let langMap: [NLLanguage: String] = [
            .japanese:           "ja-JP",
            .english:            "en-US",
            .simplifiedChinese:  "zh-CN",
            .traditionalChinese: "zh-TW",
            .korean:             "ko-KR",
            .spanish:            "es-ES",
            .french:             "fr-FR",
            .german:             "de-DE",
            .italian:            "it-IT",
            .portuguese:         "pt-BR",
            .russian:            "ru-RU",
            .arabic:             "ar-SA",
            .hindi:              "hi-IN",
            .thai:               "th-TH",
            .indonesian:         "id-ID",
            .vietnamese:         "vi-VN",
            .turkish:            "tr-TR",
        ]
        if let selected = selectedLyricLang {
            return langMap[selected] ?? detectedLangCode
        }
        let rec = NLLanguageRecognizer()
        rec.processString(text)
        let lang = rec.dominantLanguage ?? .undetermined
        // 判定できなかった場合は歌詞全体の判定結果にフォールバック
        return langMap[lang] ?? detectedLangCode
    }

    private func updateSpeakBtn(speaking: Bool) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let icon = speaking ? "speaker.wave.3.fill" : "speaker.wave.2"
        speakBtn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        speakBtn.tintColor = speaking ? AppColor.accent : AppColor.textSecondary
    }

    // MARK: Layout

    private func setupLayout() {
        // ── ミニプレイヤー ──
        setupMiniPlayer()

        // ── 進捗 ──
        progressLabel.font      = UIFont.systemFont(ofSize: 13, weight: .semibold)
        progressLabel.textColor = AppColor.textSecondary
        progressLabel.translatesAutoresizingMaskIntoConstraints = false

        progressBar.progressTintColor = AppColor.accent
        progressBar.trackTintColor    = AppColor.accent.withAlphaComponent(0.2)
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        // ── 歌詞コンテキスト ──
        prevLineLabel.font          = UIFont.systemFont(ofSize: 13)
        prevLineLabel.textColor     = AppColor.textSecondary
        prevLineLabel.numberOfLines = 2
        prevLineLabel.textAlignment = .center
        prevLineLabel.translatesAutoresizingMaskIntoConstraints = false

        currentLineLabel.font          = UIFont.systemFont(ofSize: 17, weight: .semibold)
        currentLineLabel.textColor     = AppColor.textPrimary
        currentLineLabel.numberOfLines = 3
        currentLineLabel.textAlignment = .center
        currentLineLabel.translatesAutoresizingMaskIntoConstraints = false

        nextLineLabel.font          = UIFont.systemFont(ofSize: 13)
        nextLineLabel.textColor     = AppColor.textSecondary
        nextLineLabel.numberOfLines = 2
        nextLineLabel.textAlignment = .center
        nextLineLabel.translatesAutoresizingMaskIntoConstraints = false

        // ── 入力フィールド ──
        answerField.placeholder      = localText(key: "dictation_input_placeholder")
        answerField.borderStyle      = .none
        answerField.backgroundColor  = AppColor.surface
        answerField.layer.cornerRadius = 12
        answerField.font             = UIFont.systemFont(ofSize: 16)
        answerField.textColor        = AppColor.textPrimary
        answerField.textAlignment    = .center
        answerField.autocorrectionType     = .no
        answerField.autocapitalizationType = .none
        answerField.spellCheckingType      = .no
        answerField.returnKeyType          = .done
        answerField.delegate = self
        answerField.translatesAutoresizingMaskIntoConstraints = false

        // ── 読み上げボタン ──
        let speakCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        speakBtn.setImage(UIImage(systemName: "speaker.wave.2", withConfiguration: speakCfg), for: .normal)
        speakBtn.tintColor = AppColor.textSecondary
        speakBtn.addTarget(self, action: #selector(speakTapped), for: .touchUpInside)
        speakBtn.translatesAutoresizingMaskIntoConstraints = false

        // 吹き出し（ポインター ▲ + 本体）
        let bubbleColor = UIColor(white: 0.22, alpha: 0.88)

        let speakArrow = UIView()
        speakArrow.backgroundColor = bubbleColor
        speakArrow.transform = CGAffineTransform(rotationAngle: .pi / 4)
        speakArrow.translatesAutoresizingMaskIntoConstraints = false

        speakBubble.backgroundColor = bubbleColor
        speakBubble.layer.cornerRadius = 8
        speakBubble.translatesAutoresizingMaskIntoConstraints = false

        speakHintLabel.text = localText(key: "dictation_speak_hint")
        speakHintLabel.font = .systemFont(ofSize: 9, weight: .medium)
        speakHintLabel.textColor = .white
        speakHintLabel.translatesAutoresizingMaskIntoConstraints = false
        speakBubble.addSubview(speakHintLabel)

        // ── ボタン ──
        checkBtn.setTitle(localText(key: "dictation_check_btn"), for: .normal)
        checkBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 16, weight: .semibold)
        checkBtn.backgroundColor   = AppColor.accent
        checkBtn.setTitleColor(.white, for: .normal)
        checkBtn.layer.cornerRadius = 14
        checkBtn.addTarget(self, action: #selector(checkTapped), for: .touchUpInside)
        checkBtn.translatesAutoresizingMaskIntoConstraints = false

        skipBtn.setTitle(localText(key: "dictation_skip_btn"), for: .normal)
        skipBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        skipBtn.setTitleColor(AppColor.textSecondary, for: .normal)
        skipBtn.backgroundColor = AppColor.surface
        skipBtn.layer.cornerRadius = 14
        skipBtn.layer.borderWidth = 1.5
        skipBtn.layer.borderColor = AppColor.accent.withAlphaComponent(0.4).cgColor
        skipBtn.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipBtn.translatesAutoresizingMaskIntoConstraints = false

        // ── マイクボタン ──
        let micCfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        micBtn.setImage(UIImage(systemName: "mic", withConfiguration: micCfg), for: .normal)
        micBtn.tintColor = AppColor.accent
        micBtn.backgroundColor = AppColor.surface
        micBtn.layer.cornerRadius = 12
        micBtn.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micBtn.translatesAutoresizingMaskIntoConstraints = false

        // ── Keyboard 回避 ──
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)

        // ── 配置 ──
        [progressLabel, progressBar,
         prevLineLabel, currentLineLabel, nextLineLabel,
         speakBtn, speakArrow, speakBubble, answerField, micBtn, checkBtn, skipBtn].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: track.url != nil ? 92 : 16),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            progressBar.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 6),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            { let c = prevLineLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 24); prevLineTopConstraint = c; return c }(),
            prevLineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            prevLineLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            currentLineLabel.topAnchor.constraint(equalTo: prevLineLabel.bottomAnchor, constant: 16),
            currentLineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            currentLineLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),

            // 読み上げボタンを currentLineLabel の右端に配置
            speakBtn.centerYAnchor.constraint(equalTo: currentLineLabel.centerYAnchor, constant: -6),
            speakBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            speakBtn.widthAnchor.constraint(equalToConstant: 36),
            speakBtn.heightAnchor.constraint(equalToConstant: 36),

            // 吹き出しポインター（▲）
            speakArrow.centerXAnchor.constraint(equalTo: speakBtn.centerXAnchor),
            speakArrow.topAnchor.constraint(equalTo: speakBtn.bottomAnchor, constant: 4),
            speakArrow.widthAnchor.constraint(equalToConstant: 8),
            speakArrow.heightAnchor.constraint(equalToConstant: 8),

            // 吹き出し本体（arrowの中央から始まり下半分を覆う）
            speakBubble.centerXAnchor.constraint(equalTo: speakBtn.centerXAnchor),
            speakBubble.topAnchor.constraint(equalTo: speakArrow.topAnchor, constant: 4),

            // 吹き出し内テキスト
            speakHintLabel.topAnchor.constraint(equalTo: speakBubble.topAnchor, constant: 5),
            speakHintLabel.bottomAnchor.constraint(equalTo: speakBubble.bottomAnchor, constant: -5),
            speakHintLabel.leadingAnchor.constraint(equalTo: speakBubble.leadingAnchor, constant: 8),
            speakHintLabel.trailingAnchor.constraint(equalTo: speakBubble.trailingAnchor, constant: -8),

            nextLineLabel.topAnchor.constraint(equalTo: currentLineLabel.bottomAnchor, constant: 16),
            nextLineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nextLineLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // 入力エリアはキーボード回避のため底部から積み上げ
            // ボタン行: checkBtn(左・可変幅) + skipBtn(右・固定96pt) を横並び
            skipBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            skipBtn.widthAnchor.constraint(equalToConstant: 96),
            skipBtn.heightAnchor.constraint(equalToConstant: 48),

            checkBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            checkBtn.trailingAnchor.constraint(equalTo: skipBtn.leadingAnchor, constant: -10),
            checkBtn.heightAnchor.constraint(equalToConstant: 48),
            checkBtn.centerYAnchor.constraint(equalTo: skipBtn.centerYAnchor),

            micBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            micBtn.widthAnchor.constraint(equalToConstant: 52),
            micBtn.heightAnchor.constraint(equalToConstant: 52),
            micBtn.bottomAnchor.constraint(equalTo: skipBtn.topAnchor, constant: -16),

            answerField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            answerField.trailingAnchor.constraint(equalTo: micBtn.leadingAnchor, constant: -8),
            answerField.heightAnchor.constraint(equalToConstant: 52),
            answerField.bottomAnchor.constraint(equalTo: skipBtn.topAnchor, constant: -16),
        ])
        bottomInputConstraint = skipBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -32)
        bottomInputConstraint.isActive = true
    }

    private func setupMiniPlayer() {
        let shadowWrap = miniPlayerCard
        shadowWrap.isHidden = track.url == nil
        shadowWrap.backgroundColor = .clear
        shadowWrap.layer.cornerRadius = 16
        shadowWrap.layer.shadowColor = UIColor.black.cgColor
        shadowWrap.layer.shadowOpacity = 0.22
        shadowWrap.layer.shadowRadius = 12
        shadowWrap.layer.shadowOffset = CGSize(width: 0, height: 4)
        shadowWrap.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shadowWrap)

        let card = UIView()
        card.backgroundColor = AppColor.surface
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        shadowWrap.addSubview(card)

        let bgImg = UIImageView()
        bgImg.contentMode = .scaleAspectFill
        bgImg.image = track.artworkImg ?? UIImage(named: "onpu_BL")
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
        artView.translatesAutoresizingMaskIntoConstraints = false
        if let img = track.artworkImg {
            artView.image = img
            artView.contentMode = .scaleAspectFill
        } else {
            artView.image = UIImage(named: "onpu_BL")
            artView.contentMode = .center
        }
        card.addSubview(artView)
        miniPlayerArtView = artView

        let titleLbl = UILabel()
        titleLbl.text = track.title.isEmpty ? localText(key: "practice_unknown") : track.title
        titleLbl.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLbl.textColor = AppColor.textPrimary
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)
        miniPlayerTitleLabel = titleLbl

        let artistLbl = UILabel()
        artistLbl.text = track.artist
        artistLbl.font = .systemFont(ofSize: 11)
        artistLbl.textColor = AppColor.textSecondary
        artistLbl.lineBreakMode = .byTruncatingTail
        artistLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(artistLbl)

        let ppCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let ppIcon = audioPlayer?.isPlaying == true ? "pause.fill" : "play.fill"
        playPauseBtn.setImage(UIImage(systemName: ppIcon, withConfiguration: ppCfg), for: .normal)
        playPauseBtn.tintColor = .white
        playPauseBtn.backgroundColor = AppColor.accent
        playPauseBtn.layer.cornerRadius = 19
        playPauseBtn.layer.masksToBounds = true
        playPauseBtn.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        playPauseBtn.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(playPauseBtn)

        NSLayoutConstraint.activate([
            shadowWrap.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            shadowWrap.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            shadowWrap.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
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

            playPauseBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            playPauseBtn.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            playPauseBtn.widthAnchor.constraint(equalToConstant: 38),
            playPauseBtn.heightAnchor.constraint(equalToConstant: 38),

            titleLbl.leadingAnchor.constraint(equalTo: artView.trailingAnchor, constant: 12),
            titleLbl.trailingAnchor.constraint(equalTo: playPauseBtn.leadingAnchor, constant: -8),
            titleLbl.bottomAnchor.constraint(equalTo: card.centerYAnchor, constant: 1),

            artistLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            artistLbl.trailingAnchor.constraint(equalTo: titleLbl.trailingAnchor),
            artistLbl.topAnchor.constraint(equalTo: card.centerYAnchor, constant: 4),
        ])
    }

    // MARK: Question

    private func showQuestion() {
        guard currentIndex < blanks.count else {
            showResult()
            return
        }
        let item = blanks[currentIndex]

        // TTS を止めてアイコンをリセット
        synthesizer.stopSpeaking(at: .immediate)
        updateSpeakBtn(speaking: false)

        progressLabel.text = "\(currentIndex + 1) / \(blanks.count)"
        progressBar.setProgress(Float(currentIndex) / Float(blanks.count), animated: true)

        prevLineLabel.text    = item.prevLine
        currentLineLabel.text = item.lineWithBlank
        nextLineLabel.text    = item.nextLine

        // 空欄部分を強調
        highlightBlank(in: item.lineWithBlank)

        answerField.text = ""
        answerField.becomeFirstResponder()
    }

    private func highlightBlank(in line: String) {
        let attr = NSMutableAttributedString(string: line)
        let fullRange = NSRange(line.startIndex..., in: line)
        attr.addAttribute(.foregroundColor, value: AppColor.textPrimary, range: fullRange)

        if let range = line.range(of: "_{3,}", options: .regularExpression) {
            let nsRange = NSRange(range, in: line)
            attr.addAttribute(.foregroundColor, value: AppColor.accent, range: nsRange)
            attr.addAttribute(.font,
                              value: UIFont.systemFont(ofSize: 17, weight: .bold),
                              range: nsRange)
        }
        currentLineLabel.attributedText = attr
    }

    // MARK: Actions

    @objc private func checkTapped() {
        let input = (answerField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            answerField.layer.borderColor  = UIColor.systemRed.cgColor
            answerField.layer.borderWidth  = 1.5
            answerField.layer.cornerRadius = 12
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.answerField.layer.borderWidth = 0
            }
            return
        }
        evaluateAnswer(input)
    }

    @objc private func skipTapped() {
        userAnswers[currentIndex] = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        advance()
    }

    private func evaluateAnswer(_ input: String) {
        let correct = blanks[currentIndex].answer
        let isCorrect = cleaned(input) == correct

        userAnswers[currentIndex] = input
        if isCorrect { correctCount += 1 }

        // フィードバック
        let feedbackColor: UIColor = isCorrect ? .systemGreen : .systemRed
        answerField.layer.borderColor  = feedbackColor.cgColor
        answerField.layer.borderWidth  = 2
        answerField.layer.cornerRadius = 12
        UINotificationFeedbackGenerator().notificationOccurred(isCorrect ? .success : .error)

        // 不正解の場合は正解を一瞬見せる
        if !isCorrect {
            answerField.text      = correct
            answerField.textColor = UIColor.systemRed
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            self.answerField.layer.borderWidth = 0
            self.answerField.textColor = AppColor.textPrimary
            self.advance()
        }
    }

    private func advance() {
        currentIndex += 1
        if currentIndex < blanks.count {
            showQuestion()
        } else {
            showResult()
        }
    }

    // MARK: Restart

    func restart() {
        currentIndex = 0
        correctCount = 0
        parseLyrics()
        userAnswers = Array(repeating: "", count: blanks.count)
        showQuestion()
    }

    // MARK: Result

    private func showResult() {
        answerField.resignFirstResponder()

        PracticeHistoryService.shared.add(PracticeRecord(
            id: UUID(),
            date: Date(),
            type: .dictation,
            trackTitle: track?.title ?? "",
            trackArtist: track?.artist ?? "",
            correctCount: correctCount,
            totalCount: blanks.count
        ))

        let resultVC = DictationResultViewController()
        resultVC.totalCount   = blanks.count
        resultVC.correctCount = correctCount
        resultVC.blanks       = blanks.map { ($0.answer, $0.lineWithBlank) }
        resultVC.userAnswers  = userAnswers
        navigationController?.pushViewController(resultVC, animated: true)
    }

    // MARK: Mini Player

    @objc private func playPauseTapped() {
        NotificationCenter.default.post(name: .musicaRemotePlayPause, object: nil)
    }

    @objc private func onPlaybackStateChanged(_ note: Notification) {
        let isPlaying = note.userInfo?["isPlaying"] as? Bool ?? false
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        playPauseBtn.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill", withConfiguration: cfg), for: .normal)
    }

    @objc private func onTrackChanged() {
        guard !NowPlayingMusicLibraryData.trackData.isEmpty,
              NowPlayingMusicLibraryData.nowPlaying != NOW_NOT_PLAYING else { return }
        let idx = min(NowPlayingMusicLibraryData.nowPlaying,
                      NowPlayingMusicLibraryData.trackData.count - 1)
        let newTrack = NowPlayingMusicLibraryData.trackData[idx]

        // 再生/停止ボタンのアイコンを常に最新状態に同期
        let ppCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        let isPlaying = audioPlayer?.isPlaying ?? false
        playPauseBtn.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill", withConfiguration: ppCfg), for: .normal)

        guard newTrack.url != track.url else { return }

        // ミニプレイヤーのサムネイル・タイトルを即時更新
        updateMiniPlayerTrack(newTrack)

        let lyrics = newTrack.lyric.trimmingCharacters(in: .whitespacesAndNewlines)
        let trackName = newTrack.title.isEmpty ? localText(key: "dictation_this_song") : "「\(newTrack.title)」"

        if !lyrics.isEmpty {
            let alert = UIAlertController(
                title: localText(key: "dictation_track_changed_title"),
                message: String(format: localText(key: "dictation_track_changed_msg"), trackName),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: localText(key: "dictation_switch_practice"), style: .default) { [weak self] _ in
                self?.restartWithNewTrack(track: newTrack, lyrics: lyrics)
            })
            alert.addAction(UIAlertAction(title: localText(key: "dictation_keep_current"), style: .cancel))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(
                title: localText(key: "dictation_no_lyrics_title"),
                message: String(format: localText(key: "dictation_no_lyrics_msg"), trackName),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: localText(key: "btn_ok"), style: .default))
            present(alert, animated: true)
        }
    }

    private func updateMiniPlayerTrack(_ track: TrackData) {
        if let img = track.artworkImg {
            miniPlayerArtView?.image = img
            miniPlayerArtView?.contentMode = .scaleAspectFill
        } else {
            miniPlayerArtView?.image = UIImage(named: "onpu_BL")
            miniPlayerArtView?.contentMode = .center
        }
        miniPlayerTitleLabel?.text = track.title.isEmpty ? localText(key: "practice_unknown") : track.title
    }

    func restartWithNewTrack(track: TrackData, lyrics: String) {
        self.track = track
        self.lyrics = lyrics
        self.selectedLyricLang = nil  // 新トラックは言語を自動判定
        detectLanguage()
        updateMiniPlayerTrack(track)
        currentIndex = 0
        correctCount = 0
        parseLyrics()
        userAnswers = Array(repeating: "", count: blanks.count)
        showQuestion()
    }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let kbFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        bottomInputConstraint.constant = -(kbFrame.height + 8)
        nextLineLabel.isHidden = true
        prevLineTopConstraint?.constant = 8
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        guard let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        bottomInputConstraint.constant = -32
        nextLineLabel.isHidden = false
        prevLineTopConstraint?.constant = 24
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    @objc private func speakTapped() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            updateSpeakBtn(speaking: false)
        } else {
            speakCurrentLine()
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: Voice Input

    @objc private func micTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self, status == .authorized else { return }
                self.beginCapture()
            }
        }
    }

    private func beginCapture() {
        stopRecording()

        // 現在の問いの行から言語を判定してロケールを決める
        let locale: Locale
        if currentIndex < blanks.count {
            let line = blanks[currentIndex].originalLine
            let rec = NLLanguageRecognizer()
            rec.processString(line)
            let lang = rec.dominantLanguage ?? .undetermined
            let map: [NLLanguage: String] = [
                .japanese: "ja-JP", .english: "en-US",
                .korean: "ko-KR",   .simplifiedChinese: "zh-CN",
                .traditionalChinese: "zh-TW",
            ]
            locale = Locale(identifier: map[lang] ?? "en-US")
        } else {
            locale = Locale(identifier: detectedLangCode)
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable else { return }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.recognitionRequest?.append(buf)
        }

        engine.prepare()
        guard (try? engine.start()) != nil else { return }

        sfRecognizer = recognizer
        audioEngine = engine
        recognitionRequest = request
        isRecording = true
        updateMicBtn(recording: true)
        // 録音中はオーディオ一時停止
        pausedForRecording = audioPlayer?.isPlaying ?? false
        if pausedForRecording { audioPlayer?.pause() }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                DispatchQueue.main.async {
                    self.answerField.text = result.bestTranscription.formattedString
                    // 無音が 2 秒続いたら自動停止
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                        self.stopRecording()
                    }
                }
                if result.isFinal {
                    DispatchQueue.main.async { self.stopRecording() }
                }
            }
            if let err = error as NSError?,
               !([203, 216, 1110].contains(err.code) && err.domain == "kAFAssistantErrorDomain") {
                DispatchQueue.main.async { self.stopRecording() }
            }
        }
    }

    private func stopRecording() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        sfRecognizer = nil
        isRecording = false
        updateMicBtn(recording: false)
        // オーディオセッションを再生に戻す
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        if pausedForRecording { audioPlayer?.play(); pausedForRecording = false }
    }

    private func updateMicBtn(recording: Bool) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let icon = recording ? "mic.fill" : "mic"
        micBtn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        micBtn.tintColor = recording ? .systemRed : AppColor.accent
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension DictationViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.updateSpeakBtn(speaking: false) }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.updateSpeakBtn(speaking: false) }
    }
}

// MARK: - UITextFieldDelegate

extension DictationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        checkTapped()
        return false
    }
}

// MARK: - DictationResultViewController

final class DictationResultViewController: UIViewController {

    var totalCount   = 0
    var correctCount = 0
    var blanks:      [(answer: String, lineWithBlank: String)] = []
    var userAnswers: [String] = []

    private let scrollView = UIScrollView()
    private let stack      = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        title = localText(key: "dictation_result_title")
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hidesBackButton = true

        setupLayout()
    }

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
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
        ])

        buildResultContent()
    }

    private func buildResultContent() {
        // スコアカード
        let scoreCard = buildScoreCard()
        stack.addArrangedSubview(scoreCard)

        // 問題別結果
        let reviewHeader = UILabel()
        reviewHeader.text      = localText(key: "dictation_review_header")
        reviewHeader.font      = UIFont.systemFont(ofSize: 18, weight: .bold)
        reviewHeader.textColor = AppColor.textPrimary
        stack.addArrangedSubview(reviewHeader)

        for (i, blank) in blanks.enumerated() {
            let userAns  = i < userAnswers.count ? userAnswers[i] : ""
            let isCorrect = userAns.lowercased() == blank.answer.lowercased()
            stack.addArrangedSubview(buildReviewRow(
                lineWithBlank: blank.lineWithBlank,
                answer:   blank.answer,
                userAns:  userAns,
                isCorrect: isCorrect
            ))
        }

        // ボタン
        let retryBtn = UIButton(type: .system)
        retryBtn.setTitle(localText(key: "dictation_retry_btn"), for: .normal)
        retryBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 16, weight: .semibold)
        retryBtn.backgroundColor   = AppColor.accent
        retryBtn.setTitleColor(.white, for: .normal)
        retryBtn.layer.cornerRadius = 14
        retryBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        retryBtn.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        stack.addArrangedSubview(retryBtn)

        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle(localText(key: "dictation_done_btn"), for: .normal)
        doneBtn.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        doneBtn.setTitleColor(AppColor.textSecondary, for: .normal)
        doneBtn.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        stack.addArrangedSubview(doneBtn)
    }

    private func buildScoreCard() -> UIView {
        let rate = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0
        let emoji: String
        switch rate {
        case 0.9...: emoji = "🏆"
        case 0.7...: emoji = "⭐️"
        case 0.5...: emoji = "📚"
        default:     emoji = "💪"
        }

        let card = UIView()
        card.backgroundColor  = AppColor.accent
        card.layer.cornerRadius = 20
        card.clipsToBounds    = true

        let emojiLabel = UILabel()
        emojiLabel.text          = emoji
        emojiLabel.font          = UIFont.systemFont(ofSize: 48)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        let scoreLabel = UILabel()
        scoreLabel.text          = "\(correctCount) / \(totalCount)"
        scoreLabel.font          = UIFont.systemFont(ofSize: 40, weight: .bold)
        scoreLabel.textColor     = .white
        scoreLabel.textAlignment = .center
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false

        let rateLabel = UILabel()
        rateLabel.text          = String(format: localText(key: "dictation_accuracy_fmt"), rate * 100)
        rateLabel.font          = UIFont.systemFont(ofSize: 15)
        rateLabel.textColor     = UIColor.white.withAlphaComponent(0.85)
        rateLabel.textAlignment = .center
        rateLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(emojiLabel)
        card.addSubview(scoreLabel)
        card.addSubview(rateLabel)
        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            emojiLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            scoreLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 4),
            scoreLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            rateLabel.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 4),
            rateLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            rateLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
        return card
    }

    private func buildReviewRow(lineWithBlank: String, answer: String,
                                 userAns: String, isCorrect: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor  = AppColor.surface
        card.layer.cornerRadius = 12

        let icon = UIImageView(image: UIImage(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
        icon.tintColor = isCorrect ? UIColor.systemGreen : UIColor.systemRed
        icon.translatesAutoresizingMaskIntoConstraints = false

        let lineLabel = UILabel()
        lineLabel.text          = lineWithBlank
        lineLabel.font          = UIFont.systemFont(ofSize: 12)
        lineLabel.textColor     = AppColor.textSecondary
        lineLabel.numberOfLines = 2
        lineLabel.translatesAutoresizingMaskIntoConstraints = false

        let answerLabel = UILabel()
        if isCorrect {
            answerLabel.text      = answer
            answerLabel.textColor = UIColor.systemGreen
        } else {
            let text = userAns.isEmpty ? localText(key: "dictation_skipped") : userAns
            answerLabel.text      = "\(text)  →  \(answer)"
            answerLabel.textColor = UIColor.systemRed
        }
        answerLabel.font          = UIFont.systemFont(ofSize: 14, weight: .semibold)
        answerLabel.numberOfLines = 1
        answerLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [lineLabel, answerLabel])
        textStack.axis    = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(textStack)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 22),
            icon.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        return card
    }

    @objc private func retryTapped() {
        // DictationViewController に戻る（2画面戻る）
        let vcs = navigationController?.viewControllers ?? []
        if let dictationVC = vcs.first(where: { $0 is DictationViewController }) {
            navigationController?.popToViewController(dictationVC, animated: false)
            // 新しいセッションで再起動
            if let vc = dictationVC as? DictationViewController {
                vc.restart()
            }
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    @objc private func doneTapped() {
        // Setup 画面まで戻る
        let vcs = navigationController?.viewControllers ?? []
        if let setupVC = vcs.first(where: { $0 is DictationSetupViewController }) {
            navigationController?.popToViewController(setupVC, animated: true)
        } else {
            navigationController?.popToRootViewController(animated: true)
        }
    }
}
