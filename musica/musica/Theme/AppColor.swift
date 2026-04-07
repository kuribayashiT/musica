//
//  AppColor.swift
//  musica
//
//  デザインシステム — カラートークン定義
//
//  使い方:
//    view.backgroundColor = AppColor.background
//    label.textColor = AppColor.textPrimary
//    button.tintColor = AppColor.accent
//
//  テーマ変更:
//    AppTheme.apply(.ocean)
//    NotificationCenter.default.post(name: .themeDidChange, object: nil)
//

import UIKit

// MARK: - Semantic Color Tokens

enum AppColor {

    // ── ブランドカラー ──────────────────────────────────────────────
    /// メインアクセントカラー（ボタン・選択状態・プログレスバー等）
    static var accent: UIColor { AppTheme.current.accentColor }

    /// アクセントの薄い版（背景ハイライト・バッジ等）
    static var accentMuted: UIColor { AppTheme.current.accentColor.withAlphaComponent(0.15) }

    // ── 背景 ────────────────────────────────────────────────────────
    /// 画面背景（ライト: #F2F4F8 / ダーク: #0F1117）
    static let background = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#0F1117")
            : UIColor(hex: "#F2F4F8")
    }

    /// カード・セル・モーダルの背景（ライト: #FFFFFF / ダーク: #1C1F2A）
    static let surface = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#1C1F2A")
            : UIColor(hex: "#FFFFFF")
    }

    /// セカンダリ背景（グループドテーブルの背景等）
    static let surfaceSecondary = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#161820")
            : UIColor(hex: "#EAECF2")
    }

    // ── テキスト ─────────────────────────────────────────────────────
    /// 主要テキスト（ライト: #111827 / ダーク: #F0F1F5）
    static let textPrimary = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#F0F1F5")
            : UIColor(hex: "#111827")
    }

    /// 補助テキスト（アーティスト名・説明文等）
    static let textSecondary = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#9BA3B8")
            : UIColor(hex: "#6B7280")
    }

    /// 非活性テキスト（placeholder・disabled 等）
    static let textDisabled = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#4A5068")
            : UIColor(hex: "#C0C4D0")
    }

    // ── ボーダー・区切り線 ──────────────────────────────────────────
    /// セパレーター
    static let separator = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#2A2D3A")
            : UIColor(hex: "#DDE1EC")
    }

    /// ボーダー（入力フィールド・カード枠線）
    static let border = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#353848")
            : UIColor(hex: "#C8CCDB")
    }

    // ── アクション ───────────────────────────────────────────────────
    /// 削除・危険操作（常に赤）
    static let destructive = UIColor(hex: "#FF3B30")

    /// 非活性状態のアイコン・ボタン
    static let inactive = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#4A5068")
            : UIColor(hex: "#C0C4D0")
    }

    // ── 再生コントロール専用 ─────────────────────────────────────────
    /// 再生コントロール背景（アルバムアート下部のグラデーション起点）
    static let playerBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#0F1117")
            : UIColor(hex: "#FFFFFF")
    }

    /// ミニプレイヤー背景
    static let miniPlayerBackground = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(hex: "#1C1F2A").withAlphaComponent(0.95)
            : UIColor(hex: "#FFFFFF").withAlphaComponent(0.95)
    }

    // ── ナビゲーション ───────────────────────────────────────────────
    /// ナビゲーションバー背景（テーマ依存）
    static var navigationBackground: UIColor { AppTheme.current.navigationBackground }

    /// ナビゲーションバーのタイトル・ボタン色
    static var navigationForeground: UIColor { AppTheme.current.navigationForeground }

    // ── オーバーレイ・シャドウ ──────────────────────────────────────
    /// モーダル背景のオーバーレイ
    static let overlay = UIColor.black.withAlphaComponent(0.45)

    /// カードシャドウ色
    static let shadow = UIColor.black.withAlphaComponent(0.12)
}

// MARK: - Theme Definition

enum AppThemeStyle: String, CaseIterable {
    case indigo   = "design_theme_indigo"   // デフォルト（集中・洗練）
    case ocean    = "design_theme_ocean"    // 落ち着き重視
    case rose     = "design_theme_rose"     // ポップ
    case warm     = "design_theme_warm"     // ウォーム
    case forest   = "design_theme_forest"  // ナチュラル
    case midnight = "design_theme_midnight" // ダーク派

    var displayName: String {
        switch self {
        case .indigo:   return "インディゴ"
        case .ocean:    return "オーシャン"
        case .rose:     return "ローズ"
        case .warm:     return "ウォーム"
        case .forest:   return "フォレスト"
        case .midnight: return "ミッドナイト"
        }
    }
}

struct AppThemeDefinition {
    let style: AppThemeStyle
    let accentColor: UIColor
    let navigationBackground: UIColor
    let navigationForeground: UIColor
}

// MARK: - AppTheme (Current Theme Manager)

enum AppTheme {

    // ── 現在のテーマ ─────────────────────────────────────────────────
    static var current: AppThemeDefinition = themes[.indigo]!

    // MARK: テーマ適用
    static func apply(_ style: AppThemeStyle) {
        current = themes[style] ?? themes[.indigo]!
        NOW_COLOR_THEMA = legacyIndex(for: style)
        UserDefaults.standard.set(style.rawValue, forKey: "appThemeStyle")
    }

    // MARK: 保存済みテーマを復元
    static func restoreFromUserDefaults() {
        if let raw = UserDefaults.standard.string(forKey: "appThemeStyle"),
           let style = AppThemeStyle(rawValue: raw) {
            apply(style)
        } else {
            // 旧テーマ番号との互換
            let legacyIndex = UserDefaults.standard.integer(forKey: "colorthema")
            apply(styleFromLegacy(legacyIndex))
        }
    }

    // MARK: テーマ一覧
    static let themes: [AppThemeStyle: AppThemeDefinition] = [
        .indigo: AppThemeDefinition(
            style: .indigo,
            accentColor:           UIColor(hex: "#5B6AF0"),   // インディゴブルー
            navigationBackground:  UIColor(hex: "#3D4EC8"),
            navigationForeground:  UIColor(hex: "#FFFFFF")
        ),
        .ocean: AppThemeDefinition(
            style: .ocean,
            accentColor:           UIColor(hex: "#0099CC"),   // オーシャンブルー
            navigationBackground:  UIColor(hex: "#006C91"),
            navigationForeground:  UIColor(hex: "#FFFFFF")
        ),
        .rose: AppThemeDefinition(
            style: .rose,
            accentColor:           UIColor(hex: "#E91E8C"),   // ローズピンク
            navigationBackground:  UIColor(hex: "#C01474"),
            navigationForeground:  UIColor(hex: "#FFFFFF")
        ),
        .warm: AppThemeDefinition(
            style: .warm,
            accentColor:           UIColor(hex: "#FF6B35"),   // ウォームオレンジ
            navigationBackground:  UIColor(hex: "#D94A18"),
            navigationForeground:  UIColor(hex: "#FFFFFF")
        ),
        .forest: AppThemeDefinition(
            style: .forest,
            accentColor:           UIColor(hex: "#2E9E50"),   // フォレストグリーン
            navigationBackground:  UIColor(hex: "#1B6B34"),
            navigationForeground:  UIColor(hex: "#FFFFFF")
        ),
        .midnight: AppThemeDefinition(
            style: .midnight,
            accentColor:           UIColor(hex: "#BB86FC"),   // パープル（ダーク映え）
            navigationBackground:  UIColor(hex: "#1A1A2E"),
            navigationForeground:  UIColor(hex: "#E0E0FF")
        ),
    ]

    // MARK: 旧テーマ番号との変換（後方互換）
    private static func styleFromLegacy(_ index: Int) -> AppThemeStyle {
        switch index {
        case 1, 2: return .rose
        case 3:    return .ocean
        case 4:    return .rose
        case 6, 7: return .midnight
        default:   return .indigo
        }
    }

    private static func legacyIndex(for style: AppThemeStyle) -> Int {
        switch style {
        case .indigo:   return 5
        case .ocean:    return 3
        case .rose:     return 2
        case .warm:     return 1
        case .forest:   return 1
        case .midnight: return 6
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let themeDidChange = Notification.Name("AppThemeDidChange")
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
