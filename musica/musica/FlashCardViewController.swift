//
//  FlashCardViewController.swift
//  musica
//
//  歌詞テキストから単語を抽出し、表：単語 / 裏：日本語訳 のフラッシュカード練習を提供する。
//  - NLTagger で品詞フィルタ（名詞・動詞・形容詞・副詞のみ）＋固有名詞除外
//  - iOS 18.0+ Translation framework で日本語訳を取得（それ未満はコンテキスト行のみ）
//

import UIKit
import NaturalLanguage
import AVFoundation

#if canImport(Translation)
import SwiftUI
import Translation
#endif

// MARK: - Translation Bridge (iOS 18.0+)

#if canImport(Translation)
@available(iOS 18.0, *)
private struct WordTranslationBridgeView: View {
    let words: [String]
    let configuration: TranslationSession.Configuration
    let onComplete: ([String: String]) -> Void

    var body: some View {
        Color.clear
            .translationTask(configuration) { session in
                let requests = words.map {
                    TranslationSession.Request(sourceText: $0, clientIdentifier: $0)
                }
                do {
                    let responses = try await session.translations(from: requests)
                    var dict: [String: String] = [:]
                    for r in responses {
                        if let id = r.clientIdentifier { dict[id] = r.targetText }
                    }
                    await MainActor.run { onComplete(dict) }
                } catch {
                    await MainActor.run { onComplete([:]) }
                }
            }
    }
}
#endif

// MARK: - Model

private struct FlashWord {
    let displayWord: String   // display casing (capitalized for English)
    let key: String           // lowercased for dedup / translation lookup
    let contextLine: String   // the lyric line the word came from
    var translation: String?
    var isKnown: Bool = false
}

// MARK: - FlashCardViewController

final class FlashCardViewController: UIViewController {

    // MARK: Input
    var track: TrackData?
    var preloadedWeakWords: [WeakWord]?
    var weakWordMode: Bool { preloadedWeakWords != nil }

    // MARK: State
    private var words: [FlashWord] = []
    private var currentIndex = 0
    private var isShowingBack = false
    private var knownCount = 0

    // MARK: Views
    private let progressBar        = UIProgressView(progressViewStyle: .bar)
    private let progressCountLabel = UILabel()
    private let cardContainer      = UIView()
    private let frontFace          = UIView()
    private let backFace           = UIView()
    private let frontWordLabel     = UILabel()
    private let frontHintLabel     = UILabel()
    private let backTranslLabel    = UILabel()
    private let backContextLabel   = UILabel()
    private let backLoadingIndicator = UIActivityIndicatorView(style: .medium)
    private let reviewBtn          = UIButton(type: .system)
    private let knownBtn           = UIButton(type: .system)
    private let emptyLabel         = UILabel()
    private let speakBtn           = UIButton(type: .system)
    private let synthesizer        = AVSpeechSynthesizer()
    private var detectedLanguage: NLLanguage = .english

    #if canImport(Translation)
    private var translationHost: UIViewController?
    #endif

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = weakWordMode ? localText(key: "flash_weak_mode_title") : "フラッシュカード"
        view.backgroundColor = AppColor.background
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        setupUI()
        extractAndPrepare()
    }

    // MARK: Word Extraction

    private func extractAndPrepare() {
        if let weakWords = preloadedWeakWords, !weakWords.isEmpty {
            words = weakWords.map {
                FlashWord(displayWord: $0.displayWord, key: $0.word,
                          contextLine: $0.contextLine, translation: $0.translation)
            }.shuffled()
            let lyric = words.map { $0.contextLine }.joined(separator: "\n")
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(lyric)
            detectedLanguage = recognizer.dominantLanguage ?? .english
            updateProgress()
            showCurrentCard()
            setButtonsEnabled(true)
            return
        }

        let lyric = track?.lyric ?? ""
        guard !lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showEmptyState()
            return
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(lyric)
        let lang = recognizer.dominantLanguage ?? .english
        detectedLanguage = lang

        words = extractWords(from: lyric, language: lang).shuffled()

        guard !words.isEmpty else {
            showEmptyState()
            return
        }

        requestTranslations(lang: lang)
        updateProgress()
        showCurrentCard()
        setButtonsEnabled(true)
    }

    private func extractWords(from text: String, language: NLLanguage) -> [FlashWord] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])

        // Content-word POS classes to keep
        let keepClasses: Set<NLTag> = [.noun, .verb, .adjective, .adverb]
        // Named-entity classes to discard (固有名詞)
        let namedEntityClasses: Set<NLTag> = [.personalName, .placeName, .organizationName]
        // Minimum word length
        let minLen = (language == .japanese || language == .simplifiedChinese || language == .traditionalChinese) ? 2 : 3

        var wordToLine: [String: String] = [:]

        text.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            tagger.string = trimmed
            tagger.enumerateTags(
                in: trimmed.startIndex..<trimmed.endIndex,
                unit: .word,
                scheme: .lexicalClass,
                options: [.omitWhitespace, .omitPunctuation]
            ) { tag, wordRange in
                let raw = String(trimmed[wordRange])

                // Length filter
                guard raw.count >= minLen else { return true }

                // Must contain at least one Unicode letter (not digits / symbols only)
                guard raw.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return true }

                // POS filter: keep only content words
                guard let tag, keepClasses.contains(tag) else { return true }

                // Discard proper nouns (固有名詞除外)
                let (nameTag, _) = tagger.tag(at: wordRange.lowerBound, unit: .word, scheme: .nameType)
                if let nameTag, namedEntityClasses.contains(nameTag) { return true }

                let key = raw.lowercased()
                if wordToLine[key] == nil { wordToLine[key] = trimmed }
                return true
            }
        }

        return wordToLine.map { key, line in
            // Capitalize first letter for English readability; leave CJK as-is
            let display = language == .english ? key.capitalized : key
            return FlashWord(displayWord: display, key: key, contextLine: line)
        }
    }

    // MARK: Translation

    private func requestTranslations(lang: NLLanguage) {
        #if canImport(Translation)
        if #available(iOS 18.0, *) {
            let sourceID = lang.rawValue
            // If lyrics are Japanese, offer English translation; otherwise offer Japanese
            let targetID = (lang == .japanese) ? "en" : "ja"
            let config = TranslationSession.Configuration(
                source:  Locale.Language(identifier: sourceID),
                target:  Locale.Language(identifier: targetID)
            )
            let wordList = words.map { $0.key }

            let bridgeView = WordTranslationBridgeView(words: wordList, configuration: config) { [weak self] dict in
                guard let self else { return }
                for i in self.words.indices {
                    self.words[i].translation = dict[self.words[i].key]
                }
                if self.isShowingBack { self.refreshBackFace() }
                else { self.backLoadingIndicator.stopAnimating() }

                self.translationHost?.willMove(toParent: nil)
                self.translationHost?.view.removeFromSuperview()
                self.translationHost?.removeFromParent()
                self.translationHost = nil
            }

            let host = UIHostingController(rootView: bridgeView)
            host.view.translatesAutoresizingMaskIntoConstraints = false
            host.view.backgroundColor    = .clear
            host.view.isUserInteractionEnabled = false
            addChild(host)
            view.insertSubview(host.view, at: 0)
            NSLayoutConstraint.activate([
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.widthAnchor.constraint(equalToConstant: 1),
                host.view.heightAnchor.constraint(equalToConstant: 1),
            ])
            host.didMove(toParent: self)
            translationHost = host
        }
        #endif
    }

    // MARK: UI Setup

    private func setupUI() {
        // ── Progress ───────────────────────────────────────────────────
        progressBar.progressTintColor = AppColor.accent
        progressBar.trackTintColor    = AppColor.accent.withAlphaComponent(0.18)
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        progressBar.translatesAutoresizingMaskIntoConstraints = false

        progressCountLabel.font      = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        progressCountLabel.textColor = AppColor.textSecondary
        progressCountLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(progressBar)
        view.addSubview(progressCountLabel)

        // ── Card container ─────────────────────────────────────────────
        cardContainer.backgroundColor    = AppColor.surface
        cardContainer.layer.cornerRadius = 24
        cardContainer.layer.shadowColor  = UIColor.black.cgColor
        cardContainer.layer.shadowOpacity = 0.10
        cardContainer.layer.shadowRadius  = 20
        cardContainer.layer.shadowOffset  = CGSize(width: 0, height: 6)
        cardContainer.translatesAutoresizingMaskIntoConstraints = false

        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        cardContainer.addGestureRecognizer(tap)
        cardContainer.isUserInteractionEnabled = true

        // ── Front face ─────────────────────────────────────────────────
        frontFace.translatesAutoresizingMaskIntoConstraints = false

        frontWordLabel.font             = UIFont.systemFont(ofSize: 38, weight: .bold)
        frontWordLabel.textColor        = AppColor.textPrimary
        frontWordLabel.textAlignment    = .center
        frontWordLabel.numberOfLines    = 3
        frontWordLabel.adjustsFontSizeToFitWidth = true
        frontWordLabel.minimumScaleFactor = 0.5
        frontWordLabel.translatesAutoresizingMaskIntoConstraints = false

        frontHintLabel.text          = "タップして意味を確認"
        frontHintLabel.font          = UIFont.systemFont(ofSize: 13)
        frontHintLabel.textColor     = AppColor.textSecondary
        frontHintLabel.textAlignment = .center
        frontHintLabel.translatesAutoresizingMaskIntoConstraints = false

        frontFace.addSubview(frontWordLabel)
        frontFace.addSubview(frontHintLabel)
        NSLayoutConstraint.activate([
            frontWordLabel.centerXAnchor.constraint(equalTo: frontFace.centerXAnchor),
            frontWordLabel.centerYAnchor.constraint(equalTo: frontFace.centerYAnchor, constant: -14),
            frontWordLabel.leadingAnchor.constraint(equalTo: frontFace.leadingAnchor, constant: 28),
            frontWordLabel.trailingAnchor.constraint(equalTo: frontFace.trailingAnchor, constant: -28),

            frontHintLabel.centerXAnchor.constraint(equalTo: frontFace.centerXAnchor),
            frontHintLabel.topAnchor.constraint(equalTo: frontWordLabel.bottomAnchor, constant: 14),
        ])

        // ── Back face ──────────────────────────────────────────────────
        backFace.isHidden = true
        backFace.translatesAutoresizingMaskIntoConstraints = false

        backTranslLabel.font             = UIFont.systemFont(ofSize: 32, weight: .bold)
        backTranslLabel.textColor        = AppColor.accent
        backTranslLabel.textAlignment    = .center
        backTranslLabel.numberOfLines    = 4
        backTranslLabel.adjustsFontSizeToFitWidth = true
        backTranslLabel.minimumScaleFactor = 0.5
        backTranslLabel.isHidden         = true
        backTranslLabel.translatesAutoresizingMaskIntoConstraints = false

        backContextLabel.font            = UIFont.systemFont(ofSize: 12)
        backContextLabel.textColor       = AppColor.textSecondary
        backContextLabel.textAlignment   = .center
        backContextLabel.numberOfLines   = 3
        backContextLabel.translatesAutoresizingMaskIntoConstraints = false

        backLoadingIndicator.color = AppColor.textSecondary
        backLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        backLoadingIndicator.startAnimating()

        backFace.addSubview(backTranslLabel)
        backFace.addSubview(backContextLabel)
        backFace.addSubview(backLoadingIndicator)
        NSLayoutConstraint.activate([
            backLoadingIndicator.centerXAnchor.constraint(equalTo: backFace.centerXAnchor),
            backLoadingIndicator.centerYAnchor.constraint(equalTo: backFace.centerYAnchor, constant: -14),

            backTranslLabel.centerXAnchor.constraint(equalTo: backFace.centerXAnchor),
            backTranslLabel.centerYAnchor.constraint(equalTo: backFace.centerYAnchor, constant: -14),
            backTranslLabel.leadingAnchor.constraint(equalTo: backFace.leadingAnchor, constant: 28),
            backTranslLabel.trailingAnchor.constraint(equalTo: backFace.trailingAnchor, constant: -28),

            backContextLabel.topAnchor.constraint(equalTo: backTranslLabel.bottomAnchor, constant: 14),
            backContextLabel.centerXAnchor.constraint(equalTo: backFace.centerXAnchor),
            backContextLabel.leadingAnchor.constraint(equalTo: backFace.leadingAnchor, constant: 28),
            backContextLabel.trailingAnchor.constraint(equalTo: backFace.trailingAnchor, constant: -28),
        ])

        cardContainer.addSubview(frontFace)
        cardContainer.addSubview(backFace)
        NSLayoutConstraint.activate([
            frontFace.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            frontFace.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            frontFace.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            frontFace.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),

            backFace.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            backFace.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            backFace.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            backFace.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
        ])
        view.addSubview(cardContainer)

        // ── Buttons ────────────────────────────────────────────────────
        reviewBtn.setImage(UIImage(systemName: "arrow.counterclockwise",
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)), for: .normal)
        reviewBtn.setTitle("  もう一度", for: .normal)
        reviewBtn.tintColor        = .systemRed
        reviewBtn.setTitleColor(.systemRed, for: .normal)
        reviewBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 15, weight: .semibold)
        reviewBtn.backgroundColor   = UIColor.systemRed.withAlphaComponent(0.1)
        reviewBtn.layer.cornerRadius = 18
        reviewBtn.contentEdgeInsets  = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        reviewBtn.addTarget(self, action: #selector(reviewTapped), for: .touchUpInside)
        reviewBtn.translatesAutoresizingMaskIntoConstraints = false
        reviewBtn.isHidden = true

        knownBtn.setImage(UIImage(systemName: "checkmark",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)), for: .normal)
        knownBtn.setTitle("  覚えた", for: .normal)
        knownBtn.tintColor        = AppColor.accent
        knownBtn.setTitleColor(AppColor.accent, for: .normal)
        knownBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 15, weight: .semibold)
        knownBtn.backgroundColor   = AppColor.accent.withAlphaComponent(0.1)
        knownBtn.layer.cornerRadius = 18
        knownBtn.contentEdgeInsets  = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        knownBtn.addTarget(self, action: #selector(knownTapped), for: .touchUpInside)
        knownBtn.translatesAutoresizingMaskIntoConstraints = false
        knownBtn.isHidden = true

        let btnStack = UIStackView(arrangedSubviews: [reviewBtn, knownBtn])
        btnStack.axis         = .horizontal
        btnStack.spacing      = 16
        btnStack.distribution = .fillEqually
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(btnStack)

        // ── Empty state ────────────────────────────────────────────────
        emptyLabel.text          = "歌詞から学習できる単語を\n抽出できませんでした。\n歌詞を登録してから再試行してください。"
        emptyLabel.font          = UIFont.systemFont(ofSize: 15)
        emptyLabel.textColor     = AppColor.textSecondary
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden      = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        // ── Speaker button (floats top-right of card) ──────────────────
        let speakCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        speakBtn.setImage(UIImage(systemName: "speaker.wave.2", withConfiguration: speakCfg), for: .normal)
        speakBtn.tintColor   = AppColor.textSecondary
        speakBtn.backgroundColor = .clear
        speakBtn.addTarget(self, action: #selector(speakWordTapped), for: .touchUpInside)
        speakBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(speakBtn)  // added after cardContainer → renders on top

        // ── Constraints ────────────────────────────────────────────────
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            progressCountLabel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 16),
            progressCountLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -20),

            progressBar.centerYAnchor.constraint(equalTo: progressCountLabel.centerYAnchor),
            progressBar.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: progressCountLabel.leadingAnchor, constant: -12),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            btnStack.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -20),
            btnStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            btnStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            btnStack.heightAnchor.constraint(equalToConstant: 52),

            cardContainer.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 24),
            cardContainer.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            cardContainer.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            cardContainer.bottomAnchor.constraint(equalTo: btnStack.topAnchor, constant: -24),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -32),

            speakBtn.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            speakBtn.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 14),
            speakBtn.widthAnchor.constraint(equalToConstant: 36),
            speakBtn.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    // MARK: Card Display

    private func showCurrentCard() {
        guard currentIndex < words.count else {
            showSummary()
            return
        }
        isShowingBack = false
        frontFace.isHidden = false
        backFace.isHidden  = true
        speakBtn.isHidden  = false
        frontWordLabel.text = words[currentIndex].displayWord
        refreshBackFace()
    }

    private func refreshBackFace() {
        guard currentIndex < words.count else { return }
        let word = words[currentIndex]
        if let trans = word.translation {
            backLoadingIndicator.stopAnimating()
            backLoadingIndicator.isHidden = true
            backTranslLabel.text    = trans
            backTranslLabel.isHidden = false
        } else {
            backLoadingIndicator.startAnimating()
            backLoadingIndicator.isHidden = false
            backTranslLabel.isHidden = true
        }
        backContextLabel.text = "「\(word.contextLine)」"
    }

    private func updateProgress() {
        let total    = words.count
        let done     = currentIndex
        progressBar.setProgress(total > 0 ? Float(done) / Float(total) : 0, animated: true)
        progressCountLabel.text = "\(done) / \(total)"
    }

    private func setButtonsEnabled(_ enabled: Bool) {
        reviewBtn.isHidden = !enabled
        knownBtn.isHidden  = !enabled
    }

    private func showEmptyState() {
        cardContainer.isHidden      = true
        progressBar.isHidden        = true
        progressCountLabel.isHidden = true
        speakBtn.isHidden           = true
        emptyLabel.isHidden         = false
    }

    // MARK: Card Interaction

    @objc private func cardTapped() {
        guard currentIndex < words.count else { return }
        UIView.transition(
            with: cardContainer,
            duration: 0.4,
            options: [isShowingBack ? .transitionFlipFromLeft : .transitionFlipFromRight, .allowUserInteraction]
        ) {
            self.isShowingBack.toggle()
            self.frontFace.isHidden = self.isShowingBack
            self.backFace.isHidden  = !self.isShowingBack
            self.speakBtn.isHidden  = self.isShowingBack
            if self.isShowingBack { self.refreshBackFace() }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func reviewTapped() {
        guard currentIndex < words.count else { return }
        let w = words[currentIndex]
        WeakWordService.shared.upsert(WeakWord(
            word:        w.key,
            displayWord: w.displayWord,
            translation: w.translation,
            contextLine: w.contextLine,
            trackTitle:  track?.title  ?? "",
            trackArtist: track?.artist ?? "",
            addedDate:   Date()
        ))
        currentIndex += 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        advanceCard()
    }

    @objc private func knownTapped() {
        guard currentIndex < words.count else { return }
        words[currentIndex].isKnown = true
        knownCount += 1
        WeakWordService.shared.remove(wordKey: words[currentIndex].key)
        currentIndex += 1
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        advanceCard()
    }

    private func advanceCard() {
        synthesizer.stopSpeaking(at: .immediate)
        updateProgress()
        UIView.transition(with: cardContainer, duration: 0.22, options: .transitionCrossDissolve) {
            self.showCurrentCard()
        }
    }

    @objc private func closeTapped() {
        synthesizer.stopSpeaking(at: .immediate)
        dismiss(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: TTS

    @objc private func speakWordTapped() {
        guard currentIndex < words.count else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            updateSpeakBtnIcon(speaking: false)
            return
        }
        let word     = words[currentIndex].displayWord
        let langCode = langCode(for: detectedLanguage)
        guard let voice = AVSpeechSynthesisVoice(language: langCode) else { return }
        let utterance   = AVSpeechUtterance(string: word)
        utterance.voice = voice
        utterance.rate  = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.delegate = self
        synthesizer.speak(utterance)
        updateSpeakBtnIcon(speaking: true)
    }

    private func updateSpeakBtnIcon(speaking: Bool) {
        let size = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let name = speaking ? "speaker.wave.3.fill" : "speaker.wave.2"
        speakBtn.setImage(UIImage(systemName: name, withConfiguration: size), for: .normal)
        speakBtn.tintColor = speaking ? AppColor.accent : AppColor.textSecondary
    }

    private func langCode(for lang: NLLanguage) -> String {
        let map: [NLLanguage: String] = [
            .japanese: "ja-JP", .english: "en-US",
            .simplifiedChinese: "zh-CN", .traditionalChinese: "zh-TW",
            .korean: "ko-KR", .spanish: "es-ES", .french: "fr-FR",
            .german: "de-DE", .italian: "it-IT", .portuguese: "pt-BR",
            .russian: "ru-RU",
        ]
        return map[lang] ?? "en-US"
    }

    // MARK: Summary

    private func showSummary() {
        PracticeHistoryService.shared.add(PracticeRecord(
            id: UUID(),
            date: Date(),
            type: .flashCard,
            trackTitle:  weakWordMode ? localText(key: "flash_weak_mode_title") : (track?.title  ?? ""),
            trackArtist: weakWordMode ? ""             : (track?.artist ?? ""),
            correctCount: knownCount,
            totalCount: words.count
        ))

        cardContainer.isHidden = true
        setButtonsEnabled(false)
        progressBar.setProgress(1.0, animated: true)
        progressCountLabel.text = "\(words.count) / \(words.count)"

        let pct = words.count > 0 ? knownCount * 100 / words.count : 0

        let summaryView = UIView()
        summaryView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryView)

        let emojiLabel = UILabel()
        emojiLabel.text          = pct >= 80 ? "🎉" : pct >= 50 ? "👍" : "💪"
        emojiLabel.font          = UIFont.systemFont(ofSize: 60)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false

        let pctLabel = UILabel()
        pctLabel.text          = "\(pct)%"
        pctLabel.font          = UIFont.systemFont(ofSize: 52, weight: .heavy)
        pctLabel.textColor     = AppColor.accent
        pctLabel.textAlignment = .center
        pctLabel.translatesAutoresizingMaskIntoConstraints = false

        let scoreLabel = UILabel()
        scoreLabel.text          = "\(words.count)単語中 \(knownCount)単語を覚えました"
        scoreLabel.font          = UIFont.systemFont(ofSize: 18, weight: .semibold)
        scoreLabel.textColor     = AppColor.textPrimary
        scoreLabel.textAlignment = .center
        scoreLabel.numberOfLines = 2
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false

        let doneBtn = UIButton(type: .system)
        doneBtn.setTitle("完了", for: .normal)
        doneBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 17, weight: .semibold)
        doneBtn.backgroundColor   = AppColor.accent
        doneBtn.setTitleColor(.white, for: .normal)
        doneBtn.layer.cornerRadius = 16
        doneBtn.contentEdgeInsets  = UIEdgeInsets(top: 14, left: 52, bottom: 14, right: 52)
        doneBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        doneBtn.translatesAutoresizingMaskIntoConstraints = false

        summaryView.addSubview(emojiLabel)
        summaryView.addSubview(pctLabel)
        summaryView.addSubview(scoreLabel)
        summaryView.addSubview(doneBtn)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            summaryView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            summaryView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            summaryView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            summaryView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),

            emojiLabel.topAnchor.constraint(equalTo: summaryView.topAnchor),
            emojiLabel.centerXAnchor.constraint(equalTo: summaryView.centerXAnchor),

            pctLabel.topAnchor.constraint(equalTo: emojiLabel.bottomAnchor, constant: 8),
            pctLabel.centerXAnchor.constraint(equalTo: summaryView.centerXAnchor),

            scoreLabel.topAnchor.constraint(equalTo: pctLabel.bottomAnchor, constant: 6),
            scoreLabel.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor),
            scoreLabel.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor),

            doneBtn.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 36),
            doneBtn.centerXAnchor.constraint(equalTo: summaryView.centerXAnchor),
            doneBtn.bottomAnchor.constraint(equalTo: summaryView.bottomAnchor),
        ])

        summaryView.alpha = 0
        UIView.animate(withDuration: 0.35) { summaryView.alpha = 1 }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension FlashCardViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.updateSpeakBtnIcon(speaking: false) }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.updateSpeakBtnIcon(speaking: false) }
    }
}
