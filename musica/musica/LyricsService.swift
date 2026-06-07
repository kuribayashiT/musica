//
//  LyricsService.swift
//  musica
//
//  lyrics.ovh API（無料・API Key不要）で歌詞を取得する。
//  取得した歌詞は CoreData + メモリキャッシュに保存し、
//  既存の登録済み歌詞（lyric != ""）は絶対に上書きしない。
//
//  Apple Music DRM / Amazon Music トラックは url == nil で
//  persistentID を持つ。CoreData には "am://\(persistentID)" として保存。
//

import UIKit
import CoreData
import MediaPlayer

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
    /// Apple Music / Amazon Music の DRM トラックは trackURL == nil になるため、
    /// persistentID を使って CoreData キー "am://\(persistentID)" で照合する。
    ///
    /// - Parameters:
    ///   - lyrics: 保存する歌詞テキスト
    ///   - trackURL: 対象トラックのファイル URL（DRM トラックの場合は nil）
    ///   - persistentID: DRM トラックの persistentID（通常トラックは 0）
    ///   - libraryName: 対象ライブラリ名（CoreData 検索キー）
    ///   - trackIndex: displayMusicLibraryData / NowPlayingMusicLibraryData の index
    static func saveFetchedLyrics(_ lyrics: String,
                                   trackURL: URL?,
                                   persistentID: MPMediaEntityPersistentID = 0,
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
                guard let storedUrlStr = record.url else { continue }
                // URL か am:// キーで照合（scanViewController と同じ方式）
                let matches: Bool
                if let trackURL {
                    matches = URL(string: storedUrlStr) == trackURL
                } else {
                    matches = storedUrlStr == "am://\(persistentID)"
                }
                guard matches else { continue }
                // 既存歌詞がなければ書き込む
                if (record.lyric ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    record.lyric = lyrics
                }
                break
            }
            try? context.save()
        }

        // ③ メモリキャッシュ更新
        updateMemoryCache(lyrics: lyrics, trackURL: trackURL, persistentID: persistentID, trackIndex: trackIndex)
    }

    // MARK: Private helpers

    private static func updateMemoryCache(lyrics: String,
                                          trackURL: URL?,
                                          persistentID: MPMediaEntityPersistentID,
                                          trackIndex: Int) {
        // displayMusicLibraryData（index で更新）
        if trackIndex < displayMusicLibraryData.trackData.count,
           displayMusicLibraryData.trackData[trackIndex].lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayMusicLibraryData.trackData[trackIndex].lyric = lyrics
        }

        // NowPlayingMusicLibraryData（URL または persistentID で照合）
        for i in 0..<NowPlayingMusicLibraryData.trackData.count {
            let t = NowPlayingMusicLibraryData.trackData[i]
            let matches = trackURL != nil
                ? t.url == trackURL
                : (persistentID != 0 && t.persistentID == persistentID)
            if matches && t.lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NowPlayingMusicLibraryData.trackData[i].lyric = lyrics
                break
            }
        }
        for i in 0..<NowPlayingMusicLibraryData.trackDataShuffled.count {
            let t = NowPlayingMusicLibraryData.trackDataShuffled[i]
            let matches = trackURL != nil
                ? t.url == trackURL
                : (persistentID != 0 && t.persistentID == persistentID)
            if matches && t.lyric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                NowPlayingMusicLibraryData.trackDataShuffled[i].lyric = lyrics
                break
            }
        }
    }
}
