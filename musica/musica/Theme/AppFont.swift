//
//  AppFont.swift
//  musica
//
//  デザインシステム — タイポグラフィ定義
//
//  使い方:
//    label.font = AppFont.title
//    label.font = AppFont.body
//    label.font = AppFont.caption
//
//  Dynamic Type 対応:
//    AppFont はすべて UIFontMetrics でスケールされます。
//    ユーザーの文字サイズ設定に自動追従します。
//

import UIKit

// MARK: - AppFont

enum AppFont {

    // ── 見出し系 ────────────────────────────────────────────────────

    /// ナビゲーションタイトル / Large Title（34pt Bold）
    static var largeTitle: UIFont {
        scaled(.title1, size: 34, weight: .bold)
    }

    /// 画面内ヘッダー（28pt Bold）
    static var title: UIFont {
        scaled(.title1, size: 28, weight: .bold)
    }

    /// セクションタイトル / アルバム名（20pt Semibold）
    static var title2: UIFont {
        scaled(.title2, size: 20, weight: .semibold)
    }

    /// リスト1行目 / 曲名（17pt Semibold）
    static var headline: UIFont {
        scaled(.headline, size: 17, weight: .semibold)
    }

    // ── 本文系 ────────────────────────────────────────────────────

    /// 標準テキスト（17pt Regular）
    static var body: UIFont {
        scaled(.body, size: 17, weight: .regular)
    }

    /// 説明文・アーティスト名（15pt Regular）
    static var subheadline: UIFont {
        scaled(.subheadline, size: 15, weight: .regular)
    }

    /// ボタンラベル（16pt Medium）
    static var button: UIFont {
        scaled(.callout, size: 16, weight: .medium)
    }

    /// フッター・補足情報（13pt Regular）
    static var footnote: UIFont {
        scaled(.footnote, size: 13, weight: .regular)
    }

    /// タイムスタンプ・件数・バッジ（12pt Regular）
    static var caption: UIFont {
        scaled(.caption1, size: 12, weight: .regular)
    }

    /// 極小ラベル（11pt Regular）
    static var caption2: UIFont {
        scaled(.caption2, size: 11, weight: .regular)
    }

    // ── 再生画面専用 ──────────────────────────────────────────────

    /// 再生画面 — 曲名（22pt Bold）
    static var playerTitle: UIFont {
        scaled(.title2, size: 22, weight: .bold)
    }

    /// 再生画面 — アーティスト名（17pt Medium）
    static var playerArtist: UIFont {
        scaled(.body, size: 17, weight: .medium)
    }

    /// 再生時間（数字）（14pt Regular / Monospaced）
    static var playerTime: UIFont {
        UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
    }

    /// 歌詞テキスト（歌詞サイズ設定に従う）
    static func lyric(sizeIndex: Int) -> UIFont {
        let sizes: [CGFloat] = [13, 15, 17, 19, 22, 26, 30]
        let size = sizes[max(0, min(sizeIndex, sizes.count - 1))]
        return UIFontMetrics(forTextStyle: .body).scaledFont(
            for: UIFont.systemFont(ofSize: size, weight: .regular)
        )
    }

    // ── ミニプレイヤー ────────────────────────────────────────────

    /// ミニプレイヤー — 曲名（15pt Semibold）
    static var miniPlayerTitle: UIFont {
        scaled(.subheadline, size: 15, weight: .semibold)
    }

    /// ミニプレイヤー — アーティスト名（13pt Regular）
    static var miniPlayerArtist: UIFont {
        scaled(.footnote, size: 13, weight: .regular)
    }

    // ── ナビゲーションバー ────────────────────────────────────────

    /// ナビゲーションタイトル（17pt Semibold）
    static var navigationTitle: UIFont {
        scaled(.headline, size: 17, weight: .semibold)
    }

    /// ナビゲーションボタン（17pt Regular）
    static var navigationButton: UIFont {
        scaled(.body, size: 17, weight: .regular)
    }

    // MARK: - Private

    private static func scaled(_ textStyle: UIFont.TextStyle, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: base)
    }
}

// MARK: - NSAttributedString helpers

extension AppFont {

    /// ナビゲーションバーのタイトルAttributeを生成
    static func navigationTitleAttributes(color: UIColor) -> [NSAttributedString.Key: Any] {
        [
            .font:            AppFont.navigationTitle,
            .foregroundColor: color
        ]
    }
}
