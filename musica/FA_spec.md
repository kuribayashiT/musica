# Firebase Analytics 実装仕様書

## 概要

`util.swift` 末尾の `enum FA` に全イベント定数・ログ関数を集約。  
各画面・ボタンから `FA.logScreen` / `FA.log` を呼ぶだけで記録できる構造。

---

## 1. 画面遷移ログ（screen_view）

各 ViewController の `viewDidAppear` で `FA.logScreen` を呼ぶ。

| screen_name        | screen_class                    | ファイル                              |
|--------------------|--------------------------------|---------------------------------------|
| `home`             | HomeAreaViewController          | HomeAreaViewController.swift          |
| `player`           | PlayMusicViewController         | PlayMusicViewController.swift         |
| `practice`         | PracticeViewController          | PracticeViewController.swift          |
| `settings`         | SettingViewController           | SettingViewController.swift           |
| `dictation_setup`  | DictationSetupViewController    | DictationSetupViewController.swift    |
| `dictation`        | DictationViewController         | DictationViewController.swift         |
| `section_repeat`   | SectionRepeatViewController     | SectionRepeatViewController.swift     |
| `flash_card`       | FlashCardViewController         | FlashCardViewController.swift         |
| `weak_words`       | WeakWordListViewController      | WeakWordListViewController.swift      |
| `speed_sheet`      | SpeedSheetViewController        | SpeedSheetViewController.swift        |

```swift
// 実装パターン（共通）
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    FA.logScreen(FA.Screen.home, vc: "HomeAreaViewController")
}
```

---

## 2. カスタムイベント一覧

### 2-1. 再生操作

| イベント名   | 発火箇所                        | パラメータ                          |
|-------------|--------------------------------|-------------------------------------|
| `play_tap`  | 再生ボタン押下（停止→再生）      | なし                                |
| `stop_tap`  | 停止ボタン押下                   | なし                                |
| `next_track`| 次曲ボタン押下                   | なし                                |
| `prev_track`| 前曲ボタン押下                   | なし                                |

### 2-2. シャッフル・リピート

| イベント名       | 発火箇所              | パラメータ               |
|----------------|-----------------------|--------------------------|
| `shuffle_toggle`| シャッフルボタン押下  | `enabled: Bool`          |
| `repeat_toggle` | リピートボタン押下    | なし（状態はアプリ内管理）|

### 2-3. 再生速度

| イベント名        | 発火箇所                          | パラメータ                                                 |
|-----------------|----------------------------------|------------------------------------------------------------|
| `speed_sheet_open` | 再生速度ラベルタップ（シート開く）| なし                                                       |
| `speed_change`    | 速度変更（複数経路）              | `speed: Double`, `source: String`                          |

`source` の値：

| source               | 意味                             |
|---------------------|----------------------------------|
| `speed_sheet_slider` | スピードシートのスライダー操作    |
| `speed_sheet_preset` | スピードシートのプリセットボタン  |
| `practice_tab`       | 練習タブのスライダー/ピル操作     |

### 2-4. 練習機能

| イベント名        | 発火箇所                  | パラメータ             |
|-----------------|--------------------------|------------------------|
| `dictation_start` | ディクテーション開始ボタン | `track: String`（曲名）|
| `flash_card_start`| フラッシュカード開始ボタン | `track: String`（曲名）|

### 2-5. 区間リピート

| イベント名               | 発火箇所                                    | パラメータ                            |
|------------------------|--------------------------------------------|---------------------------------------|
| `section_repeat_toggle` | ループON/OFFスイッチ変更時                  | `enabled: Bool`                       |
| `section_repeat_save`   | 「スタートをここに」「エンドをここに」ボタン  | `start: Double`, `end: Double`        |

### 2-6. オンボーディング

| イベント名            | 発火箇所             | パラメータ         |
|---------------------|---------------------|-------------------|
| `onboarding_complete`| 「始める」or スキップ | `goal: String`（`music` / `youtube` / `earCopy`）|

### 2-7. 曲追加

| イベント名  | 発火箇所                        | パラメータ           |
|-----------|--------------------------------|---------------------|
| `song_add` | ライブラリ登録成功時             | `count: Int`（登録曲数）|

### 2-8. インタースティシャル広告

| イベント名             | 発火箇所                         | パラメータ                     |
|----------------------|----------------------------------|-------------------------------|
| `ad_interstitial_show`| 広告表示直前（頻度制御通過後）     | `tracks_since_last: Int`      |

**頻度制御ロジック（PlayMusicViewController）**:
- 4曲以上スキップ/自動送り後、かつ前回表示から 180 秒（3分）以上経過した場合のみ表示
- 次曲移行 (`nextMusicPlay`) とプレイリスト末尾 (`endTruckCheckRepeat`) の両方でカウント

---

## 3. FA ヘルパー実装（util.swift）

```swift
enum FA {
    enum Screen {
        static let home           = "home"
        static let player         = "player"
        static let practice       = "practice"
        static let settings       = "settings"
        static let dictation      = "dictation"
        static let dictationSetup = "dictation_setup"
        static let sectionRepeat  = "section_repeat"
        static let flashCard      = "flash_card"
        static let weakWords      = "weak_words"
        static let speedSheet     = "speed_sheet"
    }

    static let playTap             = "play_tap"
    static let stopTap             = "stop_tap"
    static let nextTrack           = "next_track"
    static let prevTrack           = "prev_track"
    static let speedChange         = "speed_change"
    static let speedSheetOpen      = "speed_sheet_open"
    static let sectionRepeatToggle = "section_repeat_toggle"
    static let sectionRepeatSave   = "section_repeat_save"
    static let dictationStart      = "dictation_start"
    static let flashCardStart      = "flash_card_start"
    static let shuffleToggle       = "shuffle_toggle"
    static let repeatToggle        = "repeat_toggle"
    static let onboardingComplete  = "onboarding_complete"
    static let adInterstitialShow  = "ad_interstitial_show"
    static let songAdd             = "song_add"

    static func logScreen(_ name: String, vc: String) {
        Analytics.logEvent("screen_view", parameters: [
            "screen_name": name, "screen_class": vc
        ])
    }

    static func log(_ event: String, params: [String: Any]? = nil) {
        Analytics.logEvent(event, parameters: params)
    }
}
```

---

## 4. Firebase Console で確認できる主な指標

| 見たいこと                 | Consoleの場所               | 使うイベント                     |
|--------------------------|----------------------------|----------------------------------|
| どの画面がよく使われるか    | Events → screen_view        | 全画面                           |
| 再生操作の頻度             | Events → play_tap / stop_tap| play_tap, stop_tap               |
| 速度変更の傾向             | Events → speed_change       | source・speed パラメータで絞る    |
| 練習機能の利用率           | Events → dictation_start等  | dictation_start, flash_card_start|
| シャッフル利用状況         | Events → shuffle_toggle     | enabled パラメータ               |

---

## 5. AdMob 広告頻度制御仕様

| 種別                 | 表示条件                                           | 実装場所                              |
|--------------------|---------------------------------------------------|---------------------------------------|
| インタースティシャル  | 4曲以上経過 **かつ** 前回表示から 3 分（180秒）以上 | `PlayMusicViewController.tryShowInterstitialIfNeeded()` |
| バナー（ホーム）     | `ADApearFlg()` が真の場合 常時表示                  | 既存実装のまま                         |
| バナー（設定）       | 同上                                               | 既存実装のまま                         |

**広告表示フロー（インタースティシャル）**:
1. `nextMusicPlay()` または `endTruckCheckRepeat()` で曲数カウントをインクリメント
2. `tryShowInterstitialIfNeeded()` が条件を確認 → 表示
3. `ad_interstitial_show` イベントを Firebase に送信
4. 広告クローズ後 `adDidDismissFullScreenContent` が次の曲を自動再生
