//
//  TranscriptionService.swift
//  musica
//
//  音声ファイルをチャンク分割して SFSpeechRecognizer で文字起こし。
//
//  複数言語モード（自動判定）:
//    各チャンクを指定した全言語で並列認識し、最も長い結果を採用。
//    日本語解説 + 英語フレーズが混在する語学学習CDに対応。
//
//  必要な Info.plist キー: NSSpeechRecognitionUsageDescription
//

import AVFoundation
import NaturalLanguage
import Speech

// MARK: - TranscriptionService

struct TranscriptionService {

    // MARK: - Constants

    static let chunkDuration: TimeInterval = 55

    // MARK: - Errors

    enum TranscriptionError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case cannotReadFile(URL)
        case failed(Error)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "音声認識の権限がありません。設定 → プライバシーとセキュリティ → 音声認識 からアプリを許可してください。"
            case .recognizerUnavailable:
                return "指定した言語の音声認識が利用できません。"
            case .cannotReadFile(let url):
                return "音声ファイルを読み込めませんでした。(\(url.lastPathComponent))"
            case .failed(let e):
                return "文字起こし失敗: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Language Options

    struct LanguageOption {
        let label: String
        let locales: [Locale]   // 複数指定 = 自動判定モード
    }

    static let languages: [LanguageOption] = [
        // 自動判定（語学学習CD向け）
        LanguageOption(label: "🔀 自動判定（日本語＋英語）",
                       locales: [Locale(identifier: "ja-JP"), Locale(identifier: "en-US")]),
        LanguageOption(label: "🔀 自動判定（日本語＋韓国語）",
                       locales: [Locale(identifier: "ja-JP"), Locale(identifier: "ko-KR")]),
        LanguageOption(label: "🔀 自動判定（日本語＋中国語）",
                       locales: [Locale(identifier: "ja-JP"), Locale(identifier: "zh-Hans-CN")]),
        // 単一言語
        LanguageOption(label: "英語（US）",     locales: [Locale(identifier: "en-US")]),
        LanguageOption(label: "英語（UK）",     locales: [Locale(identifier: "en-GB")]),
        LanguageOption(label: "日本語",         locales: [Locale(identifier: "ja-JP")]),
        LanguageOption(label: "韓国語",         locales: [Locale(identifier: "ko-KR")]),
        LanguageOption(label: "中国語（簡体）", locales: [Locale(identifier: "zh-Hans-CN")]),
        LanguageOption(label: "フランス語",     locales: [Locale(identifier: "fr-FR")]),
        LanguageOption(label: "スペイン語",     locales: [Locale(identifier: "es-ES")]),
        LanguageOption(label: "ドイツ語",       locales: [Locale(identifier: "de-DE")]),
    ]

    // MARK: - Format

    /// 文字起こし結果を自然な改行付きテキストに整形する。
    /// NLTokenizer で文境界を検出し、1文 = 1行にする。
    static func formatTranscription(_ raw: String) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = raw
        var lines: [String] = []
        tokenizer.enumerateTokens(in: raw.startIndex..<raw.endIndex) { range, _ in
            let line = raw[range].trimmingCharacters(in: .whitespaces)
            if !line.isEmpty { lines.append(line) }
            return true
        }
        return lines.isEmpty ? raw : lines.joined(separator: "\n")
    }

    // MARK: - Duration

    static func audioDuration(url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        let d = CMTimeGetSeconds(asset.duration)
        return d.isFinite && d > 0 ? d : nil
    }

    // MARK: - Transcribe

    /// チャンク分割して文字起こし。locales が複数の場合は各チャンクで全言語を試し最長結果を採用。
    @discardableResult
    static func transcribe(
        url: URL,
        locales: [Locale],
        chunkDuration: TimeInterval = TranscriptionService.chunkDuration,
        onChunkProgress: @escaping (_ partial: String, _ chunk: Int, _ total: Int) -> Void,
        completion: @escaping (Result<String, TranscriptionError>) -> Void
    ) -> (() -> Void) {

        var isCancelled = false
        var activeTasks: [SFSpeechRecognitionTask] = []

        let cancel: () -> Void = {
            isCancelled = true
            activeTasks.forEach { $0.cancel() }
        }

        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    completion(.failure(.notAuthorized))
                    return
                }

                // 使用可能な recognizer のみ残す
                let recognizers = locales.compactMap { locale -> SFSpeechRecognizer? in
                    guard let r = SFSpeechRecognizer(locale: locale), r.isAvailable else { return nil }
                    return r
                }
                guard !recognizers.isEmpty else {
                    completion(.failure(.recognizerUnavailable))
                    return
                }

                do {
                    let chunkURLs = try splitAudioIntoChunks(url: url, chunkDuration: chunkDuration)
                    let total = chunkURLs.count

                    processChunks(
                        chunkURLs: chunkURLs,
                        chunkIndex: 0,
                        total: total,
                        recognizers: recognizers,
                        accumulated: [],
                        isCancelled: { isCancelled },
                        onTaskCreated: { activeTasks.append($0) },
                        onChunkProgress: onChunkProgress,
                        completion: { result in
                            chunkURLs.forEach { try? FileManager.default.removeItem(at: $0) }
                            completion(result)
                        }
                    )
                } catch let e as TranscriptionError {
                    completion(.failure(e))
                } catch {
                    completion(.failure(.cannotReadFile(url)))
                }
            }
        }

        return cancel
    }

    // MARK: - Split Audio（16kHz モノラルに変換）

    /// - Parameters:
    ///   - chunkDuration: 1チャンクの長さ（秒）
    ///   - stride: 次のチャンク開始までの進み幅（秒）。chunkDuration より小さくするとオーバーラップになる
    static func splitAudioIntoChunks(url: URL,
                                     chunkDuration: TimeInterval,
                                     stride: TimeInterval? = nil) throws -> [URL] {
        guard let srcFile = try? AVAudioFile(forReading: url) else {
            throw TranscriptionError.cannotReadFile(url)
        }

        let srcFormat   = srcFile.processingFormat
        let srcRate     = srcFormat.sampleRate
        let totalFrames = AVAudioFrameCount(srcFile.length)

        let dstRate: Double = 16000
        guard let dstFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: dstRate,
                                            channels: 1,
                                            interleaved: false) else {
            throw TranscriptionError.cannotReadFile(url)
        }

        let srcFramesPerChunk  = AVAudioFrameCount(chunkDuration * srcRate)
        let dstFramesPerChunk  = AVAudioFrameCount(chunkDuration * dstRate) + 512
        let strideFrames       = AVAudioFrameCount((stride ?? chunkDuration) * srcRate)

        var chunkURLs: [URL] = []
        var srcOffset: AVAudioFramePosition = 0
        let tmpDir = FileManager.default.temporaryDirectory

        while srcOffset < AVAudioFramePosition(totalFrames) {
            // コンバーターはチャンクごとに新規作成（再利用するとフィルタ状態が蓄積して後半が歪む）
            guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else { break }

            let remaining = AVAudioFrameCount(AVAudioFramePosition(totalFrames) - srcOffset)
            let srcFrames = min(srcFramesPerChunk, remaining)

            guard let srcBuf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: srcFrames),
                  let dstBuf = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: dstFramesPerChunk) else { break }

            srcFile.framePosition = srcOffset
            try srcFile.read(into: srcBuf, frameCount: srcFrames)

            var srcConsumed = false
            var convErr: NSError?
            converter.convert(to: dstBuf, error: &convErr) { _, outStatus in
                if srcConsumed { outStatus.pointee = .noDataNow; return nil }
                outStatus.pointee = .haveData
                srcConsumed = true
                return srcBuf
            }
            if let err = convErr { throw err }

            let chunkURL = tmpDir.appendingPathComponent(
                "tr_chunk_\(chunkURLs.count)_\(UUID().uuidString).wav"
            )
            let outFile = try AVAudioFile(forWriting: chunkURL, settings: dstFormat.settings)
            try outFile.write(from: dstBuf)

            chunkURLs.append(chunkURL)
            srcOffset += AVAudioFramePosition(strideFrames)
        }

        return chunkURLs
    }

    // MARK: - Sequential Chunk Processing

    private static func processChunks(
        chunkURLs: [URL],
        chunkIndex: Int,
        total: Int,
        recognizers: [SFSpeechRecognizer],
        accumulated: [String],
        isCancelled: @escaping () -> Bool,
        onTaskCreated: @escaping (SFSpeechRecognitionTask) -> Void,
        onChunkProgress: @escaping (String, Int, Int) -> Void,
        completion: @escaping (Result<String, TranscriptionError>) -> Void
    ) {
        guard !isCancelled() else { return }
        guard chunkIndex < chunkURLs.count else {
            let joined    = accumulated.joined(separator: " ")
            let formatted = formatTranscription(joined)
            completion(.success(formatted))
            return
        }

        let advance: (String) -> Void = { chunkText in
            guard !isCancelled() else { return }
            processChunks(
                chunkURLs: chunkURLs,
                chunkIndex: chunkIndex + 1,
                total: total,
                recognizers: recognizers,
                accumulated: accumulated + [chunkText],
                isCancelled: isCancelled,
                onTaskCreated: onTaskCreated,
                onChunkProgress: onChunkProgress,
                completion: completion
            )
        }

        // 複数言語を並列認識して一番長い結果を採用
        recognizeBestResult(
            chunkURL: chunkURLs[chunkIndex],
            recognizers: recognizers,
            isCancelled: isCancelled,
            onTaskCreated: onTaskCreated,
            onProgress: { partial in
                let preview = (accumulated + [partial]).joined(separator: "\n")
                onChunkProgress(preview, chunkIndex, total)
            },
            completion: advance
        )
    }

    // MARK: - Multi-language Best-Result Recognition

    /// 1チャンクを全 recognizer で並列認識し、最長テキストを返す。
    private static func recognizeBestResult(
        chunkURL: URL,
        recognizers: [SFSpeechRecognizer],
        isCancelled: @escaping () -> Bool,
        onTaskCreated: @escaping (SFSpeechRecognitionTask) -> Void,
        onProgress: @escaping (String) -> Void,
        completion: @escaping (String) -> Void
    ) {
        let group = DispatchGroup()
        let lock = NSLock()
        var bestText = ""

        for recognizer in recognizers {
            group.enter()
            let request = SFSpeechURLRecognitionRequest(url: chunkURL)
            request.shouldReportPartialResults = true
            if #available(iOS 16.0, *) { request.addsPunctuation = true }

            var localBest = ""

            let task = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    let text = result.bestTranscription.formattedString
                    if text.count > localBest.count { localBest = text }

                    // 進捗表示は最初の recognizer（主言語）のみ
                    if recognizer === recognizers.first {
                        DispatchQueue.main.async { onProgress(localBest) }
                    }

                    if result.isFinal {
                        lock.lock()
                        if localBest.count > bestText.count { bestText = localBest }
                        lock.unlock()
                        group.leave()
                    }
                }
                if let error {
                    let nsErr = error as NSError
                    let isSoft = nsErr.domain == "kAFAssistantErrorDomain"
                        && [203, 216, 1110].contains(nsErr.code)
                    if isSoft {
                        lock.lock()
                        if localBest.count > bestText.count { bestText = localBest }
                        lock.unlock()
                        group.leave()
                    }
                }
            }
            onTaskCreated(task)
        }

        group.notify(queue: .main) {
            guard !isCancelled() else { return }
            completion(bestText)
        }
    }
}
