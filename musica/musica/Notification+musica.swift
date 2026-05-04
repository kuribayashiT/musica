//
//  Notification+musica.swift
//  musica
//
//  アプリ全体で使う NSNotification.Name の定義。
//

import Foundation

extension Notification.Name {
    /// 練習タブ → PlayMusicVC：再生/停止トグルを要求
    static let musicaRemotePlayPause = Notification.Name("musica.remotePlayPause")

    /// 練習タブ → PlayMusicVC：前の曲へ
    static let musicaRemotePrev = Notification.Name("musica.remotePrev")

    /// 練習タブ → PlayMusicVC：次の曲へ
    static let musicaRemoteNext = Notification.Name("musica.remoteNext")

    /// PlayMusicVC → 全体：再生曲が切り替わった
    static let musicaTrackChanged = Notification.Name("musica.trackChanged")

    /// PlayMusicVC → 練習タブ：再生状態が変化した（userInfo["isPlaying"]: Bool）
    static let musicaPlaybackStateChanged = Notification.Name("musica.playbackStateChanged")
}
