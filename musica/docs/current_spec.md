# musica 現状機能定義書

**バージョン:** 5.1.5  
**更新日:** 2026-06-07  
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
Tab 1: スキャン  scanViewController
Tab 2: 設定      SettingViewController
Tab 3: 発見      DiscoverViewController
Tab 4: 練習      PracticeViewController    ← AppDelegate で ITuneRankingViewController と差し替え
```

> Storyboard 上は `ITuneRankingViewController` が Tab 4 に配置されているが、AppDelegate の `injectPracticeTab()` によって `PracticeViewController` に差し替えられる。  
> `SearchViewController` はコード上は残存しているが、Storyboard から切り離されており未使用。

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

**役割:** メイン再生画面（`PlayMusicViewControllerNewUI` / `PlayMusicViewControllerPlayerUI` として分割実装済み）

| 機能 | 実装詳細 |
|------|----------|
| 再生エンジン | `HighSpeedAudioPlayer`（AVAudioEngine ベース）|
| 速度範囲 | **0.5x〜50x**（34スナップポイント） |
| 速度制御方式 | ≤8x: `AVAudioUnitTimePitch`（ピッチ保持）/ >8x: timePitch 8x 固定 + `AVAudioUnitVarispeed` |
| 再生/一時停止 | 中央の再生ボタン |
| 前曲/次曲 | 左右ボタン |
| 再生位置 | `AMProgressSlider`（ドラッグ時にトラックが太くなりサムが出現するカスタムスライダー） |
| 経過時間/総時間 | ラベル表示 |
| 再生速度 | `SpeedSheetViewController`（ボトムシート。プリセットボタン5種 + スライダー 0.5x〜50x） |
| リピート | ボタンで3段階切り替え：なし → 全曲 → 1曲。ラベル付き状態表示 |
| シャッフル | ボタンON/OFF。ラベル付き状態表示 |
| 区間リピート | `RegionRepeatSheetViewController`（ボトムシート）で開始/終了点を指定 |
| アルバムアート/歌詞 | タップジェスチャーで切り替え |
| 歌詞フォントサイズ | ボタンで変更（7段階） |
| コマンドセンター | ロック画面・AirPlay 対応（MPNowPlayingInfoCenter） |
| バックグラウンド再生 | AVAudioSession による常時再生 |
| インタースティシャル広告 | 4曲以上再生かつ前回から3分以上経過した場合に表示（課金済みは非表示） |

**スピードシートのスナップポイント（34段階）:**  
0.5, 0.6, 0.7, 0.75, 0.8, 0.9, 1.0, 1.1, 1.2, 1.25, 1.3, 1.4, 1.5, 1.6, 1.7, 1.75, 1.8, 1.9,  
2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0, 7.0, 8.0, 10.0, 15.0, 20.0, 30.0, 40.0, 50.0

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

### Tab 1: スキャン（scanViewController）

**役割:** OCR テキスト取得（歌詞スキャン用）

| 機能 | 実装詳細 |
|------|----------|
| OCRスキャン | カメラ撮影 → Google Vision API → テキスト抽出 |
| テキスト翻訳 | 日本語・英語・中国語に対応 |
| 翻訳結果表示 | セグメント切り替え（原文 / 翻訳後） |
| 歌詞編集モード | 再生中の曲の歌詞をテキストエリアで編集・CoreData 保存 |
| 翻訳回数制限 | Reward 広告を見ると翻訳回数（5回）補充 |

---

### Tab 2: 設定（SettingViewController）

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

### Tab 3: 発見（DiscoverViewController）

**役割:** 世界のiTunesランキング閲覧とYouTube検索

| 機能 | 実装詳細 |
|------|----------|
| iTunesランキング | 8カ国（🇺🇸🇬🇧🇯🇵🇰🇷🇨🇳🇹🇭🇪🇸🇹🇷）の最新Top50 |
| ランキング種別 | 楽曲 / ミュージックビデオ切り替え |
| 読み込みUX | スケルトン+シマーアニメーション（Instagram風）|
| YouTube検索 | WKWebView内でYouTube検索、動画URLを検出して専用プレイヤーへ遷移 |
| 国設定保存 | UserDefaultsで選択国を永続化 |

---

### Tab 4: 練習（PracticeViewController）

**役割:** 語学・音楽練習のダッシュボード。再生中の曲をもとに各練習モードへ案内する。

| 機能 | 実装詳細 |
|------|----------|
| 再生中カード | 現在再生中の曲名・アーティスト・アートワークを常時表示。タップで再生/一時停止 |
| 速度プリセット | 水平スクロール。0.5x〜50x のプリセットをタップで即時変更 |
| 機能グリッド（2列） | 区間リピート・フラッシュカード・弱点単語リスト |
| ディクテーションカード | 歌詞の有無でCTAが変化。「ディクテーション開始」「テキストを準備する」「字幕を入力する」 |
| 練習履歴 | 連続日数・週間ドット・月次バーチャート・最近のセッション |

**遷移先:**
- 区間リピート → `SectionRepeatViewController`
- フラッシュカード → `FlashCardViewController`
- 弱点単語 → `WeakWordListViewController`
- ディクテーション開始 → `DictationViewController`
- テキスト準備 → `DictationSetupViewController`（音楽ルート）
- 字幕入力 → `DictationSetupViewController`（YouTubeルート）
- 練習履歴詳細 → `PracticeHistoryViewController`

---

### Tab 4 → テキスト準備（DictationSetupViewController）

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

### Tab 4 → 区間リピート（SectionRepeatViewController）

**役割:** 曲の特定区間をループ再生する練習画面

| 機能 | 実装詳細 |
|------|----------|
| 区間指定 | `RangeTrackView`（カスタムビュー）で開始・終了ハンドルをドラッグ |
| ループ再生 | `HighSpeedAudioPlayer` で区間をループ。ループON/OFFボタン |
| 再生位置表示 | 経過時間・総時間・現在位置バー |
| 曲情報カード | アートワーク・タイトル・アーティスト表示 |

---

### Tab 4 → ディクテーション（DictationViewController）

**役割:** 歌詞の穴埋め練習（リスニング → 書き取り）

| 機能 | 実装詳細 |
|------|----------|
| 出題 | 歌詞を行単位でランダム出題。空白マスク表示 |
| 言語フィルタ | `selectedLyricLang` 指定時は該当言語の行のみ出題 / 未指定時は支配的言語を自動検出 |
| 音声読み上げ | `AVSpeechSynthesizer`（TTS）で出題文を読み上げ（言語自動切り替え） |
| 音声入力（回答） | `SFSpeechRecognizer` でマイク入力 → テキスト変換 |
| 正誤判定 | 入力テキストと正解を比較。スコア集計（パーセント表示） |
| 弱点登録 | 不正解単語を `WeakWordService` へ自動追加 |
| ミニプレイヤー | 練習中も元の楽曲を再生可能 |
| 結果表示 | `DictationResultViewController` でスコア・正解一覧を表示 |

---

### Tab 4 → フラッシュカード（FlashCardViewController）

**役割:** 歌詞から自動生成した単語カードで語彙練習

| 機能 | 実装詳細 |
|------|----------|
| 単語抽出 | `NLTokenizer` で歌詞から品詞フィルタ（名詞・動詞・形容詞） |
| 翻訳 | iOS 18+ ネイティブ翻訳API |
| カードUI | 表（原語）→タップ→裏（翻訳）のフリップアニメーション |
| 進捗表示 | プログレスバー |
| 弱点登録 | 「もう一度」タップで `WeakWordService` へ追加 |
| 言語対応 | `NLLanguageRecognizer` で自動判定（英語・日本語・中国語等） |

---

### Tab 4 → 弱点単語リスト（WeakWordListViewController）

**役割:** ディクテーション不正解・フラッシュカード「もう一度」で蓄積した苦手単語の管理

| 機能 | 実装詳細 |
|------|----------|
| 一覧表示 | 蓄積した弱点単語を一覧表示 |
| 個別削除 | 単語単位で削除 |
| 全削除 | 全件一括削除 |
| フラッシュカード練習 | リストから直接 `FlashCardViewController` に移行 |

---

### Tab 4 → 練習履歴（PracticeHistoryViewController / PracticeHistoryService）

**役割:** 練習の継続状況を可視化してリテンションを促進

| 機能 | 実装詳細 |
|------|----------|
| 連続日数（ストリーク） | 連続練習日数をバッジ表示 |
| 週間ドット | 直近7日の練習有無をドットで表示 |
| 月次バーチャート | 月ごとの練習回数をバーで可視化 |
| 最近のセッション | 直近の練習セッション一覧 |

---

## 4. サービス層・ユーティリティ

| クラス | 役割 |
|--------|------|
| `HighSpeedAudioPlayer` | AVAudioEngine ベースの音楽再生エンジン。0.5x〜50x 速度変更対応。`_generation` カウンタで二重発火防止 |
| `WhisperKitService` | オンデバイス Whisper AI 文字起こし。チャンク分割・沈黙分割・多言語対応・重複除去 |
| `TranscriptionService` | WhisperKit のラッパー。16kHz モノラル変換・チャンク処理・多言語ベスト選択 |
| `YouTubeCaptionService` | InnerTube API + WKWebView フォールバックで YouTube 字幕を自動取得 |
| `YoutubeCaptionStore` | 動画IDをキーに字幕テキストを UserDefaults に永続化 |
| `LyricsService` | CoreData への歌詞保存・取得。メモリキャッシュも同期 |
| `WeakWordService` | 弱点単語の永続化・取得・削除 |
| `PracticeHistoryService` | 練習セッションの記録・集計（連続日数・週間/月次統計） |
| `DemoDataSeeder` | シミュレータ起動時にサイン波デモ音声4曲を自動生成してデモライブラリ登録 |
| `SampleDataSeeder` | 実機・シミュレータ共通の初回起動サンプルデータ生成 |

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
var speedRow: Int                  // 再生速度インデックス（0〜33 → 34スナップポイント対応）
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
| YouTube InnerTube API | 字幕自動取得（`YouTubeCaptionService`） |
| iTunes RSS API | ランキング（発見タブ） |
| Google Vision API | OCR（スキャンタブ） |
| WhisperKit（オンデバイス） | 音声文字起こし（`WhisperKitService`） |
| Firebase Analytics | 行動ログ（10画面・15+カスタムイベント） |
| Firebase Cloud Messaging | プッシュ通知 |
| Firebase Remote Config | 機能フラグ・AD設定 |
| Firebase Crashlytics | クラッシュ解析 |
| Google AdMob | 広告（バナー・ネイティブ・インタースティシャル・Reward） |
| Five / AppVador | サブ広告ネットワーク |
| SwiftyStoreKit | アプリ内課金 |
| Vision Framework | スクショOCR（`DictationSetupViewController` / `CaptionTextEditorViewController`） |
| Speech Framework | 音声入力（ディクテーション回答） |
| AVSpeechSynthesizer | TTS 読み上げ（ディクテーション出題） |
| iOS 18 翻訳API | フラッシュカード翻訳（iOS 18以上のみ） |

---

## 8. Firebase Analytics 実装状況

**計測画面（10画面）**: home / player / practice / settings / dictation_setup / dictation / section_repeat / flash_card / weak_words / speed_sheet

**カスタムイベント**: play_tap / stop_tap / next_track / prev_track / speed_change / speed_sheet_open / shuffle_toggle / repeat_toggle / section_repeat_toggle / section_repeat_save / dictation_start / flash_card_start / onboarding_complete / song_add / ad_interstitial_show

---

## 9. 現状の UX 課題

### 9-A. 初見ユーザーの導線が不明確

- `OnboardingViewController` は実装済みだが、表示条件・起動タイミングの詰めが必要
- ホームタブで「まず何をすべきか」が空状態では分かりにくい（空状態UIは未実装）

### 9-B. 練習タブと再生タブの連携

- 練習タブは「再生中の曲」に依存するが、曲が未再生のときのUXが不完全（アラートのみ）
- ディクテーション終了後に元の曲・ライブラリへ自然に戻れる経路がない

### 9-C. 再生画面の新旧UI混在

- 旧実装と新実装（SpeedSheet・RegionRepeatSheet）が共存しており、コードが散在
- `PlayMusicViewController.swift` 本体のリファクタリングが未完

### 9-D. スキャンタブの役割の曖昧さ

- `scanViewController` は OCR スキャンと歌詞編集という異なる機能が同居
- 練習タブに歌詞準備機能（WhisperKit OCR）が追加されたため、スキャンタブの存在意義が薄れている

### 9-E. Apple Music 楽曲の再生未対応

- `HighSpeedAudioPlayer`（AVAudioFile + AVAudioEngine）は FairPlay DRM により Apple Music トラックを再生できない
- 現状は端末内楽曲のみ対応

### 9-F. 状態管理の複雑さ（開発上の問題）

- グローバル変数が30以上存在し、画面間の状態共有が追いにくい
- 同じロジック（キーボード管理・広告ロード）が複数画面に重複実装
