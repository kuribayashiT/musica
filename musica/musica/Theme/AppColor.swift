//
//  AppColor.swift
//  musica
//
//  デザインシステム — カラートークン定義
//  テーマ切り替えを廃止し、バイオレットインディゴアクセントに固定。
//
//  2025 トレンド準拠:
//    - アクセント: #7867F5（バイオレットインディゴ）
//      従来の青寄りインディゴ #5B6AF0 より紫側にシフト。
//      Arc / Linear / Figma など最先端 creative tool と同系統。
//    - ダーク背景: わずかに暖かみを加え #121218 へ（冷たすぎる青黒を改善）
//    - Surface: #1E2030 → 背景との差が出やすいよう微調整
//

import UIKit

// MARK: - Semantic Color Tokens

enum AppColor {

    // ── ブランドカラー ──────────────────────────────────────────────
    /// メインアクセントカラー（バイオレットインディゴ固定）
    static let accent: UIColor = UIColor(hex: "#7867F5")

    /// アクセントの薄い版
    static var accentMuted: UIColor { accent.withAlphaComponent(0.15) }

    // ── 背景 ────────────────────────────────────────────────────────
    static let background = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#121218")
            : UIColor(hex: "#F4F3FA")
    }

    static let surface = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#1E2030")
            : UIColor(hex: "#FFFFFF")
    }

    static let surfaceSecondary = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#181A28")
            : UIColor(hex: "#ECEAF6")
    }

    // ── テキスト ──────────────────────────────────────────────────
    static let textPrimary = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#F0F1F5")
            : UIColor(hex: "#111827")
    }

    static let textSecondary = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#9BA3B8")
            : UIColor(hex: "#6B7280")
    }

    static let textDisabled = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#4A5068")
            : UIColor(hex: "#C0C4D0")
    }

    // ── ボーダー・区切り線 ─────────────────────────────────────────
    static let separator = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#2C2E40")
            : UIColor(hex: "#E2DFEF")
    }

    static let border = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#38394E")
            : UIColor(hex: "#CAC6DC")
    }

    // ── アクション ───────────────────────────────────────────────
    static let destructive = UIColor(hex: "#FF3B30")

    static let inactive = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#4A5068")
            : UIColor(hex: "#C0C4D0")
    }

    // ── 再生コントロール専用 ──────────────────────────────────────
    static let playerBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#121218")
            : UIColor(hex: "#FFFFFF")
    }

    static let miniPlayerBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#1E2030").withAlphaComponent(0.95)
            : UIColor(hex: "#FFFFFF").withAlphaComponent(0.95)
    }

    // ── ナビゲーション ───────────────────────────────────────────
    static var navigationBackground: UIColor { accent }
    static let navigationForeground: UIColor = .white

    // ── オーバーレイ・シャドウ ───────────────────────────────────
    static let overlay = UIColor.black.withAlphaComponent(0.45)
    static let shadow  = UIColor.black.withAlphaComponent(0.14)
}

// MARK: - UIColor Hex Initializer

extension UIColor {
    convenience init(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8)  & 0xFF) / 255
        let b = CGFloat(rgb         & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
