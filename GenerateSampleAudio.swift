#!/usr/bin/env swift
//
//  GenerateSampleAudio.swift
//
//  【使い方】
//  ターミナルで実行:
//    swift /Users/kuribayashi/Desktop/Dev/musica/GenerateSampleAudio.swift
//
//  生成された .caf で musica/musica/ 内の既存ファイルを上書きしてください。
//
//  各文を EN / JA それぞれ別の say コールで生成し、
//  AIFF → WAV 変換後に Python の wave モジュールで結合します。
//

import Foundation

// MARK: - Shell helper

@discardableResult
func shell(_ cmd: String) -> (out: String, code: Int32) {
    let t = Process()
    t.launchPath = "/bin/bash"
    t.arguments  = ["-c", cmd]
    let pipe = Pipe(), errPipe = Pipe()
    t.standardOutput = pipe
    t.standardError  = errPipe
    t.launch(); t.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (out, t.terminationStatus)
}

/// locale 例: "en_US", "ja_JP"
func bestVoice(locale: String) -> String {
    let list  = shell("say -v ? 2>/dev/null").out
    let lines = list.components(separatedBy: "\n").filter { $0.contains(locale) }

    let excluded = ["Albert","Bad News","Bahh","Bells","Boing","Bubbles",
                    "Cellos","Wobble","Jester","Junior","Organ","Superstar",
                    "Trinoids","Zarvox","Good News","Ralph","Kathy"]

    func name(_ l: String) -> String {
        l.components(separatedBy: "  ").first?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    func isGood(_ l: String) -> Bool { !excluded.contains(where: { l.hasPrefix($0) }) }

    for q in ["premium", "enhanced"] {
        if let l = lines.first(where: { $0.lowercased().contains(q) && isGood($0) }) {
            return name(l)
        }
    }
    let preferred = locale == "ja_JP"
        ? ["Kyoko", "Otoya", "Flo", "Eddy"]
        : ["Samantha", "Flo", "Eddy", "Reed", "Shelley"]
    for p in preferred {
        if lines.contains(where: { $0.hasPrefix(p) }) { return p }
    }
    return name(lines.first ?? "")
}

// MARK: - Python helper (WAV 結合・無音生成)
// say の出力は AIFC (非標準圧縮) のため afconvert で WAV に変換してから wave モジュールで処理する

let pyHelperPath = "/tmp/musica_audio_helper.py"

func writePythonHelper() {
    let code = #"""
#!/usr/bin/env python3
import sys, wave

def gen_silence(ms_str, out_path):
    ms = int(ms_str)
    sample_rate = 22050
    n = sample_rate * ms // 1000
    with wave.open(out_path, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sample_rate)
        f.writeframes(b'\x00\x00' * n)

def concat_wav(in_files, out_path):
    all_frames = b''
    params = None
    for fn in in_files:
        try:
            with wave.open(fn, 'rb') as wf:
                if params is None:
                    params = wf.getparams()
                all_frames += wf.readframes(wf.getnframes())
        except Exception as e:
            print(f'[concat] warning {fn}: {e}', file=sys.stderr)
    if params and all_frames:
        with wave.open(out_path, 'wb') as out_f:
            out_f.setparams(params)
            out_f.writeframes(all_frames)

cmd = sys.argv[1]
if cmd == 'silence':
    gen_silence(sys.argv[2], sys.argv[3])
elif cmd == 'concat':
    concat_wav(sys.argv[2:-1], sys.argv[-1])
"""#
    try? code.write(toFile: pyHelperPath, atomically: true, encoding: .utf8)
}

/// WAV 形式の無音ファイルを生成してパスを返す
func genSilence(ms: Int) -> String {
    let path = "/tmp/musica_sil_\(ms).wav"
    if !FileManager.default.fileExists(atPath: path) {
        shell("python3 '\(pyHelperPath)' silence \(ms) '\(path)'")
    }
    return path
}

/// AIFF → WAV 変換（say の出力は AIFC なので必須）
func aiff2wav(_ aiff: String, _ wav: String) -> Bool {
    shell("afconvert '\(aiff)' '\(wav)' -d LEI16@22050 -f WAVE").code == 0
}

/// WAV ファイル群を結合
func concatWAV(_ files: [String], to output: String) {
    let args = files.map { "'\($0)'" }.joined(separator: " ")
    shell("python3 '\(pyHelperPath)' concat \(args) '\(output)'")
}

// MARK: - Speeches

struct Speech {
    let slug: String; let locale: String; let rate: Int; let text: String
}

struct BilingualSpeech {
    let slug: String
    let sentences: [(en: String, ja: String)]
}

// ── 単言語サンプル ─────────────────────────────────────────────────────
let monoSpeeches: [Speech] = [
    Speech(
        slug: "sample_en", locale: "en_US", rate: 145,
        text: "Hello, and welcome to musica. " +
              "This is a sample track for English dictation practice. " +
              "Try to write down what you hear. " +
              "You can slow down the playback speed using the controls below. " +
              "Listening carefully to each word will help you improve your English skills. " +
              "Good luck, and enjoy your practice!"
    ),
    Speech(
        slug: "sample_ja", locale: "ja_JP", rate: 155,
        text: "こんにちは。これはmusicaのサンプル練習曲です。" +
              "ディクテーション練習を試してみましょう。" +
              "再生速度を落として、聞こえた言葉を書き取ってみてください。" +
              "繰り返し練習することで、リスニング力が上がります。" +
              "自分の好きな曲や動画を追加して、楽しく学習を続けましょう。"
    ),
]

// ── 英日交互レッスン（lesson_01〜06） ─────────────────────────────────
let bilingualSpeeches: [BilingualSpeech] = [
    BilingualSpeech(slug: "lesson_01", sentences: [
        (en: "Dictation practice is one of the most effective ways to improve your listening skills in a foreign language.",
         ja: "ディクテーション練習は、外国語のリスニング力を高める最も効果的な方法の一つです。"),
        (en: "The idea is simple.",
         ja: "考え方はシンプルです。"),
        (en: "You listen to a piece of audio, then try to write down exactly what you heard, word for word.",
         ja: "音声を聴いて、聞こえた内容を一言一句そのまま書き取ります。"),
        (en: "This forces your brain to process every sound carefully, rather than just getting a general meaning.",
         ja: "これにより、なんとなく意味をつかむのではなく、すべての音を丁寧に処理するよう脳が鍛えられます。"),
        (en: "Over time, your ears become trained to catch words you used to miss.",
         ja: "続けることで、以前は聞き取れなかった言葉も拾えるようになっていきます。"),
        (en: "Unlike passive listening, dictation is active. You are fully engaged with every sentence.",
         ja: "受動的な聞き流しとは違い、ディクテーションは能動的です。すべての文に集中して取り組みます。"),
        (en: "musica is designed to make this process easy and enjoyable.",
         ja: "musicaは、このプロセスを簡単で楽しいものにするために設計されています。"),
        (en: "You can use any audio you like, music, podcasts, or videos, as your practice material.",
         ja: "音楽・ポッドキャスト・動画など、好きな音声を練習素材として使えます。"),
        (en: "Let's get started.",
         ja: "さあ、始めましょう。"),
    ]),
    BilingualSpeech(slug: "lesson_02", sentences: [
        (en: "One of the most powerful features in musica is playback speed control.",
         ja: "musicaの最も強力な機能の一つが、再生速度のコントロールです。"),
        (en: "When you first listen to a track, try playing it at normal speed.",
         ja: "トラックを初めて聴くときは、まず通常の速度で再生してみてください。"),
        (en: "If it feels too fast, slow it down to 0.75x or 0.5x.",
         ja: "速すぎると感じたら、0.75倍や0.5倍に遅くしてみましょう。"),
        (en: "At half speed, every word becomes much clearer, and you will find it easier to write down what you hear.",
         ja: "半速にすると、すべての言葉がずっとはっきり聞こえ、書き取りやすくなります。"),
        (en: "As your listening improves, you can push yourself by increasing the speed.",
         ja: "リスニング力が上がってきたら、速度を上げて自分を追い込んでみましょう。"),
        (en: "Try 1.25x or even 1.5x. Faster audio trains your brain to process language more quickly.",
         ja: "1.25倍や1.5倍を試してみてください。速い音声は、言語をより速く処理するよう脳を鍛えます。"),
        (en: "The key is to find a speed that challenges you without overwhelming you.",
         ja: "ポイントは、無理なくチャレンジできる速度を見つけることです。"),
        (en: "Adjust, listen, write, and check. Then repeat at a slightly faster speed.",
         ja: "速度を調整して、聴いて、書いて、確認する。そして少し速くしてもう一度繰り返しましょう。"),
    ]),
    BilingualSpeech(slug: "lesson_03", sentences: [
        (en: "Adding a transcript to your audio track is one of the best ways to get the most out of your practice.",
         ja: "音声トラックにスクリプトを追加することは、練習を最大限に活かすための最善の方法の一つです。"),
        (en: "In musica, you can save lyrics or a script for any track.",
         ja: "musicaでは、どのトラックにも歌詞やスクリプトを保存できます。"),
        (en: "After you finish a dictation session, open the lyrics panel to check your answers.",
         ja: "ディクテーションが終わったら、歌詞パネルを開いて答え合わせをしましょう。"),
        (en: "Pay attention to the parts you missed or got wrong.",
         ja: "聞き取れなかった部分や間違えた箇所に注目してください。"),
        (en: "These are exactly the sounds and words you need to practice more.",
         ja: "それこそが、もっと練習が必要な音や言葉です。"),
        (en: "You can also use the lyrics panel before you listen, to preview the vocabulary, or to follow along with the text while the audio plays.",
         ja: "聴く前に歌詞パネルで語彙を予習したり、再生中にテキストを目で追ったりすることもできます。"),
        (en: "Try both approaches and see which one works best for you.",
         ja: "両方の方法を試して、自分に合ったやり方を見つけてみてください。"),
    ]),
    BilingualSpeech(slug: "lesson_04", sentences: [
        (en: "musica lets you organize your audio into music libraries.",
         ja: "musicaでは、音声を音楽ライブラリに整理して管理できます。"),
        (en: "To create a new library, tap the plus button on the home screen.",
         ja: "新しいライブラリを作るには、ホーム画面のプラスボタンをタップしてください。"),
        (en: "Give your library a name, for example, English Podcasts, or My Favorite Songs.",
         ja: "ライブラリに名前をつけましょう。例えば「英語ポッドキャスト」や「お気に入りの曲」など。"),
        (en: "Once your library is created, you can add audio files from your iPhone.",
         ja: "ライブラリを作ったら、iPhoneから音声ファイルを追加できます。"),
        (en: "musica supports a wide range of file formats, so you can use almost any audio saved on your device.",
         ja: "musicaは幅広いファイル形式に対応しているので、端末に保存されているほぼすべての音声を使えます。"),
        (en: "You can create as many libraries as you like.",
         ja: "ライブラリはいくつでも作れます。"),
        (en: "Try making separate libraries for different topics, languages, or difficulty levels.",
         ja: "テーマ別・言語別・難易度別にライブラリを分けてみましょう。"),
        (en: "Staying organized makes it easier to track your progress and stay motivated.",
         ja: "整理しておくことで、進捗を把握しやすくなり、モチベーションを維持しやすくなります。"),
    ]),
    BilingualSpeech(slug: "lesson_05", sentences: [
        (en: "Did you know you can practice dictation with YouTube videos in musica?",
         ja: "musicaではYouTube動画を使ってディクテーション練習ができることを知っていましたか？"),
        (en: "Open the favorites tab on the home screen.",
         ja: "ホーム画面のお気に入りタブを開いてください。"),
        (en: "Tap the plus button to add a YouTube video using its URL.",
         ja: "プラスボタンをタップして、URLからYouTube動画を追加しましょう。"),
        (en: "Once added, the video will appear in your favorites list.",
         ja: "追加すると、動画がお気に入りリストに表示されます。"),
        (en: "You can play the video directly inside the app, and use all of musica's features, including playback speed control.",
         ja: "アプリ内で直接動画を再生でき、再生速度コントロールを含むmusicaのすべての機能が使えます。"),
        (en: "To get the most out of video practice, try adding a transcript for the video.",
         ja: "動画練習を最大限に活かすには、動画のスクリプトを追加してみましょう。"),
        (en: "You can save it in musica and use it to check your dictation after each session.",
         ja: "musicaに保存しておけば、毎回の練習後に答え合わせに使えます。"),
        (en: "News reports, interviews, and tutorial videos are especially good for dictation practice.",
         ja: "ニュースレポート・インタビュー・チュートリアル動画は特にディクテーション練習に向いています。"),
    ]),
    BilingualSpeech(slug: "lesson_06", sentences: [
        (en: "The most important factor in improving your listening skills is consistency.",
         ja: "リスニング力を高める上で最も大切なのは、継続することです。"),
        (en: "Even ten minutes of focused dictation practice every day will produce better results than one long session once a week.",
         ja: "週に一度の長いセッションより、毎日10分間の集中したディクテーション練習の方が効果的です。"),
        (en: "Here are a few tips to help you stay consistent.",
         ja: "継続するためのヒントをいくつか紹介します。"),
        (en: "First, choose audio that you actually enjoy. If you find the content interesting, you are much more likely to practice regularly.",
         ja: "まず、本当に楽しめる音声を選んでください。内容が面白ければ、定期的に練習する可能性がずっと高まります。"),
        (en: "Second, start with shorter sections. Pause after every one or two sentences, write down what you heard, and then check.",
         ja: "次に、短い区間から始めましょう。1〜2文ごとに一時停止して、聞こえた内容を書き取り、確認します。"),
        (en: "Do not try to transcribe everything at once.",
         ja: "一度にすべてを書き取ろうとしないでください。"),
        (en: "Third, review your mistakes. Every error is a clue about which sounds or words you need to focus on.",
         ja: "そして、間違いを見直しましょう。すべてのミスは、どの音や言葉を重点的に練習すべきかを教えてくれる手がかりです。"),
        (en: "musica is here to support your journey. Keep going, your ears will thank you.",
         ja: "musicaはあなたの学習をサポートします。続けていきましょう。きっと耳が喜ぶはずです。"),
    ]),
]

// MARK: - Generate

let outDir  = FileManager.default.currentDirectoryPath
let enVoice = bestVoice(locale: "en_US")
let jaVoice = bestVoice(locale: "ja_JP")
print("🎙  英語ボイス: \(enVoice.isEmpty ? "デフォルト" : enVoice)")
print("🎙  日本語ボイス: \(jaVoice.isEmpty ? "デフォルト" : jaVoice)\n")

writePythonHelper()

let sil500 = genSilence(ms: 500)
let sil800 = genSilence(ms: 800)

// ── 単言語トラック ────────────────────────────────────────────────────
for s in monoSpeeches {
    let cafPath  = "\(outDir)/\(s.slug).caf"
    let aiffPath = "/tmp/\(s.slug)_tmp.aiff"
    try? FileManager.default.removeItem(atPath: cafPath)
    try? FileManager.default.removeItem(atPath: aiffPath)

    let voice    = bestVoice(locale: s.locale)
    let escaped  = s.text.replacingOccurrences(of: "'", with: #"'\''"#)
    let voiceArg = voice.isEmpty ? "" : "-v '\(voice)'"
    let sayResult = shell("say \(voiceArg) --rate=\(s.rate) -o '\(aiffPath)' '\(escaped)'")
    guard sayResult.code == 0 else { print("❌  [\(s.slug)] say 失敗\n"); continue }

    let afResult = shell("afconvert '\(aiffPath)' '\(cafPath)' -d LEI16@44100 -f caff")
    try? FileManager.default.removeItem(atPath: aiffPath)
    if afResult.code == 0 {
        let sz = (try? FileManager.default.attributesOfItem(atPath: cafPath)[.size] as? Int) ?? 0
        print("✅  \(s.slug).caf  (\(sz / 1024) KB)\n")
    } else { print("❌  [\(s.slug)] afconvert 失敗\n") }
}

// ── 英日交互レッスン ──────────────────────────────────────────────────
let enVoiceArg = enVoice.isEmpty ? "" : "-v '\(enVoice)'"
let jaVoiceArg = jaVoice.isEmpty ? "" : "-v '\(jaVoice)'"

for s in bilingualSpeeches {
    print("🎙  [\(s.slug)] 英日交互 \(s.sentences.count) 文ペア...")

    var wavSegments: [String] = []
    var tempFiles:   [String] = []

    for (i, pair) in s.sentences.enumerated() {
        // ── 英語 ──
        let enAiff = "/tmp/musica_\(s.slug)_\(i)_en.aiff"
        let enWav  = "/tmp/musica_\(s.slug)_\(i)_en.wav"
        let enText = pair.en.replacingOccurrences(of: "'", with: #"'\''"#)
        if shell("say \(enVoiceArg) --rate=145 -o '\(enAiff)' '\(enText)'").code == 0,
           aiff2wav(enAiff, enWav) {
            wavSegments.append(enWav)
            tempFiles += [enAiff, enWav]
        } else {
            print("   ⚠️  EN[\(i)] 生成失敗")
            if FileManager.default.fileExists(atPath: enAiff) { tempFiles.append(enAiff) }
        }
        wavSegments.append(sil500)

        // ── 日本語 ──
        let jaAiff = "/tmp/musica_\(s.slug)_\(i)_ja.aiff"
        let jaWav  = "/tmp/musica_\(s.slug)_\(i)_ja.wav"
        let jaText = pair.ja.replacingOccurrences(of: "'", with: #"'\''"#)
        if shell("say \(jaVoiceArg) --rate=155 -o '\(jaAiff)' '\(jaText)'").code == 0,
           aiff2wav(jaAiff, jaWav) {
            wavSegments.append(jaWav)
            tempFiles += [jaAiff, jaWav]
        } else {
            print("   ⚠️  JA[\(i)] 生成失敗")
            if FileManager.default.fileExists(atPath: jaAiff) { tempFiles.append(jaAiff) }
        }
        wavSegments.append(sil800)
    }

    // WAV 結合 → CAF 変換
    let concatWav = "/tmp/musica_\(s.slug)_concat.wav"
    concatWAV(wavSegments, to: concatWav)
    tempFiles.append(concatWav)

    let cafPath = "\(outDir)/\(s.slug).caf"
    try? FileManager.default.removeItem(atPath: cafPath)
    let afResult = shell("afconvert '\(concatWav)' '\(cafPath)' -d LEI16@44100 -f caff")

    for f in tempFiles { try? FileManager.default.removeItem(atPath: f) }

    if afResult.code == 0 {
        let sz = (try? FileManager.default.attributesOfItem(atPath: cafPath)[.size] as? Int) ?? 0
        print("✅  \(s.slug).caf  (\(sz / 1024) KB)\n")
    } else {
        print("❌  [\(s.slug)] afconvert 失敗\n")
    }
}

print("完了！生成された .caf を musica/musica/ に上書きしてください。")
