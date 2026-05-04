//
//  SampleDataSeeder.swift
//  musica
//
//  初回起動・アップデート時にサンプルデータを投入するシーダー。
//  ・お気に入り動画 : YouTube サンプル動画を先頭に登録（動画ごとに独立フラグで管理）
//  ・音楽ライブラリ : バンドル済み音声ファイル（sample_en.caf / sample_ja.caf）を
//                    お気に入り動画 の直後に登録
//
//  【サンプル動画の追加方法】
//  　sampleMVDefinitions 配列に新しいエントリを追加してください。
//  　各動画は独立した UserDefaults フラグで管理されます:
//  　  "yt_sample_seeded_{videoID}" … 登録済みフラグ
//  　  "yt_sample_deleted_{videoID}" … ユーザーが明示的に削除したフラグ
//  　削除されていない限り、アップデート時にも自動で追加されます。
//
//  【ユーザーが動画を削除した時】
//  　PlayMVListViewController.deleteBtnTapped から
//  　SampleDataSeeder.markMVDeleted(videoID:) を呼ぶと、以降は再登録されません。
//
//  【音声ファイルの更新手順】
//  　プロジェクト直上の GenerateSampleAudio.swift を実行して .caf を再生成し、
//  　Xcode プロジェクト内の sample_en.caf / sample_ja.caf を差し替えてください。
//

import Foundation
import CoreData
import UIKit
import AVFoundation

enum SampleDataSeeder {

    // ── 定数 ──────────────────────────────────────────────────────────
    static let sampleLibraryName     = "📖 使い方ガイド＆練習曲"
    private static let seededKey        = "sampleDataSeeded_v1"
    private static let lessonSeeded     = "sampleLessonsSeeded_v4"  // 音声ファイルを強制上書き更新
    private static let orderFixKey      = "sampleOrderFixed_v2"
    private static let captionUpdated   = "yt_caption_bilingual_v1" // 動画キャプション英日対訳更新

    // ── サンプル動画定義（新しい動画はここに追加するだけ） ─────────────
    //  各動画は独立フラグで管理されるため、過去動画を削除してもフラグは残る
    private struct MVDef {
        let id: String; let title: String; let time: String; let caption: String
        var seededKey:  String { "yt_sample_seeded_\(id)" }
        var deletedKey: String { "yt_sample_deleted_\(id)" }
    }
    private static let sampleMVDefinitions: [MVDef] = [
        MVDef(
            id:    "R-t27Vpwqcs",
            title: "How to Use musica — Listening & Dictation Practice App (サンプル)",
            time:  "1:00",
            caption:
                "Welcome to musica — the app designed to help you improve your listening skills through dictation practice.\n" +
                "musicaへようこそ。ディクテーション練習を通じてリスニング力を高めるアプリです。\n\n" +
                "Here's how it works.\n" +
                "使い方を説明します。\n\n" +
                "First, add your favorite songs or audio tracks to a music library.\n" +
                "まず、好きな曲や音声トラックを音楽ライブラリに追加してください。\n\n" +
                "You can import audio files directly from your iPhone, or add YouTube videos to your favorites list.\n" +
                "iPhoneから音声ファイルを直接インポートするか、YouTubeの動画をお気に入りリストに追加できます。\n\n" +
                "Once your track is loaded, you can adjust the playback speed to match your level.\n" +
                "トラックを読み込んだら、自分のレベルに合わせて再生速度を調整できます。\n\n" +
                "Slow it down to half speed to catch every word, or speed it up to challenge yourself with faster listening.\n" +
                "半速まで遅くして一語一語を聞き取ったり、速度を上げてより速いリスニングに挑戦したりできます。\n\n" +
                "To practice dictation, simply listen to a section, pause, and try to write down what you heard.\n" +
                "ディクテーション練習をするには、区間を聴いて一時停止し、聞こえた内容を書き取ってみてください。\n\n" +
                "Then replay it to check.\n" +
                "その後、再生して答え合わせをしましょう。\n\n" +
                "You can also add lyrics or a transcript to any track.\n" +
                "どのトラックにも歌詞やスクリプトを追加できます。\n\n" +
                "This helps you follow along, verify your answers, and study the text at your own pace.\n" +
                "音声に合わせてテキストを確認したり、答え合わせをしたり、自分のペースで学習したりするのに役立ちます。\n\n" +
                "The more you repeat, the more your ears will train to pick up natural speech — in any language.\n" +
                "繰り返せば繰り返すほど、あらゆる言語の自然な発話を聞き取る耳が鍛えられていきます。\n\n" +
                "Start with the sample tracks included in the app, then add your own music, podcasts, or any audio you want to master.\n" +
                "アプリのサンプルトラックから始めて、自分の音楽・ポッドキャスト・習得したい音声を追加しましょう。\n\n" +
                "musica turns your favorite content into your personal listening classroom.\n" +
                "musicaはあなたのお気に入りコンテンツを、あなただけのリスニング教室に変えます。\n\n" +
                "Happy practicing!\n" +
                "楽しく練習しましょう！"
        ),
    ]

    // ── ユーザーがサンプル動画を明示的に削除した時に呼ぶ ────────────────
    static func markMVDeleted(videoID: String) {
        guard sampleMVDefinitions.contains(where: { $0.id == videoID }) else { return }
        UserDefaults.standard.set(true, forKey: "yt_sample_deleted_\(videoID)")
        dlog("[SampleSeeder] サンプル動画を削除済みとしてマーク: \(videoID)")
    }

    // ── エントリポイント（同期・メインスレッド可） ─────────────────────
    static func seedIfNeeded(appDelegate: AppDelegate) {
        let ctx = appDelegate.managedObjectContext

        // ① trackNum のズレは毎回修正
        fixMVTrackNumIfNeeded(context: ctx)

        // ② 表示順を正規化（一回のみ）
        fixOrderIfNeeded(context: ctx)

        // ③ サンプル動画を動画ごとに独立して登録（毎起動チェック）
        seedSampleMVsIfNeeded(context: ctx)

        // ④ 動画キャプションを英日対訳に更新（既存ユーザー含む・一回のみ）
        updateCaptionsIfNeeded()

        // ⑤ 6レッスントラックを追加（既存ユーザー含む・一回のみ）
        seedLessonsIfNeeded(context: ctx)

        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }

        // ⑤ バンドルから音声ファイルをコピーして CoreData に書き込む（初回のみ）
        let tracks = buildSampleTracks()
        seedMusicLibraryWith(tracks, context: ctx)
        UserDefaults.standard.set(true, forKey: seededKey)
        dlog("[SampleSeeder] サンプルデータを登録しました（\(tracks.count) 曲）")
    }

    // ── ① trackNum 修正 ────────────────────────────────────────────────
    private static func fixMVTrackNumIfNeeded(context: NSManagedObjectContext) {
        let mvListName = localText(key: "home_okiniiri")

        let mvReq: NSFetchRequest<MVModel> = MVModel.fetchRequest()
        mvReq.predicate = NSPredicate(format: "musicLibraryName = %@", mvListName)
        let actual = (try? context.fetch(mvReq))?.count ?? 0

        let libReq: NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        libReq.predicate = NSPredicate(format: "musicLibraryName = %@", mvListName)
        guard let lib = (try? context.fetch(libReq))?.first,
              lib.trackNum != Int16(actual) else { return }

        lib.trackNum = Int16(actual)
        try? context.save()
    }

    // ── ② 表示順の正規化（一回のみ・v2 で既存端末にも適用） ─────────────
    //  正規化後の並び: 0=お気に入り動画  1=サンプル練習曲  2以降=ユーザーライブラリ
    private static func fixOrderIfNeeded(context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: orderFixKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: orderFixKey) }

        let mvListName = localText(key: "home_okiniiri")
        let allReq: NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        guard let all = try? context.fetch(allReq), !all.isEmpty else { return }

        // ピン留めライブラリを抽出
        let mvLib     = all.first { $0.musicLibraryName == mvListName }
        let sampleLib = all.first { $0.musicLibraryName == sampleLibraryName }

        // それ以外をソート（既存の indicatoryNum 順を維持）
        let others = all
            .filter { $0.musicLibraryName != mvListName && $0.musicLibraryName != sampleLibraryName }
            .sorted { $0.indicatoryNum < $1.indicatoryNum }

        // 番号を振り直す
        mvLib?.indicatoryNum     = 0
        sampleLib?.indicatoryNum = 1
        for (i, lib) in others.enumerated() { lib.indicatoryNum = Int16(i + 2) }

        try? context.save()
        dlog("[SampleSeeder] 表示順を正規化しました（MV=0, sample=1, others \(others.count) 件）")
    }

    // ── 動画キャプションを英日対訳に上書き更新（一回のみ） ──────────────
    private static func updateCaptionsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: captionUpdated) else { return }
        for def in sampleMVDefinitions where !def.caption.isEmpty {
            YoutubeCaptionStore.save(def.caption, for: def.id)
        }
        UserDefaults.standard.set(true, forKey: captionUpdated)
        dlog("[SampleSeeder] 動画キャプションを英日対訳に更新しました")
    }

    // ── サンプル動画を動画ごとに独立して登録（毎起動チェック） ──────────
    //  登録済み or ユーザーが削除済み → スキップ
    //  未登録 → お気に入りリストの先頭(indicatoryNum=0)に挿入
    private static func seedSampleMVsIfNeeded(context: NSManagedObjectContext) {
        let mvListName = localText(key: "home_okiniiri")

        for def in sampleMVDefinitions {
            // 削除済みならスキップ
            if UserDefaults.standard.bool(forKey: def.deletedKey) { continue }
            // 登録済みならスキップ
            if UserDefaults.standard.bool(forKey: def.seededKey)  { continue }

            // CoreData に既に存在するか確認（念のため）
            let dupReq: NSFetchRequest<MVModel> = MVModel.fetchRequest()
            dupReq.predicate = NSPredicate(format: "musicLibraryName = %@ AND videoID = %@",
                                           mvListName, def.id)
            if (try? context.fetch(dupReq))?.isEmpty == false {
                UserDefaults.standard.set(true, forKey: def.seededKey)
                continue
            }

            // 既存の全動画を +1 シフトして先頭に挿入
            let allReq: NSFetchRequest<MVModel> = MVModel.fetchRequest()
            allReq.predicate = NSPredicate(format: "musicLibraryName = %@", mvListName)
            let existing = (try? context.fetch(allReq)) ?? []
            for mv in existing { mv.indicatoryNum += 1 }

            let entity = NSEntityDescription.entity(forEntityName: "MVModel", in: context)!
            let m = NSManagedObject(entity: entity, insertInto: context) as! MVModel
            m.videoID          = def.id
            m.videoTitle       = def.title
            m.thumbnailUrl     = "https://i.ytimg.com/vi/\(def.id)/hqdefault.jpg"
            m.videoTime        = def.time
            m.musicLibraryName = mvListName
            m.indicatoryNum    = 0

            if !def.caption.isEmpty {
                YoutubeCaptionStore.save(def.caption, for: def.id)
            }
            try? context.save()

            // trackNum を実件数に同期
            let totalReq: NSFetchRequest<MVModel> = MVModel.fetchRequest()
            totalReq.predicate = NSPredicate(format: "musicLibraryName = %@", mvListName)
            let total = (try? context.fetch(totalReq))?.count ?? 0
            let libReq: NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
            libReq.predicate = NSPredicate(format: "musicLibraryName = %@", mvListName)
            if let lib = (try? context.fetch(libReq))?.first {
                lib.trackNum = Int16(total)
                try? context.save()
            }

            UserDefaults.standard.set(true, forKey: def.seededKey)
            dlog("[SampleSeeder] サンプル動画を登録しました: \(def.id)")
        }
    }

    // ── 音楽ライブラリのシード ────────────────────────────────────────
    private static func seedMusicLibraryWith(_ tracks: [TrackData],
                                              context: NSManagedObjectContext) {
        guard !tracks.isEmpty else { return }

        let dupReq: NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        dupReq.predicate = NSPredicate(format: "musicLibraryName = %@", sampleLibraryName)
        guard (try? context.fetch(dupReq))?.isEmpty == true else { return }

        // pos >= 1 の既存ライブラリを後ろへ
        let allReq: NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        for lib in (try? context.fetch(allReq)) ?? [] where lib.indicatoryNum >= 1 {
            lib.indicatoryNum += 1
        }

        let libEntity = NSEntityDescription.entity(forEntityName: "MusicLibraryModel", in: context)!
        let lib = NSManagedObject(entity: libEntity, insertInto: context) as! MusicLibraryModel
        lib.musicLibraryName = sampleLibraryName
        lib.trackNum         = Int16(tracks.count)
        lib.creationDate     = Date()
        lib.iconName         = "onpu_BL"
        lib.icomColorName    = colorChoicesNameArray[0]
        lib.indicatoryNum    = 1

        for (i, t) in tracks.enumerated() {
            let te = NSEntityDescription.entity(forEntityName: "MusicModel", in: context)!
            let m  = NSManagedObject(entity: te, insertInto: context) as! MusicModel
            m.musicLibraryName = sampleLibraryName
            m.trackTitle       = t.title
            m.artist           = t.artist
            m.albumTitle       = t.albumName
            m.lyric            = t.lyric
            m.url              = String(describing: t.url!)
            m.indicatoryNum    = Int16(i)
            if let img = t.artworkImg, let png = img.pngData() { m.artworkData = png }
        }
        try? context.save()
    }

    // ── 6レッスンのシード（既存ユーザー含む・一回のみ） ─────────────────
    private static func seedLessonsIfNeeded(context: NSManagedObjectContext) {
        guard !UserDefaults.standard.bool(forKey: lessonSeeded) else { return }
        defer { UserDefaults.standard.set(true, forKey: lessonSeeded) }

        // 既存のレッスン音声ファイルを削除してバンドルから再コピーさせる
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for slug in ["lesson_01", "lesson_02", "lesson_03", "lesson_04", "lesson_05", "lesson_06"] {
            let fileURL = docs.appendingPathComponent("\(slug).caf")
            try? FileManager.default.removeItem(at: fileURL)
        }

        let lessons = buildLessonTracks()
        guard !lessons.isEmpty else { return }

        // ライブラリが既に存在するか確認
        let libReq: NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
        libReq.predicate = NSPredicate(format: "musicLibraryName = %@", sampleLibraryName)

        if let lib = (try? context.fetch(libReq))?.first {
            // 既存ライブラリ: MusicModel を全削除して入れ直す
            let oldReq: NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
            oldReq.predicate = NSPredicate(format: "musicLibraryName = %@", sampleLibraryName)
            for m in (try? context.fetch(oldReq)) ?? [] { context.delete(m) }

            for (i, t) in lessons.enumerated() {
                let te = NSEntityDescription.entity(forEntityName: "MusicModel", in: context)!
                let m  = NSManagedObject(entity: te, insertInto: context) as! MusicModel
                m.musicLibraryName = sampleLibraryName
                m.trackTitle       = t.title
                m.artist           = t.artist
                m.albumTitle       = t.albumName
                m.lyric            = t.lyric
                m.url              = String(describing: t.url!)
                m.indicatoryNum    = Int16(i)
                if let img = t.artworkImg, let png = img.pngData() { m.artworkData = png }
            }
            lib.trackNum = Int16(lessons.count)
            try? context.save()
        } else {
            // 新規ライブラリとして挿入（indicatoryNum=1、他を後ろへ）
            let allReq: NSFetchRequest<MusicLibraryModel> = MusicLibraryModel.fetchRequest()
            for lib in (try? context.fetch(allReq)) ?? [] where lib.indicatoryNum >= 1 {
                lib.indicatoryNum += 1
            }
            let libEntity = NSEntityDescription.entity(forEntityName: "MusicLibraryModel", in: context)!
            let lib = NSManagedObject(entity: libEntity, insertInto: context) as! MusicLibraryModel
            lib.musicLibraryName = sampleLibraryName
            lib.trackNum         = Int16(lessons.count)
            lib.creationDate     = Date()
            lib.iconName         = "onpu_BL"
            lib.icomColorName    = colorChoicesNameArray[0]
            lib.indicatoryNum    = 1

            for (i, t) in lessons.enumerated() {
                let te = NSEntityDescription.entity(forEntityName: "MusicModel", in: context)!
                let m  = NSManagedObject(entity: te, insertInto: context) as! MusicModel
                m.musicLibraryName = sampleLibraryName
                m.trackTitle       = t.title
                m.artist           = t.artist
                m.albumTitle       = t.albumName
                m.lyric            = t.lyric
                m.url              = String(describing: t.url!)
                m.indicatoryNum    = Int16(i)
                if let img = t.artworkImg, let png = img.pngData() { m.artworkData = png }
            }
            try? context.save()
        }
        dlog("[SampleSeeder] 6レッスントラックを登録しました")
    }

    // ── 6レッスントラック定義 ────────────────────────────────────────────
    private static func buildLessonTracks() -> [TrackData] {
        let defs: [(slug: String, title: String, lyric: String)] = [
            (
                slug:  "lesson_01",
                title: "Lesson 1 — ディクテーションとは？",
                lyric:
                    "Dictation practice is one of the most effective ways to improve your listening skills in a foreign language.\n" +
                    "ディクテーション練習は、外国語のリスニング力を高める最も効果的な方法の一つです。\n\n" +
                    "The idea is simple.\n" +
                    "考え方はシンプルです。\n\n" +
                    "You listen to a piece of audio, then try to write down exactly what you heard — word for word.\n" +
                    "音声を聴いて、聞こえた内容を一言一句そのまま書き取ります。\n\n" +
                    "This forces your brain to process every sound carefully, rather than just getting a general meaning.\n" +
                    "これにより、なんとなく意味をつかむのではなく、すべての音を丁寧に処理するよう脳が鍛えられます。\n\n" +
                    "Over time, your ears become trained to catch words you used to miss.\n" +
                    "続けることで、以前は聞き取れなかった言葉も拾えるようになっていきます。\n\n" +
                    "Unlike passive listening, dictation is active. You are fully engaged with every sentence.\n" +
                    "受動的な聞き流しとは違い、ディクテーションは能動的です。すべての文に集中して取り組みます。\n\n" +
                    "musica is designed to make this process easy and enjoyable.\n" +
                    "musicaは、このプロセスを簡単で楽しいものにするために設計されています。\n\n" +
                    "You can use any audio you like — music, podcasts, or videos — as your practice material.\n" +
                    "音楽・ポッドキャスト・動画など、好きな音声を練習素材として使えます。\n\n" +
                    "Let's get started.\n" +
                    "さあ、始めましょう。"
            ),
            (
                slug:  "lesson_02",
                title: "Lesson 2 — 再生速度を使いこなす",
                lyric:
                    "One of the most powerful features in musica is playback speed control.\n" +
                    "musicaの最も強力な機能の一つが、再生速度のコントロールです。\n\n" +
                    "When you first listen to a track, try playing it at normal speed.\n" +
                    "トラックを初めて聴くときは、まず通常の速度で再生してみてください。\n\n" +
                    "If it feels too fast, slow it down to 0.75x or 0.5x.\n" +
                    "速すぎると感じたら、0.75倍や0.5倍に遅くしてみましょう。\n\n" +
                    "At half speed, every word becomes much clearer, and you will find it easier to write down what you hear.\n" +
                    "半速にすると、すべての言葉がずっとはっきり聞こえ、書き取りやすくなります。\n\n" +
                    "As your listening improves, you can push yourself by increasing the speed.\n" +
                    "リスニング力が上がってきたら、速度を上げて自分を追い込んでみましょう。\n\n" +
                    "Try 1.25x or even 1.5x. Faster audio trains your brain to process language more quickly.\n" +
                    "1.25倍や1.5倍を試してみてください。速い音声は、言語をより速く処理するよう脳を鍛えます。\n\n" +
                    "The key is to find a speed that challenges you without overwhelming you.\n" +
                    "ポイントは、無理なくチャレンジできる速度を見つけることです。\n\n" +
                    "Adjust, listen, write, and check. Then repeat at a slightly faster speed.\n" +
                    "速度を調整して、聴いて、書いて、確認する。そして少し速くしてもう一度繰り返しましょう。"
            ),
            (
                slug:  "lesson_03",
                title: "Lesson 3 — 字幕・歌詞の活用法",
                lyric:
                    "Adding a transcript to your audio track is one of the best ways to get the most out of your practice.\n" +
                    "音声トラックにスクリプトを追加することは、練習を最大限に活かすための最善の方法の一つです。\n\n" +
                    "In musica, you can save lyrics or a script for any track.\n" +
                    "musicaでは、どのトラックにも歌詞やスクリプトを保存できます。\n\n" +
                    "After you finish a dictation session, open the lyrics panel to check your answers.\n" +
                    "ディクテーションが終わったら、歌詞パネルを開いて答え合わせをしましょう。\n\n" +
                    "Pay attention to the parts you missed or got wrong.\n" +
                    "聞き取れなかった部分や間違えた箇所に注目してください。\n\n" +
                    "These are exactly the sounds and words you need to practice more.\n" +
                    "それこそが、もっと練習が必要な音や言葉です。\n\n" +
                    "You can also use the lyrics panel before you listen — to preview the vocabulary, or to follow along with the text while the audio plays.\n" +
                    "聴く前に歌詞パネルで語彙を予習したり、再生中にテキストを目で追ったりすることもできます。\n\n" +
                    "Try both approaches and see which one works best for you.\n" +
                    "両方の方法を試して、自分に合ったやり方を見つけてみてください。"
            ),
            (
                slug:  "lesson_04",
                title: "Lesson 4 — ライブラリの作り方",
                lyric:
                    "musica lets you organize your audio into music libraries.\n" +
                    "musicaでは、音声を音楽ライブラリに整理して管理できます。\n\n" +
                    "To create a new library, tap the plus button on the home screen.\n" +
                    "新しいライブラリを作るには、ホーム画面のプラスボタンをタップしてください。\n\n" +
                    "Give your library a name — for example, English Podcasts, or My Favorite Songs.\n" +
                    "ライブラリに名前をつけましょう。例えば「英語ポッドキャスト」や「お気に入りの曲」など。\n\n" +
                    "Once your library is created, you can add audio files from your iPhone.\n" +
                    "ライブラリを作ったら、iPhoneから音声ファイルを追加できます。\n\n" +
                    "musica supports a wide range of file formats, so you can use almost any audio saved on your device.\n" +
                    "musicaは幅広いファイル形式に対応しているので、端末に保存されているほぼすべての音声を使えます。\n\n" +
                    "You can create as many libraries as you like.\n" +
                    "ライブラリはいくつでも作れます。\n\n" +
                    "Try making separate libraries for different topics, languages, or difficulty levels.\n" +
                    "テーマ別・言語別・難易度別にライブラリを分けてみましょう。\n\n" +
                    "Staying organized makes it easier to track your progress and stay motivated.\n" +
                    "整理しておくことで、進捗を把握しやすくなり、モチベーションを維持しやすくなります。"
            ),
            (
                slug:  "lesson_05",
                title: "Lesson 5 — YouTube動画で練習",
                lyric:
                    "Did you know you can practice dictation with YouTube videos in musica?\n" +
                    "musicaではYouTube動画を使ってディクテーション練習ができることを知っていましたか？\n\n" +
                    "Open the favorites tab on the home screen.\n" +
                    "ホーム画面のお気に入りタブを開いてください。\n\n" +
                    "Tap the plus button to add a YouTube video using its URL.\n" +
                    "プラスボタンをタップして、URLからYouTube動画を追加しましょう。\n\n" +
                    "Once added, the video will appear in your favorites list.\n" +
                    "追加すると、動画がお気に入りリストに表示されます。\n\n" +
                    "You can play the video directly inside the app, and use all of musica's features — including playback speed control.\n" +
                    "アプリ内で直接動画を再生でき、再生速度コントロールを含むmusicaのすべての機能が使えます。\n\n" +
                    "To get the most out of video practice, try adding a transcript for the video.\n" +
                    "動画練習を最大限に活かすには、動画のスクリプトを追加してみましょう。\n\n" +
                    "You can save it in musica and use it to check your dictation after each session.\n" +
                    "musicaに保存しておけば、毎回の練習後に答え合わせに使えます。\n\n" +
                    "News reports, interviews, and tutorial videos are especially good for dictation practice.\n" +
                    "ニュースレポート・インタビュー・チュートリアル動画は特にディクテーション練習に向いています。"
            ),
            (
                slug:  "lesson_06",
                title: "Lesson 6 — 毎日続けるコツ",
                lyric:
                    "The most important factor in improving your listening skills is consistency.\n" +
                    "リスニング力を高める上で最も大切なのは、継続することです。\n\n" +
                    "Even ten minutes of focused dictation practice every day will produce better results than one long session once a week.\n" +
                    "週に一度の長いセッションより、毎日10分間の集中したディクテーション練習の方が効果的です。\n\n" +
                    "Here are a few tips to help you stay consistent.\n" +
                    "継続するためのヒントをいくつか紹介します。\n\n" +
                    "First, choose audio that you actually enjoy. If you find the content interesting, you are much more likely to practice regularly.\n" +
                    "まず、本当に楽しめる音声を選んでください。内容が面白ければ、定期的に練習する可能性がずっと高まります。\n\n" +
                    "Second, start with shorter sections. Pause after every one or two sentences, write down what you heard, and then check.\n" +
                    "次に、短い区間から始めましょう。1〜2文ごとに一時停止して、聞こえた内容を書き取り、確認します。\n\n" +
                    "Do not try to transcribe everything at once.\n" +
                    "一度にすべてを書き取ろうとしないでください。\n\n" +
                    "Third, review your mistakes. Every error is a clue about which sounds or words you need to focus on.\n" +
                    "そして、間違いを見直しましょう。すべてのミスは、どの音や言葉を重点的に練習すべきかを教えてくれる手がかりです。\n\n" +
                    "musica is here to support your journey. Keep going — your ears will thank you.\n" +
                    "musicaはあなたの学習をサポートします。続けていきましょう。きっと耳が喜ぶはずです。"
            ),
        ]
        return defs.compactMap { d in
            guard let url = copyBundleAudio(slug: d.slug) else { return nil }
            var t         = TrackData()
            t.title       = d.title
            t.artist      = "musica 使い方ガイド"
            t.albumName   = sampleLibraryName
            t.url         = url
            t.lyric       = d.lyric
            t.artworkImg  = makeArtwork()
            t.existFlg    = true
            t.isCloudItem = false
            return t
        }
    }

    // ── TrackData 定義（バンドルから音声をコピー・初回のみ） ────────────
    private static func buildSampleTracks() -> [TrackData] {
        let defs: [(slug: String, title: String, lyric: String)] = [
            (
                slug:  "sample_en",
                title: "練習曲A — 英語ディクテーション",
                lyric:
                    "Hello, and welcome to musica.\n" +
                    "This is a sample track for English dictation practice.\n" +
                    "Try to write down what you hear.\n" +
                    "You can slow down the playback speed using the controls below.\n" +
                    "Listening carefully to each word will help you improve your English skills.\n" +
                    "Good luck, and enjoy your practice!"
            ),
            (
                slug:  "sample_ja",
                title: "練習曲B — 日本語リスニング",
                lyric:
                    "こんにちは。これはmusicaのサンプル練習曲です。\n" +
                    "ディクテーション練習を試してみましょう。\n" +
                    "再生速度を落として、聞こえた言葉を書き取ってみてください。\n" +
                    "繰り返し練習することで、リスニング力が上がります。\n" +
                    "自分の好きな曲や動画を追加して、楽しく学習を続けましょう。"
            ),
        ]

        return defs.compactMap { d in
            guard let url = copyBundleAudio(slug: d.slug) else { return nil }
            var t         = TrackData()
            t.title       = d.title
            t.artist      = "musica サンプル"
            t.albumName   = sampleLibraryName
            t.url         = url
            t.lyric       = d.lyric
            t.artworkImg  = makeArtwork()
            t.existFlg    = true
            t.isCloudItem = false
            return t
        }
    }

    /// バンドル内の .caf を Documents にコピーして URL を返す
    private static func copyBundleAudio(slug: String) -> URL? {
        let docs    = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docs.appendingPathComponent("\(slug).caf")

        // すでにコピー済み
        if FileManager.default.fileExists(atPath: destURL.path) { return destURL }

        // バンドルから探してコピー
        guard let src = Bundle.main.url(forResource: slug, withExtension: "caf") else {
            dlog("[SampleSeeder] バンドルに \(slug).caf が見つかりません")
            return nil
        }
        do {
            try FileManager.default.copyItem(at: src, to: destURL)
            return destURL
        } catch {
            dlog("[SampleSeeder] コピー失敗: \(error.localizedDescription)")
            return nil
        }
    }

    // ── アートワーク生成 ──────────────────────────────────────────────
    private static func makeArtwork() -> UIImage {
        let size = CGSize(width: 300, height: 300)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let g = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [AppColor.accent.withAlphaComponent(0.85).cgColor,
                         UIColor(hex: "#9B5CF0").cgColor] as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 90),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            ]
            let s  = "🎵" as NSString
            let ss = s.size(withAttributes: attrs)
            s.draw(at: CGPoint(x: (size.width - ss.width) / 2,
                               y: (size.height - ss.height) / 2),
                   withAttributes: attrs)
        }
    }
}
