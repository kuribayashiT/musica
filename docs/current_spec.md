# musica 現状機能定義書

**バージョン:** 4.2.65  
**更新日:** 2026-04-28  
**対象:** ソースコード実態に基づく現状整理

---

## 1. アプリ概要

音楽再生・管理と YouTube MV を統合したマルチメディア音楽アプリ。  
iOS 音楽ライブラリからカスタムプレイリストを作成し、速度変更・区間リピート・歌詞編集・ディクテーション練習などの高機能再生ができる。  
語学学習・カラオケ練習・耳コピを主なユースケースとする。

---

## 2. 画面構成（5タブ）

```
Tab 0: ホーム    HomeAreaViewController
Tab 1: 練習      PracticeViewController          ← ランキングタブを置き換え（AppDelegate で動的注入）
Tab 2: 検索      SearchViewController
Tab 3: スキャン  scanViewController
Tab 4: 設定      SettingViewController
```

> ランキング（ITuneRankingViewController）は AppDelegate の `injectPracticeTab()` によって「練習」タブに差し替えられる。  
> Storyboard 上は元の5タブ構成のまま。

---

## 3. 各画面の機能定義

### Tab 0: ホーム（HomeAreaViewController）

**役割:** カスタム音楽ライブラリの管理と起点

| 機能 | 実装詳細 |
|------|----------|
| ライブラリ一覧表示 | UITableView。各行に名前・曲数・アイコン・アイコンカラーを表示 |
| ライブラリ作成 | ナビゲーションバーの「+」ボタン → OSアルバム一覧 → 曲選択 → 名前入力 |
| ライブラリ削除 | 左スワイプで「削除」ボタン表示（SWTableViewCell） |
| ライブラリリネーム | 左スワイプで「名前変更」ボタン表示 |
| 並び替え | ドラッグ&ドロップ（編集モード） |
| お気に入りMV | テーブル末尾に固定セクションとして表示（`PlayMVListViewController` へ遷移） |
| チュートリアル | 初回起動時に CoachMarksController で案内 |
| 報酬型広告ボタン | 右上に常時表示（課金済みの場合は非表示） |

**遷移先:**
- ライブラリタップ → `MusicPlayListViewController`
- お気に入りMVタップ → `PlayMVListViewController`
- ライブラリ作成 → `CustomMusicLibraryAlbumViewController`

---

### Tab 0 → プレイリスト（MusicPlayListViewController）

**役割:** ライブラリ内のトラック一覧と簡易再生コントロール

| 機能 | 実装詳細 |
|------|----------|
| トラック一覧 | UITableView。タイトル・アーティスト・アルバム表示 |
| 再生 | トラックタップ → `PlayMusicViewController` へ遷移 |
| ミニプレイヤー | 上部に現在再生中の曲名（自動スクロール）・前曲/再生/次曲ボタン |
| トラック追加 | 右上「+」ボタン → `CustamMusicLibraryRegisterViewController` |
| トラック削除 | 左スワイプで削除 |
| 並び替え | ドラッグ&ドロップ（編集モード） |
| 広告 | バナー広告（下部） |

---

### Tab 0 → 再生（PlayMusicViewController）

**役割:** メイン再生画面（旧UI + 新UI が共存。`PlayMusicViewControllerNewUI` / `PlayMusicViewControllerPlayerUI` として分割実装済み）

| 機能 | 実装詳細 |
|------|----------|
| 再生/一時停止 | 中央の再生ボタン |
| 前曲/次曲 | 左右ボタン |
| 再生位置 | `AMProgressSlider`（ドラッグ時にトラックが太くなりサムが出現するカスタムスライダー） |
| 経過時間/総時間 | ラベル表示 |
| 再生速度 | `SpeedSheetViewController`（ボトムシート。プリセットボタン5種 + スライダー） |
| リピート | ボタンで3段階切り替え：なし → 全曲 → 1曲。ラベル付き状態表示 |
| シャッフル | ボタンON/OFF。ラベル付き状態表示 |
| 区間リピート | `RegionRepeatSheetViewController`（ボトムシート）で開始/終了点を指定 |
| アルバムアート/歌詞 | タップジェスチャーで切り替え |
| 歌詞フォントサイズ | ボタンで変更（7段階） |
| コマンドセンター | ロック画面・AirPlay 対応（MPNowPlayingInfoCenter） |
| バックグラウンド再生 | AVAudioSession による常時再生 |
| インタースティシャル広告 | 曲終了時に表示（課金済みは非表示） |

**新UIコンポーネント（実装済み）:**
- `PlayMusicViewControllerNewUI.swift` — アルバムアート表示・歌詞切り替え・シャッフル/リピートUI
- `PlayMusicViewControllerPlayerUI.swift` — 速度プリセットアクション・SpeedSheetDelegate・タグ定数
- `SpeedSheetViewController.swift` — 速度選択ボトムシート（0.25x〜3.0x）
- `RegionRepeatSheetViewController.swift` — 区間リピートボトムシート（RangeTrackView）

---

### Tab 0 → お気に入りMV（PlayMVListViewController → YoutubeVideoViewController / YoutubePlayViewController）

**役割:** お気に入りYouTube動画の管理と再生

| 機能 | 実装詳細 |
|------|----------|
| グリッド表示 | 2列 UICollectionView（SDWebImage でサムネ表示） |
| 並び替え | 長押し → ジグルアニメーション → ドラッグ |
| 削除 | 編集モード中のバツボタン |
| 動画再生 | `YoutubeVideoViewController`（WKWebView 埋め込み） |
| ディクテーション練習 | 動画詳細画面から `DictationSetupViewController` へ遷移（YouTubeルート） |
| 字幕登録 | `CaptionTextEditorViewController`（字幕なし動画で表示） |

---

### Tab 0 → 音楽登録（CustamMusicLibraryRegisterViewController）

**役割:** ライブラリへの曲追加

| 機能 | 実装詳細 |
|------|----------|
| 曲選択 | OS 標準ライブラリからアルバム → 曲を複数選択 |
| 選択曲確認 | UITableView で選択中の曲一覧を表示 |
| 曲削除 | スワイプで選択解除 |
| 並び替え | ドラッグ&ドロップ |
| ライブラリ名入力 | UITextField（上部固定） |
| 登録/更新 | 「決定」ボタン → CoreData に保存 |
| 進捗表示 | UIProgressView で登録進捗を表示 |

---

### Tab 1: 練習（PracticeViewController）

**役割:** 語学・音楽練習のダッシュボード。再生中の曲をもとに各練習モードへ案内する。

| 機能 | 実装詳細 |
|------|----------|
| 再生中カード | 現在再生中の曲名・アーティスト・アートワークを常時表示。タップで再生/一時停止 |
| 速度プリセット | 水平スクロール。0.5x〜2.0x の9段階プリセットをタップで即時変更 |
| 機能グリッド（2列） | 区間リピート（`SectionRepeatViewController`）・Coming Soon 枠 |
| ディクテーションカード | 歌詞の有無でCTAが変化。「ディクテーション開始」「テキストを準備する」「字幕を入力する」 |
| 言語選択 | 検出した言語チップを水平スクロール表示。タップで対象言語を絞り込み |

**遷移先:**
- 区間リピート → `SectionRepeatViewController`
- ディクテーション開始 → `DictationViewController`
- テキスト準備 → `DictationSetupViewController`（音楽ルート）
- 字幕入力 → `DictationSetupViewController`（YouTubeルート）

---

### Tab 1 → テキスト準備（DictationSetupViewController）

**役割:** ディクテーション用テキストの準備（取得・確認・保存）

| 機能 | 実装詳細 |
|------|----------|
| WhisperKit 文字起こし | オンデバイス AI（モデル選択可：Tiny〜Small）で音声を自動テキスト化 |
| 言語指定 | 自動検出・日本語・英語・中国語・韓国語・その他から選択 |
| スクショOCR | PHPicker で複数枚選択 → Vision Framework でテキスト抽出 |
| YouTube字幕取得 | InnerTube API → WKWebView フォールバックで字幕自動取得 |
| 歌詞テキスト確認/編集 | `LyricsTextEditorViewController` でモーダル表示 |
| テキスト保存 | `LyricsService.saveFetchedLyrics` で CoreData + メモリキャッシュに保存 |
| Reward広告 | 文字起こし前に Reward 広告を表示（課金済みはスキップ） |

---

### Tab 1 → 区間リピート（SectionRepeatViewController）

**役割:** 曲の特定区間をループ再生する練習画面

| 機能 | 実装詳細 |
|------|----------|
| 区間指定 | `RangeTrackView`（カスタムビュー）で開始・終了ハンドルをドラッグ |
| ループ再生 | `AVAudioPlayer` で区間をループ。ループON/OFFボタン |
| 再生位置表示 | 経過時間・総時間・現在位置バー |
| 曲情報カード | アートワーク・タイトル・アーティスト表示 |
| ヒントカード | 操作説明 |

---

### Tab 1 → ディクテーション（DictationViewController）

**役割:** 歌詞の穴埋め練習（リスニング → 書き取り）

| 機能 | 実装詳細 |
|------|----------|
| 出題 | 歌詞を行単位でランダム出題。空白マスク表示 |
| 音声読み上げ | `AVSpeechSynthesizer`（TTS）で出題文を読み上げ |
| 音声入力（回答） | `SFSpeechRecognizer` でマイク入力 → テキスト変換 |
| 正誤判定 | 入力テキストと正解を比較。スコア集計 |
| ミニプレイヤー | 練習中も元の楽曲を再生可能 |
| 結果表示 | `DictationResultViewController` でスコア・正解一覧を表示 |

---

### Tab 2: 検索（SearchViewController）

**役割:** YouTube 動画の検索と試聴

| 機能 | 実装詳細 |
|------|----------|
| キーワード検索 | YouTube Data API v3 |
| 推奨ワード | CollectionView で横スクロール表示 |
| 推奨MV | CollectionView で横スクロール表示 |
| 検索結果 | UITableView（サムネイル・タイトル・チャンネル名） |
| 動画プレビュー | WKWebView による YouTube 埋め込み再生 |
| お気に入り登録 | MV を CoreData（MVModel）に保存 |
| ネイティブ広告 | 6〜7件ごとに広告を挿入 |
| バナー広告 | 下部 |

---

### Tab 3: スキャン/翻訳（scanViewController）

**役割:** OCR と翻訳（歌詞スキャン用。練習タブが主力になったため補助的な位置づけ）

| 機能 | 実装詳細 |
|------|----------|
| OCRスキャン | カメラ撮影 → Google Vision API → テキスト抽出 |
| テキスト翻訳 | 日本語・英語・中国語に対応 |
| 翻訳結果表示 | セグメント切り替え（原文 / 翻訳後） |
| 歌詞編集モード | 再生中の曲の歌詞をテキストエリアで編集・CoreData 保存 |
| 翻訳回数制限 | Reward 広告を見ると翻訳回数（5回）補充 |

---

### Tab 4: 設定（SettingViewController）

**役割:** アプリ全体の設定と課金

| 機能 | 実装詳細 |
|------|----------|
| プッシュ通知 | ON/OFF トグル |
| カラーテーマ | 9種類から選択（即時反映） |
| 広告削除（課金） | 課金済みなら非表示。未課金時に「削除」ボタン表示 |
| おすすめアプリ | 自社他アプリへのリンク |
| ホームページ | SafariViewController で開く |
| プライバシーポリシー | SafariViewController で開く |
| アプリ情報 | バージョン番号表示 |

---

## 4. サービス層・ユーティリティ

### 新規追加サービス（v4.2.x〜）

| クラス | 役割 |
|--------|------|
| `WhisperKitService` | オンデバイス Whisper AI 文字起こし。チャンク分割・沈黙分割・多言語対応・重複除去・ローマ字除去など |
| `TranscriptionService` | WhisperKit のラッパー。16kHz モノラル変換・チャンク処理・多言語ベスト選択 |
| `YouTubeCaptionFetcher` | InnerTube API + WKWebView フォールバックで YouTube 字幕を自動取得 |
| `YoutubeCaptionStore` | 動画IDをキーに字幕テキストを UserDefaults に永続化 |
| `LyricsService` | CoreData への歌詞保存・取得。`displayMusicLibraryData` / `NowPlayingMusicLibraryData` のメモリキャッシュも同期 |

### オンボーディング

`OnboardingViewController` — 3ステップ（Welcome → ゴール選択 → 使い方説明）  
初回起動時に表示。ゴール選択（カラオケ / 語学 / 耳コピ）に応じて訴求内容を変える。

### シミュレータ専用

`DemoDataSeeder` — シミュレータ起動時にサイン波デモ音声4曲を自動生成してデモライブラリとして登録。

---

## 5. データモデル

### CoreData エンティティ

| エンティティ | 主要フィールド | 用途 |
|-------------|---------------|------|
| `MusicLibraryModel` | musicLibraryName, trackNum, iconName, icomColorName, indicatoryNum | ライブラリ一覧管理 |
| `MusicModel` | trackTitle, artist, albumTitle, genre, url, lyric, artworkData | 各ライブラリのトラック（歌詞含む） |
| `MVModel` | videoID, videoTitle, thumbnailUrl, videoTime, indicatoryNum | お気に入りMV |

### UserDefaults 主要キー

| キー | 型 | 用途 |
|------|----|------|
| `colorthema` | Int | カラーテーマ番号（0〜8） |
| `kakin` | Bool | 課金状態 |
| `ADdate` | Date | 広告非表示期限 |
| `mojisize` | Int | 歌詞フォントサイズ |
| `startUpCount` | Int | 起動回数 |
| `transCount` | Int | 翻訳残回数 |
| `demoSeeded` | Bool | デモデータ生成済みフラグ（シミュレータ専用） |

### グローバル状態（define.swift）

```swift
var SHUFFLE_FLG: Bool              // シャッフル状態
var repeatState: Int               // 0:なし 1:1曲 2:全曲
var LYRIC_IMG_SEGMENT_STATE: Int   // 0:サムネ 1:歌詞
var NowPlayingMusicLibraryData     // 再生中ライブラリ（NowPlayingData 構造体）
var displayMusicLibraryData        // 表示中ライブラリ
var KAKIN_FLG: Bool                // 課金状態
var NOW_COLOR_THEMA: Int           // テーマ番号
var speedRow: Int                  // 再生速度インデックス（0〜60、デフォルト5=1.0x）
// ...他30以上
```

---

## 6. デザインシステム（実装済み）

```swift
// AppColor — テーマ対応カラートークン（AppDelegate で初期化）
AppColor.accent          // テーマのアクセントカラー
AppColor.background      // 画面背景
AppColor.surface         // カード・セル背景
AppColor.surfaceSecondary
AppColor.textPrimary
AppColor.textSecondary
AppColor.separator

// AppFont
AppFont.headline         // 17pt Semibold
AppFont.footnote         // 13pt Regular
AppFont.caption          // 12pt Regular
```

---

## 7. 外部サービス

| サービス | 用途 |
|----------|------|
| YouTube Data API v3 | 動画検索 |
| YouTube InnerTube API | 字幕自動取得（`YouTubeCaptionFetcher`） |
| Google Vision API | OCR（スキャンタブ） |
| iTunes RSS API | ランキング |
| WhisperKit（オンデバイス） | 音声文字起こし（`WhisperKitService`） |
| Firebase Analytics | 行動ログ |
| Firebase Cloud Messaging | プッシュ通知 |
| Firebase Remote Config | 機能フラグ・AD設定 |
| Firebase Crashlytics | クラッシュ解析 |
| Google AdMob | 広告（バナー・ネイティブ・インタースティシャル・Reward） |
| Five / AppVador | サブ広告ネットワーク |
| SwiftyStoreKit | アプリ内課金 |
| Vision Framework | スクショOCR（`DictationSetupViewController` / `CaptionTextEditorViewController`） |
| Speech Framework | 音声入力（ディクテーション回答） |
| AVSpeechSynthesizer | TTS 読み上げ（ディクテーション出題） |

---

## 8. 現状の UX 課題

### 8-A. 初見ユーザーの導線が不明確

- `OnboardingViewController` は実装済みだが、表示条件・起動タイミングの詰めが必要
- ホームタブで「まず何をすべきか」が空状態では分かりにくい（空状態UIは未実装）
- 「+」ボタンが複数画面に散在し、「新規ライブラリ作成」と「トラック追加」が同じアイコンで区別しにくい

### 8-B. 練習タブと再生タブの連携

- 練習タブは「再生中の曲」に依存するが、曲が未再生のときのUXが不完全（アラートのみ）
- ディクテーション終了後に元の曲・ライブラリへ自然に戻れる経路がない

### 8-C. 再生画面の新旧UI混在

- 旧実装（UIPickerView の速度選択など）と新実装（SpeedSheet・RegionRepeatSheet）が共存しており、コードが散在
- `PlayMusicViewController.swift` 本体のリファクタリングが未完

### 8-D. スキャンタブの役割の曖昧さ

- `scanViewController` は OCR スキャンと歌詞編集という異なる機能が同居したまま
- 練習タブに歌詞準備機能（WhisperKit OCR）が追加されたため、スキャンタブの存在意義が薄れている

### 8-E. 状態管理の複雑さ（開発上の問題）

- グローバル変数が30以上存在し、画面間の状態共有が追いにくい
- `CUSTOM_LYBRARY_FROM_MUSICLIST` などのフラグで遷移元を判定する設計
- 同じロジック（キーボード管理・広告ロード）が複数画面に重複実装
