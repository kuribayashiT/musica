//
//  LyricsService.swift
//  musica
//
//  lyrics.ovh API（無料・API Key不要）で歌詞を取得する。
//  取得した歌詞は CoreData + メモリキャッシュに保存し、
//  既存の登録済み歌詞（lyric != ""）は絶対に上書きしない。
//

import UIKit
import CoreData

// MARK: - LyricsService

struct LyricsService {

    // MARK: Fetch

    /// 曲名 + アーティスト名で歌詞を検索する。
    /// - Parameters:
    ///   - title: 曲名
    ///   - artist: アーティスト名
    ///   - completion: 取得できた歌詞テキスト、見つからない場合は nil
    static func fetch(title: String, artist: String,
                      completion: @escaping (String?) -> Void) {
        // lyrics.ovh: https://api.lyrics.ovh/v1/{artist}/{title}
        let base = "https://api.lyrics.ovh/v1/"
        let a = artist.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? artist
        let t = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: base + a + "/" + t) else {
            completion(nil); return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if let jsonObj = try? JSONSerialization.jsonObject(with: data),
               let json = jsonObj as? [String: Any],
               let lyrics = json["lyrics"] as? String,
               !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DispatchQueue.main.async { completion(lyrics) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    // MARK: Save

    /// 取得した歌詞を CoreData + メモリキャッシュに保存する。
    /// 既存歌詞（lyric が空でない）は上書きしない。
    ///
    /// - Parameters:
    ///   - lyrics: 保存する歌詞テキスト
    ///   - trackURL: 対象トラックのファイル URL
    ///   - libraryName: 対象ライブラリ名（CoreData 検索キー）
    ///   - trackIndex: displayMusicLibraryData / NowPlayingMusicLibraryData の index
    static func saveFetchedLyrics(_ lyrics: String,
                                   trackURL: URL,
                                   libraryName: String,
                                   trackIndex: Int) {
        // ① 既存歌詞がある場合は保存しない
        if trackIndex < displayMusicLibraryData.trackData.count,
           !displayMusicLibraryData.trackData[trackIndex].lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }

        // ② CoreData 保存
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context     = appDelegate.managedObjectContext
        let req: NSFetchRequest<MusicModel> = MusicModel.fetchRequest()
        req.predicate = NSPredicate(format: "%K = %@", "musicLibraryName", libraryName)

        if let fetchData = try? context.fetch(req) {
            for record in fetchData {
                guard let urlStr = record.url,
                      URL(string: urlStr) == trackURL else { continue }
                // 既存歌詞がなければ書き込む
                if (record.lyric ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    record.lyric = lyrics
                }
                break
            }
            try? context.save()
        }

        // ③ メモリキャッシュ更新
        updateMemoryCache(lyrics: lyrics, trackURL: trackURL, trackIndex: trackIndex)
    }

    // MARK: Private helpers

    private static func updateMemoryCache(lyrics: String, trackURL: URL, trackIndex: Int) {
        // displayMusicLibraryData
        if trackIndex < displayMusicLibraryData.trackData.count,
           displayMusicLibraryData.trackData[trackIndex].lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayMusicLibraryData.trackData[trackIndex].lyric = lyrics
        }

        // NowPlayingMusicLibraryData（URL 照合）
        for i in 0..<NowPlayingMusicLibraryData.trackData.count {
            if NowPlayingMusicLibraryData.trackData[i].url == trackURL,
               NowPlayingMusicLibraryData.trackData[i].lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NowPlayingMusicLibraryData.trackData[i].lyric = lyrics
                break
            }
        }
        for i in 0..<NowPlayingMusicLibraryData.trackDataShuffled.count {
            if NowPlayingMusicLibraryData.trackDataShuffled[i].url == trackURL,
               NowPlayingMusicLibraryData.trackDataShuffled[i].lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NowPlayingMusicLibraryData.trackDataShuffled[i].lyric = lyrics
                break
            }
        }
    }
}
