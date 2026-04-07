//
//  DemoDataSeeder.swift
//  musica
//
//  シミュレータ専用デモデータシーダー
//
//  【概要】
//  シミュレータには音楽ライブラリが存在しないため、コア再生機能のテストができない。
//  このファイルはシミュレータ起動時に自動でデモ用音声ファイル（サイン波）を生成し、
//  CoreData にデモライブラリとして登録する。
//
//  【動作条件】
//  - #if targetEnvironment(simulator) で実機では一切実行されない
//  - CoreData にライブラリが 0 件の時だけシードする（2 回目以降は何もしない）
//  - UserDefaults の "demoSeeded" フラグで多重登録を防ぐ
//
//  【使い方】
//  AppDelegate.application(_:didFinishLaunchingWithOptions:) の末尾で
//    DemoDataSeeder.seedIfNeeded(appDelegate: self)
//  を呼ぶだけ。
//

import Foundation
import AVFoundation
import CoreData
import UIKit

enum DemoDataSeeder {

    // MARK: - Public Entry Point

    static func seedIfNeeded(appDelegate: AppDelegate) {
        #if targetEnvironment(simulator)
        // すでにシード済みなら何もしない
        guard !UserDefaults.standard.bool(forKey: "demoSeeded") else { return }
        // CoreData に既存ライブラリがあれば何もしない
        guard getNowMusicLibraryData().isEmpty else { return }

        print("[DemoSeeder] シミュレータ用デモデータを生成します...")

        let tracks = generateDemoTracks()
        guard !tracks.isEmpty else {
            print("[DemoSeeder] 音声ファイルの生成に失敗しました")
            return
        }

        registNewMusicLibrary(
            appdelegate: appDelegate,
            libraryName: "🎵 デモライブラリ",
            trackList: tracks
        ) { success in
            if success {
                UserDefaults.standard.set(true, forKey: "demoSeeded")
                print("[DemoSeeder] デモライブラリを登録しました（\(tracks.count) 曲）")
                // HomeAreaViewController へ更新通知
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .init("DemoSeederDidFinish"), object: nil)
                }
            } else {
                print("[DemoSeeder] CoreData への登録に失敗しました")
            }
        }
        #endif
    }

    // MARK: - Audio Generation

    /// デモ用トラック一覧を生成（音声ファイルを Documents に保存し TrackData を返す）
    private static func generateDemoTracks() -> [TrackData] {
        let demos: [(title: String, artist: String, album: String, hz: Double, duration: Double, lyric: String)] = [
            (
                title:    "Demo Song A",
                artist:   "musica Demo",
                album:    "Demo Album",
                hz:       440.0,   // A4
                duration: 30.0,
                lyric:    "これはデモ用の楽曲です。\n\nシミュレータでのテスト用に自動生成されました。\n再生・速度変更・リピートなどの機能を試してみてください。"
            ),
            (
                title:    "Demo Song B",
                artist:   "musica Demo",
                album:    "Demo Album",
                hz:       523.25,  // C5
                duration: 20.0,
                lyric:    "Demo Song B\n\nシャッフル機能のテストに使えます。"
            ),
            (
                title:    "Demo Song C",
                artist:   "musica Demo",
                album:    "Demo Album",
                hz:       659.25,  // E5
                duration: 15.0,
                lyric:    "Demo Song C\n\n区間リピート機能もお試しください。"
            ),
            (
                title:    "Demo Song D",
                artist:   "musica Demo",
                album:    "Demo Album",
                hz:       349.23,  // F4
                duration: 25.0,
                lyric:    "Demo Song D\n\n歌詞の表示・編集機能のサンプルテキストです。"
            ),
        ]

        var tracks: [TrackData] = []
        for (i, demo) in demos.enumerated() {
            guard let url = generateSineWaveFile(
                filename:  "demo_track_\(i)",
                frequency: demo.hz,
                duration:  demo.duration
            ) else { continue }

            var track          = TrackData()
            track.title        = demo.title
            track.artist       = demo.artist
            track.albumName    = demo.album
            track.url          = url
            track.lyric        = demo.lyric
            track.artworkImg   = makeDemoArtwork(index: i)
            track.existFlg     = true
            track.isCloudItem  = false
            tracks.append(track)
        }
        return tracks
    }

    // MARK: - Sine Wave File Generator

    /// サイン波 CAF ファイルを Documents に生成して URL を返す
    private static func generateSineWaveFile(
        filename:  String,
        frequency: Double,
        duration:  Double
    ) -> URL? {
        let docs       = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL  = docs.appendingPathComponent("\(filename).caf")

        // すでに生成済みならそのまま返す
        if FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        let sampleRate: Double        = 44100
        let channels: AVAudioChannelCount = 2
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channels
        ) else { return nil }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        // サイン波 + フェードイン/アウト（クリックノイズ防止）
        let fadeFrames = Int(sampleRate * 0.02)  // 20ms
        for ch in 0..<Int(channels) {
            guard let data = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<Int(frameCount) {
                let t         = Double(i) / sampleRate
                var amplitude = 0.4 * sin(2.0 * .pi * frequency * t)
                // フェード
                if i < fadeFrames {
                    amplitude *= Double(i) / Double(fadeFrames)
                } else if i > Int(frameCount) - fadeFrames {
                    amplitude *= Double(Int(frameCount) - i) / Double(fadeFrames)
                }
                data[i] = Float(amplitude)
            }
        }

        do {
            let file = try AVAudioFile(forWriting: outputURL, settings: format.settings)
            try file.write(from: buffer)
            return outputURL
        } catch {
            print("[DemoSeeder] ファイル書き込みエラー: \(error)")
            return nil
        }
    }

    // MARK: - Demo Artwork Generator

    /// テキストとグラデーションで簡易アートワーク画像を生成
    private static func makeDemoArtwork(index: Int) -> UIImage {
        let size   = CGSize(width: 300, height: 300)
        let colors: [(UIColor, UIColor)] = [
            (UIColor(hex: "#5B6AF0"), UIColor(hex: "#9B5CF0")),  // インディゴ→パープル
            (UIColor(hex: "#0099CC"), UIColor(hex: "#00CCB4")),  // シアン→ティール
            (UIColor(hex: "#FF6B35"), UIColor(hex: "#FFB347")),  // オレンジ→アンバー
            (UIColor(hex: "#2E9E50"), UIColor(hex: "#5BD47A")),  // グリーン→ライトグリーン
        ]
        let (c1, c2) = colors[index % colors.count]
        let notes = ["♩", "♪", "♫", "♬"]
        let note  = notes[index % notes.count]

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // グラデーション背景
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors:      [c1.cgColor, c2.cgColor] as CFArray,
                locations:   [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end:   CGPoint(x: size.width, y: size.height),
                options: []
            )

            // 音符アイコン
            let attrs: [NSAttributedString.Key: Any] = [
                .font:            UIFont.systemFont(ofSize: 120),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            ]
            let str = note as NSString
            let strSize = str.size(withAttributes: attrs)
            str.draw(
                at: CGPoint(
                    x: (size.width  - strSize.width)  / 2,
                    y: (size.height - strSize.height) / 2
                ),
                withAttributes: attrs
            )
        }
    }
}
