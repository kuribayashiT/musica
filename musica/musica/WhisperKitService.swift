//
//  WhisperKitService.swift
//  musica
//
//  WhisperKit（オンデバイス Whisper）による文字起こしサービス。
//  iOS 16 以上が必要。初回のみモデルファイルをダウンロード（base: ~74MB）。
//
//  多言語モード:
//    languages が複数の場合、30秒チャンクごとに全言語で転写し
//    avgLogprob（信頼スコア）が最も高い言語の結果を採用。
//    英語・日本語が交互に来る語学教材に最適。
//

import AVFoundation
import Foundation
import NaturalLanguage
import WhisperKit

// MARK: - WhisperKitService

@available(iOS 16, *)
final class WhisperKitService {

    // MARK: - Singleton

    static let shared = WhisperKitService()
    private init() {}

    private var pipe: WhisperKit?
    private var loadedModelName: String?

    // MARK: - Model Options

    struct ModelOption {
        let label: String
        let name: String
        let sizeNote: String
    }

    static let models: [ModelOption] = [
        ModelOption(label: "Tiny（~39MB・最速）",                  name: "openai_whisper-tiny",             sizeNote: "~39MB"),
        ModelOption(label: "Base（~74MB・推奨）",                  name: "openai_whisper-base",             sizeNote: "~74MB"),
        ModelOption(label: "Small（~244MB・高精度）",              name: "openai_whisper-small",            sizeNote: "~244MB"),
        ModelOption(label: "Distil-Large-v3（~600MB・英語特化）",  name: "distil-whisper_distil-large-v3", sizeNote: "~600MB"),
        ModelOption(label: "Large-v3（~1.5GB・最高精度）",         name: "openai_whisper-large-v3",        sizeNote: "~1.5GB"),
    ]

    // MARK: - Language Options

    struct WhisperLanguageOption {
        let label: String
        let codes: [String]   // 空 = 自動検出, 複数 = チャンクごとにベスト選択
    }

    static let languageOptions: [WhisperLanguageOption] = [
        // codes: [] = Whisper 自身が言語を自動検出（task:.transcribe は維持して翻訳抑制）
        WhisperLanguageOption(label: "🌐 全自動（言語自動検出）",          codes: []),
        WhisperLanguageOption(label: "🇯🇵 日本語",                    codes: ["ja"]),
        WhisperLanguageOption(label: "🇺🇸 英語",                      codes: ["en"]),
        WhisperLanguageOption(label: "🔀 日本語＋英語（チャンクごと判定）", codes: ["ja", "en"]),
        WhisperLanguageOption(label: "🇰🇷 韓国語",                    codes: ["ko"]),
        WhisperLanguageOption(label: "🇨🇳 中国語",                    codes: ["zh"]),
        WhisperLanguageOption(label: "🔀 日本語＋韓国語",              codes: ["ja", "ko"]),
        WhisperLanguageOption(label: "🔀 日本語＋中国語",              codes: ["ja", "zh"]),
    ]

    // MARK: - Supported Models

    /// デバイスが実行可能なモデルのみを返す。推奨モデルの name も合わせて返す
    @available(iOS 16, *)
    static func supportedModels() -> (models: [ModelOption], defaultName: String) {
        let recommended  = WhisperKit.recommendedModels()
        let supportedSet = Set(recommended.supported)
        let filtered     = models.filter { supportedSet.contains($0.name) }
        return (filtered.isEmpty ? models : filtered, recommended.default)
    }

    // MARK: - Transcribe Entry Point

    /// - Parameter languages: 空 = auto, 1つ = 単一言語, 複数 = チャンクごとにベスト選択
    func transcribe(
        url: URL,
        modelName: String,
        languages: [String],
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String {

        // モデルが未ロードまたは変更されたら初期化
        if pipe == nil || loadedModelName != modelName {
            let sizeNote = WhisperKitService.models.first { $0.name == modelName }?.sizeNote ?? ""
            await MainActor.run {
                onProgress("モデルを準備中... (初回は \(sizeNote) のダウンロードが発生します)")
            }

            // キャッシュ済みモデルのパスを確認
            // キャッシュがあれば modelFolder を直接渡してネットワーク検証をスキップ
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let cachedPath = documentsDir
                .appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
                .appendingPathComponent(modelName)
                .path

            if FileManager.default.fileExists(atPath: cachedPath) {
                // キャッシュあり: ダウンロードせず直接ロード
                pipe = try await WhisperKit(modelFolder: cachedPath, verbose: false)
            } else {
                // 初回: HuggingFace からダウンロード
                pipe = try await WhisperKit(
                    model: modelName,
                    modelRepo: "argmaxinc/whisperkit-coreml",
                    verbose: false
                )
            }
            loadedModelName = modelName
        }

        // ipod-library:// などの仮想URLは実ファイルにエクスポート
        let fileURL = try await exportToTempFileIfNeeded(url: url, onProgress: onProgress)
        defer {
            if fileURL != url { try? FileManager.default.removeItem(at: fileURL) }
        }

        let rawBody: String

        if languages.count >= 2 {
            // 複数言語指定: チャンクごとにベスト選択
            rawBody = try await transcribeMultiLanguage(fileURL, languages: languages, onProgress: onProgress)
        } else if languages.isEmpty {
            // 全自動: 1文1チャンク＋language=nil（各チャンクでWhisperが言語自動検出）
            rawBody = try await transcribeAutoLanguage(fileURL, onProgress: onProgress)
        } else {
            // 単一言語指定
            let lang: String? = languages.first
            rawBody = try await transcribeSingleLanguage(fileURL, language: lang, onProgress: onProgress)
        }

        let cleaned   = Self.removeSpeakingAnnotations(rawBody)
        var formatted = TranscriptionService.formatTranscription(cleaned)
        // ハルシネーション（繰り返しループ）で同一行が3回以上出た場合は除去する
        formatted = Self.deduplicateLines(formatted)

        return formatted
    }

    // MARK: - Auto Language Transcription（全自動：チャンク単位で言語自動検出）

    /// 語学CDに最適化した全自動文字起こし。
    ///
    /// 「1チャンク = 1文 = 1言語」になるよう小さく分割し、
    /// 各チャンクを language=nil（Whisper自動検出）で転写する。
    /// 日本語文 → ja チャンク、英語訳 → en チャンクとして独立して処理されるため
    /// 両言語が正しい音声順で出力される。
    private func transcribeAutoLanguage(
        _ fileURL: URL,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String {

        await MainActor.run { onProgress("無音区間を検出中...") }

        // 語学CDの1文は2〜3秒。文間ポーズは200ms程度なので minSilenceWindow:2(200ms) で分割。
        // targetDuration:2.0 + minSilenceWindow:2 により 1チャンク≒1文(1言語)になる。
        // 1チャンク1言語にすることで language=nil の自動検出精度が最大化される。
        let chunkURLs = try splitAtSilenceBoundaries(
            url: fileURL,
            targetDuration: 2.0,
            silenceThreshold: 0.025,
            minChunkDuration: 0.8,
            minSilenceWindow: 2     // 200ms: 短い文間ポーズでも積極的に分割
        )
        defer { chunkURLs.forEach { try? FileManager.default.removeItem(at: $0) } }

        let total = chunkURLs.count

        // ── language=nil で全チャンクを文字起こし ──
        // 各チャンクが1文(≒1言語)なので Whisper の言語自動検出が正確に機能する。
        // 日本語チャンク → 日本語で転写、英語チャンク → 英語で転写が自動的に行われる。
        var assembled: [String] = []
        var langCounts: [String: Int] = [:]
        #if DEBUG
        var debugLog: [String] = []
        #endif

        for (i, chunkURL) in chunkURLs.enumerated() {
            await MainActor.run { onProgress("[\(i + 1)/\(total)] 文字起こし中...") }

            let sec: Double
            if let af = try? AVAudioFile(forReading: chunkURL) {
                sec = Double(af.length) / af.processingFormat.sampleRate
            } else { sec = 0 }

            guard sec >= 0.8 else {
                #if DEBUG
                debugLog.append("[\(i + 1)/\(total)][-][\(String(format: "%.1f", sec))s] ⏭️スキップ(短すぎ)")
                #endif
                continue
            }

            var opts = DecodingOptions()
            opts.language                   = nil    // Whisper が言語を自動検出
            opts.task                       = .transcribe
            opts.usePrefillPrompt           = false  // 自動検出モードでは無効化
            opts.skipSpecialTokens          = true
            opts.noSpeechThreshold          = 0.65   // 無音・ノイズチャンクを積極的に除去
            opts.compressionRatioThreshold  = 2.4
            opts.logProbThreshold           = nil
            opts.firstTokenLogProbThreshold = nil

            // 直前1チャンクのテキストをコンテキストとして渡す
            // → 同音異義語（「一般動詞」vs「いっぱん同士」など）の漢字選択精度が向上する
            // usePrefillPrompt=false でも promptTokens は有効（言語自動検出には影響しない）
            if let prev = assembled.last, !prev.isEmpty {
                opts.promptTokens = pipe?.tokenizer?.encode(text: prev)
            }

            let results = try await pipe?.transcribe(audioPath: chunkURL.path, decodeOptions: opts) ?? []
            var text = results.map { $0.text }.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lang = results.first?.language ?? "-"

            if lang != "-" { langCounts[lang, default: 0] += 1 }

            // ── 翻訳検出フォールバック ───────────────────────────────────────────
            // 非ラテン語（ja/ko/zh）が検出されたのに出力に該当文字がない場合、
            // Whisper がチャンク内の母国語部分を英語に翻訳してしまった可能性がある。
            // 対策: 該当言語で再試行して母国語テキストを回収する。
            // チャンクが細かくなった（targetDuration:2.5）ので発生頻度は激減するはず。
            var recovered = false
            if !text.isEmpty && Self.needsTranslationRecovery(lang: lang, text: text) {
                var fixOpts = opts
                fixOpts.language         = lang   // 母国語を強制指定して再試行
                fixOpts.usePrefillPrompt = true
                if let fixResults = try? await pipe?.transcribe(audioPath: chunkURL.path, decodeOptions: fixOpts) {
                    let fixText = (fixResults ?? []).map { $0.text }.joined(separator: " ")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    // fixText に実際に対象言語の文字が含まれている場合のみ採用
                    // （英語で再転写した場合は意味がないためスキップ）
                    let fixHasTargetScript = Self.needsTranslationRecovery(lang: lang, text: fixText) == false
                        && fixText.unicodeScalars.contains { s in
                            (0x3040...0x30FF ~= s.value) ||   // ひらがな・カタカナ
                            (0x4E00...0x9FFF ~= s.value) ||   // 漢字
                            (0xAC00...0xD7AF ~= s.value)      // ハングル
                        }
                    if !fixText.isEmpty && fixHasTargetScript {
                        // 母国語テキストのみ採用（英語部分は別チャンクとして処理済みのはず）
                        text = fixText
                        recovered = true
                    }
                }
            }

            #if DEBUG
            let recoverMark = recovered ? "🔄" : ""
            let preview = text.isEmpty
                ? "⚠️空[\(lang)]"
                : "[\(lang)]\(recoverMark) " + String(text.suffix(35)).replacingOccurrences(of: "\n", with: "↵")
            debugLog.append("[\(i + 1)/\(total)][\(String(format: "%.1f", sec))s] \(preview)")
            #else
            _ = recovered
            #endif

            if !text.isEmpty {
                let filtered = Self.removeRomanizedSentences(text)
                if !filtered.trimmingCharacters(in: .whitespaces).isEmpty {
                    assembled.append(filtered)
                }
            }
        }

        #if DEBUG
        let detectedLangs = langCounts.sorted { $0.value > $1.value }.prefix(3).map { "\($0.key):\($0.value)" }
        dlog("---DEBUG transcribeAutoLanguage---\n" + debugLog.joined(separator: "\n") +
             "\n検出言語: \(detectedLangs.joined(separator: ", "))")
        #endif

        return assembled.joined(separator: " ")
    }

    // MARK: - Single Language Transcription

    private func transcribeSingleLanguage(
        _ fileURL: URL,
        language: String?,   // nil = Whisper が言語自動検出、非nil = 指定言語
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String {

        await MainActor.run { onProgress("無音区間を検出中...") }

        // 無音境界でチャンク分割（話者の切れ目で切るので文の途中で切れない）
        // 5秒チャンク: 1文≒1チャンクになるため言語検出が安定する
        let chunkURLs = try splitAtSilenceBoundaries(url: fileURL, targetDuration: 5, silenceThreshold: 0.025, minChunkDuration: 3)
        defer { chunkURLs.forEach { try? FileManager.default.removeItem(at: $0) } }

        let total = chunkURLs.count
        var assembled: [String] = []   // 結果蓄積 & initialPrompt 用
        #if DEBUG
        var debugLog: [String] = []
        #endif

        for (i, chunkURL) in chunkURLs.enumerated() {
            // チャンクごとに options を組み立て（initialPrompt を毎回更新するため）
            var options = DecodingOptions()
            options.language                   = language
            options.task                       = .transcribe
            options.usePrefillPrompt           = language != nil
            options.noSpeechThreshold          = 1.0
            options.compressionRatioThreshold  = 2.4
            options.logProbThreshold           = nil
            options.firstTokenLogProbThreshold = nil
            // 直前2チャンクの末尾を文脈として渡す（文の途中カットによる断片や誤認識を抑制）
            let prompt = assembled.suffix(2).joined(separator: " ")
            if !prompt.isEmpty {
                options.promptTokens = pipe?.tokenizer?.encode(text: prompt)
            }

            await MainActor.run { onProgress("(\(i + 1)/\(total)) 文字起こし中...") }
            let results = try await pipe?.transcribe(audioPath: chunkURL.path,
                                                      decodeOptions: options) ?? []
            let text = results.map { $0.text }.joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lang = results.first?.language ?? "-"
            #if DEBUG
            let preview = text.isEmpty
                ? "⚠️空"
                : String(text.suffix(40)).replacingOccurrences(of: "\n", with: "↵")
            debugLog.append("[\(i + 1)/\(total)][\(lang)] \(preview)")
            #endif
            await MainActor.run {
                let p = text.isEmpty ? "⚠️空" : String(text.suffix(25))
                onProgress("(\(i + 1)/\(total)) [\(lang)] \(p)")
            }
            if !text.isEmpty { assembled.append(text) }
        }

        #if DEBUG
        dlog("---DEBUG transcribeSingleLanguage---\n" + debugLog.joined(separator: "\n"))
        #endif

        return assembled.joined(separator: " ")
    }

    // MARK: - Multi-Language Transcription（短チャンク×言語ベスト選択）

    /// 5秒程度の短チャンクに分割し、各チャンクを全言語で転写して
    /// avgLogprob（信頼スコア）が最も高い言語の結果を採用する。
    /// 短チャンク＝1文≒1チャンクになるため言語検出が安定し、抜けが激減する。
    private func transcribeMultiLanguage(
        _ fileURL: URL,
        languages: [String],
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> String {

        await MainActor.run { onProgress("無音区間を検出中...") }
        let chunkURLs = try splitAtSilenceBoundaries(url: fileURL,
                                                      targetDuration: 5,
                                                      silenceThreshold: 0.025,
                                                      minChunkDuration: 3)
        defer { chunkURLs.forEach { try? FileManager.default.removeItem(at: $0) } }

        let total = chunkURLs.count
        var assembled: [String] = []

        for (i, chunkURL) in chunkURLs.enumerated() {
            await MainActor.run {
                onProgress("(\(i + 1)/\(total)) 言語判定中...")
            }
            // 直前チャンクの末尾をプロンプトとして渡すことで文脈を引き継ぐ
            let prompt = assembled.suffix(2).joined(separator: " ")
            let bestText = try await combinedTranscription(for: chunkURL, languages: languages, initialPrompt: prompt)
            let trimmed  = bestText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { assembled.append(trimmed) }
        }

        return assembled.joined(separator: " ")
    }

    // セグメント単位でタイムスタンプを保持するための内部型
    private struct TaggedSegment {
        let lang: String
        let start: Float
        let end: Float
        let text: String
        let avgLogprob: Float
    }

    /// 1チャンクを全言語で転写し、セグメントのタイムスタンプ順に並べて返す。
    ///
    /// 従来の「言語パス順に結合」方式を廃止。代わりにセグメントレベルで処理:
    ///   1. 全言語パスのセグメントをタイムスタンプ付きで収集
    ///   2. 開始時刻でソート（音声順を保証）
    ///   3. 重なり > 50% のセグメントは優劣を判定して1つに統合
    ///      - ローマ字日本語なら除去して相手側を採用
    ///      - avgLogprob が明確に高い方を採用
    ///   4. タイムスタンプ順に結合 → 日本語→英語でも英語→日本語でも正しい順序
    private func combinedTranscription(for chunkURL: URL, languages: [String], initialPrompt: String = "") async throws -> String {
        var allSegments: [TaggedSegment] = []

        for lang in languages {
            var opts = DecodingOptions()
            opts.language                   = lang
            opts.task                       = .transcribe
            opts.usePrefillPrompt           = true
            opts.skipSpecialTokens          = true
            opts.noSpeechThreshold          = 1.0
            opts.compressionRatioThreshold  = 2.4
            opts.logProbThreshold           = nil
            opts.firstTokenLogProbThreshold = nil
            if !initialPrompt.isEmpty {
                opts.promptTokens = pipe?.tokenizer?.encode(text: initialPrompt)
            }

            guard let results = try await pipe?.transcribe(audioPath: chunkURL.path,
                                                            decodeOptions: opts),
                  !results.isEmpty else { continue }

            for result in results {
                for seg in result.segments {
                    let text = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }
                    allSegments.append(TaggedSegment(
                        lang: lang,
                        start: seg.start,
                        end: seg.end,
                        text: text,
                        avgLogprob: seg.avgLogprob
                    ))
                }
            }
        }
        guard !allSegments.isEmpty else { return "" }

        // 1. 開始時刻でソート（音声の実際の順序を反映）
        allSegments.sort { $0.start < $1.start }

        // 2. 重複解消: 50%以上重なるセグメントはより良い方だけ残す
        var kept: [TaggedSegment] = []
        for seg in allSegments {
            if let conflictIdx = kept.firstIndex(where: { segmentOverlapRatio($0, seg) > 0.5 }) {
                let existing = kept[conflictIdx]
                let existIsRomaji = Self.isRomanizedJapanese(existing.text)
                let newIsRomaji   = Self.isRomanizedJapanese(seg.text)

                if existIsRomaji && !newIsRomaji {
                    kept[conflictIdx] = seg          // 既存がローマ字 → 新しい方に置換
                } else if !existIsRomaji && newIsRomaji {
                    ()                               // 新しい方がローマ字 → 既存を維持
                } else if seg.avgLogprob > existing.avgLogprob + 0.1 {
                    kept[conflictIdx] = seg          // 信頼スコアが明確に高い → 置換
                }
                // 差が小さい場合は既存を維持（最初に処理した方を優先）
            } else {
                kept.append(seg)
            }
        }

        // 3. 開始時刻順に並べてテキスト結合
        kept.sort { $0.start < $1.start }
        return kept.map { $0.text }.joined(separator: " ")
    }

    /// 2つのセグメントの重なり率を返す（短い方の長さに対する重なりの割合）
    private func segmentOverlapRatio(_ a: TaggedSegment, _ b: TaggedSegment) -> Float {
        let overlapStart = max(a.start, b.start)
        let overlapEnd   = min(a.end,   b.end)
        let overlap      = max(0, overlapEnd - overlapStart)
        let shorter      = min(a.end - a.start, b.end - b.start)
        return shorter > 0 ? overlap / shorter : 0
    }

    // MARK: - Silence-Based Splitting

    /// 無音区間を検出してそこでチャンク分割する。
    /// - targetDuration: 目標チャンク長（秒）。無音が見つからない場合はこの時間でハードカット
    /// - silenceThreshold: 無音判定 RMS しきい値（0.0〜1.0、小さいほど厳しい）
    /// - minChunkDuration: チャンクの最小長（秒）。これより短い分割は行わない
    /// - minSilenceWindow: 分割点と認める最短無音ウィンドウ数（1ウィンドウ=100ms）。
    ///                     小さいほど短いポーズでも分割 → 語学CDの文間ポーズ(300ms)で分割可能
    private func splitAtSilenceBoundaries(
        url: URL,
        targetDuration: TimeInterval = 25,
        silenceThreshold: Float = 0.015,
        minChunkDuration: TimeInterval = 8,
        minSilenceWindow: Int = 5
    ) throws -> [URL] {

        guard let srcFile = try? AVAudioFile(forReading: url) else {
            throw NSError(domain: "WhisperKitService", code: -5,
                          userInfo: [NSLocalizedDescriptionKey: "音声ファイルを開けませんでした"])
        }

        let srcFormat  = srcFile.processingFormat
        let srcRate    = srcFormat.sampleRate
        let windowSec  = 0.1                              // 100ms ウィンドウで RMS を計算
        let windowSize = Int(srcRate * windowSec)
        let readChunk  = Int(srcRate * 5)                 // 5秒ずつ読み込む（メモリ節約）

        // ── 1. 無音マップ作成（100ms 単位の bool 配列）──────────────────────────
        var silenceMap  = [Bool]()
        var totalFrames = 0

        while true {
            guard let buf = AVAudioPCMBuffer(pcmFormat: srcFormat,
                                             frameCapacity: AVAudioFrameCount(readChunk)) else { break }
            srcFile.framePosition = AVAudioFramePosition(totalFrames)
            do { try srcFile.read(into: buf, frameCount: AVAudioFrameCount(readChunk)) }
            catch { break }
            guard buf.frameLength > 0 else { break }

            let frames    = Int(buf.frameLength)
            let channels  = Int(srcFormat.channelCount)
            var winStart  = 0
            while winStart < frames {
                let winEnd = min(winStart + windowSize, frames)
                var sumSq: Float = 0
                var cnt   = 0
                for ch in 0..<channels {
                    if let ptr = buf.floatChannelData?[ch] {
                        for f in winStart..<winEnd { sumSq += ptr[f] * ptr[f]; cnt += 1 }
                    }
                }
                let rms = cnt > 0 ? sqrt(sumSq / Float(cnt)) : 0
                silenceMap.append(rms < silenceThreshold)
                winStart += windowSize
            }
            totalFrames += frames
        }

        // ── 2. スプリットポイントを無音区間の中点に決定 ───────────────────────
        let targetFrames  = Int(srcRate * targetDuration)
        let searchFrames  = Int(srcRate * min(targetDuration, 7))  // target以内で探索
        let minChunk      = Int(srcRate * minChunkDuration)
        let minSilWin     = minSilenceWindow   // 呼び出し側から制御可能（デフォルト5=500ms）

        var splitPoints   = [0]
        while let last = splitPoints.last, last < totalFrames {
            let target = last + targetFrames
            if target >= totalFrames { break }

            let sStart = max(last + minChunk, target - searchFrames)
            let sEnd   = min(totalFrames, target + searchFrames)
            let wStart = sStart / windowSize
            let wEnd   = min(sEnd / windowSize, silenceMap.count - 1)

            // 探索範囲内で最長かつ minSilWin 以上の無音区間の中点を分割点にする
            var bestMid   = target   // 無音が見つからなければ target でハードカット
            var bestLen   = 0
            var silStart  = -1

            if wStart <= wEnd {
                for w in wStart...wEnd {
                    if silenceMap[w] {
                        if silStart < 0 { silStart = w }
                        let len = w - silStart + 1
                        if len >= minSilWin && len > bestLen {
                            bestLen = len
                            bestMid = ((silStart + w) / 2) * windowSize
                        }
                    } else {
                        silStart = -1
                    }
                }
            }
            splitPoints.append(bestMid)
        }
        splitPoints.append(totalFrames)

        // ── 3. 各スプリットを WAV ファイルに書き出す ──────────────────────────
        let dstRate: Double = 16000
        guard let dstFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: dstRate,
                                            channels: 1,
                                            interleaved: false) else {
            throw NSError(domain: "WhisperKitService", code: -6,
                          userInfo: [NSLocalizedDescriptionKey: "出力フォーマット作成失敗"])
        }

        var chunkURLs = [URL]()
        for i in 0..<(splitPoints.count - 1) {
            guard let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else { continue }
            let start     = splitPoints[i]
            let end       = splitPoints[i + 1]
            let srcFrames = AVAudioFrameCount(end - start)
            let dstFrames = AVAudioFrameCount(Double(srcFrames) / srcRate * dstRate) + 512

            guard let srcBuf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: srcFrames),
                  let dstBuf = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: dstFrames)
            else { continue }

            srcFile.framePosition = AVAudioFramePosition(start)
            try srcFile.read(into: srcBuf, frameCount: srcFrames)

            var consumed = false
            var convErr: NSError?
            converter.convert(to: dstBuf, error: &convErr) { _, status in
                if consumed { status.pointee = .noDataNow; return nil }
                status.pointee = .haveData; consumed = true; return srcBuf
            }
            if convErr != nil { continue }

            let chunkURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("wk_sil_\(i)_\(UUID().uuidString).wav")
            let outFile = try AVAudioFile(forWriting: chunkURL, settings: dstFormat.settings)
            try outFile.write(from: dstBuf)

            // 末尾に 0.5秒の無音パディング（Whisperに「ここで終わり」を伝える）
            let padFrames = AVAudioFrameCount(dstRate * 0.5)
            if let padBuf = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: padFrames) {
                padBuf.frameLength = padFrames
                // floatChannelData はゼロ初期化済みなので書くだけでOK
                try outFile.write(from: padBuf)
            }

            chunkURLs.append(chunkURL)
        }

        return chunkURLs
    }

    // MARK: - WAV Conversion

    /// 音声ファイルを WhisperKit が最も安定して処理できる 16kHz mono WAV に変換する。
    /// m4a(AAC)はランダムアクセスが非効率で WhisperKit の内部スライディングウィンドウが
    /// ファイル後半でシーク失敗することがあるため、事前に WAV 変換する。
    private func convertToWav(url: URL) throws -> URL {
        guard let srcFile = try? AVAudioFile(forReading: url) else {
            throw NSError(domain: "WhisperKitService", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "音声ファイルを開けませんでした"])
        }

        let srcFormat = srcFile.processingFormat
        let dstRate: Double = 16000
        guard let dstFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                            sampleRate: dstRate,
                                            channels: 1,
                                            interleaved: false),
              let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else {
            throw NSError(domain: "WhisperKitService", code: -4,
                          userInfo: [NSLocalizedDescriptionKey: "音声フォーマットの変換器を作成できませんでした"])
        }

        let totalFrames   = AVAudioFrameCount(srcFile.length)
        let readChunk     = AVAudioFrameCount(srcFormat.sampleRate * 10) // 10秒ずつ読み込み
        let dstChunk      = AVAudioFrameCount(dstRate * 10) + 512
        let wavURL        = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_full_\(UUID().uuidString).wav")
        let outFile       = try AVAudioFile(forWriting: wavURL, settings: dstFormat.settings)

        var srcOffset: AVAudioFramePosition = 0
        while srcOffset < AVAudioFramePosition(totalFrames) {
            let remaining  = AVAudioFrameCount(AVAudioFramePosition(totalFrames) - srcOffset)
            let frames     = min(readChunk, remaining)
            guard let srcBuf = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: frames),
                  let dstBuf = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: dstChunk) else { break }

            srcFile.framePosition = srcOffset
            try srcFile.read(into: srcBuf, frameCount: frames)

            var consumed = false
            var convErr: NSError?
            converter.convert(to: dstBuf, error: &convErr) { _, status in
                if consumed { status.pointee = .noDataNow; return nil }
                status.pointee = .haveData
                consumed = true
                return srcBuf
            }
            if let err = convErr { throw err }
            try outFile.write(from: dstBuf)
            srcOffset += AVAudioFramePosition(frames)
        }

        return wavURL
    }

    // MARK: - Export Helper

    /// ipod-library:// など実パスでないURLを一時ファイルに書き出す
    private func exportToTempFileIfNeeded(
        url: URL,
        onProgress: @escaping @Sendable (String) -> Void
    ) async throws -> URL {
        if url.isFileURL { return url }

        await MainActor.run { onProgress("音声ファイルを準備中...") }

        let asset = AVURLAsset(url: url)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        guard let session = AVAssetExportSession(asset: asset,
                                                  presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "WhisperKitService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "エクスポートセッションを作成できませんでした"])
        }
        session.outputURL = tempURL
        session.outputFileType = .m4a

        await session.export()

        if let error = session.error {
            throw error
        }
        guard session.status == .completed else {
            throw NSError(domain: "WhisperKitService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "音声ファイルのエクスポートに失敗しました (status: \(session.status.rawValue))"])
        }
        return tempURL
    }

    // MARK: - Translation Detection

    /// 検出言語が非ラテン語（ja/ko/zh）なのにテキストに該当文字が含まれない場合 true を返す。
    /// Whisper が混在チャンクの日本語・韓国語・中国語音声を英語に翻訳した疑いがある状態を検出する。
    private static func needsTranslationRecovery(lang: String, text: String) -> Bool {
        guard !text.isEmpty else { return false }
        switch lang {
        case "ja":
            // ひらがな・カタカナ・漢字が一切ない場合に翻訳と判定
            return !text.unicodeScalars.contains { s in
                (s.value >= 0x3040 && s.value <= 0x309F) ||  // ひらがな
                (s.value >= 0x30A0 && s.value <= 0x30FF) ||  // カタカナ
                (s.value >= 0x4E00 && s.value <= 0x9FFF)     // CJK漢字
            }
        case "ko":
            return !text.unicodeScalars.contains { s in
                s.value >= 0xAC00 && s.value <= 0xD7A3       // ハングル
            }
        case "zh":
            return !text.unicodeScalars.contains { s in
                s.value >= 0x4E00 && s.value <= 0x9FFF       // CJK漢字
            }
        default:
            return false
        }
    }

    // MARK: - Romanized Japanese Removal

    /// ヘボン式ローマ字で書かれた日本語文を除去する。
    /// Whisper が日本語音声を誤ってローマ字で出力した場合（例: "Anata wa eigo o hanashimasu ka?"）を除去。
    /// チャンク単位で呼ぶこと（join後だと日本語混在で全体がASCIIにならず除去できない）。
    private static func removeRomanizedSentences(_ text: String) -> String {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var kept: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespaces)
            if !isRomanizedJapanese(sentence) {
                kept.append(sentence)
            }
            return true
        }
        return kept.joined(separator: " ")
    }

    private static func isRomanizedJapanese(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        // ASCII文字のみで構成されているか
        guard text.unicodeScalars.allSatisfy({ $0.value < 128 }) else { return false }
        // ヘボン式ローマ字の日本語助詞・語尾が2つ以上含まれていればローマ字日本語と判定
        let lower = text.lowercased()
        let markers = ["masu", "desu", "imasu", "shimasu", " wa ", " ga ", " wo ",
                       " ni ", " no ", " de ", " ka?", " ka.", " yo ", "mashita"]
        let count = markers.filter { lower.contains($0) }.count
        return count >= 2
    }

    // MARK: - Deduplication

    /// 同一行が maxAllowed 回を超えて現れる場合、超過分を除去する（ハルシネーション対策）。
    /// 語学学習CDでは同じ文が2回繰り返されることがあるため、上限を2に設定。
    private static func deduplicateLines(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var counts: [String: Int] = [:]
        var result: [String] = []
        let maxAllowed = 1   // 語学学習CDでも同文の繰り返しはハルシネーション扱いで除去

        for line in lines {
            let key = line.trimmingCharacters(in: .whitespaces)
            if key.isEmpty {
                result.append(line)
                continue
            }
            let n = counts[key, default: 0]
            if n < maxAllowed {
                result.append(line)
                counts[key] = n + 1
            }
            // maxAllowed 回を超えた行はスキップ（ループ系ハルシネーション除去）
        }
        return result.joined(separator: "\n")
    }

    // MARK: - Annotation Cleanup

    /// "(Speaking Japanese)" / "[Music]" などWhisperが挿入する注釈、および
    /// skipSpecialTokens が効かなかった場合の <|token|> 形式の特殊トークンを除去。
    /// ヘボン式ローマ字で書かれた日本語文（Whisperの言語迷い産物）も除去する。
    private static func removeSpeakingAnnotations(_ text: String) -> String {
        var result = text
        let patterns = [
            "<\\|[^|]*\\|>",                  // <|startoftranscript|> <|ja|> <|0.00|> などWhisper特殊トークン
            "\\(Speaking [^)]+\\)",           // (Speaking Japanese) など
            "\\[Speaking [^\\]]+\\]",         // [Speaking Japanese] など
            "\\[[A-Za-z_\\s]+\\]",            // [BLANK_AUDIO], [MUSIC], [ Silence ] など（小文字・スペース含む）
            "\\(\\s*[A-Z][^)]{0,30}\\)",      // (Music), (Applause) など短い英語注釈
            "\\(\\s*音楽\\s*\\)",             // (音楽), ( 音楽 ) など（スペース混入版も対応）
            "（\\s*音楽\\s*）",               // 全角括弧版
            "\\(\\s*拍手\\s*\\)", "（\\s*拍手\\s*）", // 拍手
            "\\(\\s*BGM\\s*\\)",              // (BGM)
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // ── ヘボン式ローマ字日本語の行を除去 ──────────────────────────────────
        // 例: "Anata wa eigo o hanashimasu ka?" のような
        // 日本語音声をWhisperがローマ字で誤認識した行を除去する。
        // 判定基準: ASCII のみ かつ masu/desu/ka/wa/no/ni/ga/wo/de など
        // 日本語助詞・語尾がスペース区切りで出現する
        let romajiMarkers = ["masu", "desu", "imasu", "shimasu", " wa ", " ga ", " wo ", " ni ", " no ", " de ", " ka?", " ka。", " ka."]
        let lines = result.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return true }
            // ASCII文字のみで構成されている行に対してチェック
            let isAllAscii = trimmed.unicodeScalars.allSatisfy { $0.value < 128 }
            guard isAllAscii else { return true } // 日本語・中国語が含まれる行は除外しない
            let lower = trimmed.lowercased()
            // ローマ字マーカーが2つ以上あればローマ字日本語と判定
            let markerCount = romajiMarkers.filter { lower.contains($0) }.count
            return markerCount < 2
        }
        return filtered.joined(separator: "\n")
    }
}
