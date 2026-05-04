//
//  YoutubeCaptionStore.swift
//  musica
//
//  YouTube 動画の字幕テキストを videoID をキーとして UserDefaults に保存するユーティリティ。

import Foundation

enum YoutubeCaptionStore {

    private static func key(for videoID: String) -> String {
        "yt_caption_v1_\(videoID)"
    }

    static func save(_ caption: String, for videoID: String) {
        UserDefaults.standard.set(caption, forKey: key(for: videoID))
    }

    static func load(for videoID: String) -> String? {
        let s = UserDefaults.standard.string(forKey: key(for: videoID))
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }

    static func delete(for videoID: String) {
        UserDefaults.standard.removeObject(forKey: key(for: videoID))
    }

    static func exists(for videoID: String) -> Bool {
        load(for: videoID) != nil
    }
}
