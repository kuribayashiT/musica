# musica アプリ仕様書 v5.1.5

最終更新: 2026-05-14

---

## 1. アプリ概要

**musica** は「好きな曲で語学学習できる音楽プレイヤー」。  
音楽再生・高速再生・ディクテーション・フラッシュカードなどを1つのアプリに統合し、  
エンタメと学習を切り離さないコンセプトで設計されている。

| 項目 | 内容 |
|---|---|
| 対応OS | iOS 13以降 |
| 言語 | 日本語・英語（多言語対応 `Localizable.strings`） |
| 収益モデル | サブスクリプション月額500円（広告削除）＋AdMob広告 |
| 主要フレームワーク | AVFoundation, NaturalLanguage, Firebase, GoogleMobileAds, SDWebImage, WhisperKit |

---

## 2. タブ構成

| タブ | ViewController | 役割 |
|---|---|---|
| ホーム | HomeAreaViewController | ライブラリ一覧・楽曲選択 |
| 発見 | DiscoverViewController | iTunesランキング + YouTube検索 |
| 練習 | PracticeViewController | 学習ダッシュボード |
| 設定 | SettingViewController | 各種設定・サブスク管理 |

---

## 3. 機能詳細

### 3-1. 音楽プレイヤー（PlayMusicViewController）

| 機能 | 詳細 |
|---|---|
| 再生エンジン | `HighSpeedAudioPlayer`（AVAudioEngine ベース） |
| 速度範囲 | **0.5x 〜 50x**（対数スケール）|
| 速度制御方式 | ≤8x: `AVAudioUnitTimePitch`（ピッチ保持）<br>>8x: timePitch 8x固定 + `AVAudioUnitVarispeed`（最大6.25x）|
| 速度変更UI | ボトムシート（スライダー＋プリセット）/ 練習タブカード |
| 自動次曲再生 | `onFinish` クロージャ方式（`_generation`カウンタで二重発火防止）|
| リピートモード | オフ / 1曲リピート / 全曲リピート |
| シャッフル | 有効/無効切り替え |
| 歌詞表示 | 再生中にスクロール表示・フォントサイズ調整可 |
| 区間リピート | 任意のIN/OUTPOINTをリアルタイム設定してループ |
| セグメント制御 | コンテンツ / 歌詞 表示切り替え |

**スピードシートのスナップポイント（34段階）**:  
0.5, 0.6, 0.7, 0.75, 0.8, 0.9, 1.0, 1.1, 1.2, 1.25, 1.3, 1.4, 1.5, 1.6, 1.7, 1.75, 1.8, 1.9,  
2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0, 7.0, 8.0, 10.0, 15.0, 20.0, 30.0, 40.0, 50.0

---

### 3-2. ライブラリ管理（CustamMusicLibraryRegisterViewController）

- 端末内楽曲をライブラリとしてグループ化して管理
- ライブラリごとに曲リスト・アートワークを表示
- 楽曲追加時に Firebase に `song_add` イベント送信（登録曲数パラメータ付き）

---

### 3-3. 発見タブ（DiscoverViewController）

| 機能 | 詳細 |
|---|---|
| iTunesランキング | 8カ国（US/GB/JP/KR/CN/TH/ES/TR）の最新Top50 |
| ランキング種別 | 楽曲 / ミュージックビデオ切り替え |
| 読み込みUX | **スケルトン+シマーアニメーション**（Instagram風） |
| YouTube検索 | WKWebView内でYouTube検索、動画URLを検出して専用プレイヤーへ遷移 |
| 国設定保存 | UserDefaultsで選択国を永続化 |

**シマーの実装**:
- 1つの `CAGradientLayer`（セル幅の3倍）を `CALayer` マスク（各プレースホルダー形状）でクリップ
- `transform.translation.x` アニメーションで左→右スライド（全パーツでピクセル速度一定）
- `needsShimmer` フラグで bounds確定前の初回表示を確実に処理

---

### 3-4. 練習ダッシュボード（PracticeViewController）

再生中の曲と連携した4つの練習モードへのエントリポイント。

| カード | 内容 |
|---|---|
| 今すぐ再開 | 再生中曲のアートワーク＋前/後/再生コントロール |
| ディクテーション | 歌詞の有無で状態が変わるCTAカード |
| 練習モードグリッド | 区間リピート・フラッシュカード・弱点単語リスト |
| 速度コントロール | スライダー＋プリセットピル（0.5x〜50x） |
| 練習履歴 | 連続日数・週間ドット・月次バーチャート・最近のセッション |

---

### 3-5. ディクテーション（DictationSetupViewController / DictationViewController）

**セットアップ（DictationSetupViewController）**:

| 機能 | 詳細 |
|---|---|
| 歌詞取得方法 | API自動取得 / OCR（カメラ撮影） / 手動テキスト入力 |
| AI文字起こし | WhisperKit（オンデバイス） / YouTube字幕取得 |
| 言語選択 | 歌詞を解析して検出言語をピル表示。「すべて」or個別選択 |
| 言語フィルタ | `NLLanguageRecognizer` で行ごとに判定 |

**練習本体（DictationViewController）**:

| 機能 | 詳細 |
|---|---|
| 出題形式 | 歌詞の一部を空欄にして聞き取り |
| 言語フィルタ | `selectedLyricLang` 指定時は該当言語の行のみ出題<br>未指定時は歌詞全体から支配的言語を自動検出してフィルタ |
| TTS | `AVSpeechSynthesizer` で問題文を読み上げ（言語自動切り替え）|
| 音声入力 | マイク入力で解答（`SFSpeechRecognizer`）|
| 採点 | 正解率をパーセントで表示 |
| 弱点登録 | 不正解単語を自動的にWeakWordリストへ追加 |
| ミニプレイヤー | 練習中も音楽再生コントロール可 |

---

### 3-6. フラッシュカード（FlashCardViewController）

| 機能 | 詳細 |
|---|---|
| 単語抽出 | `NLTokenizer` で歌詞から品詞フィルタ（名詞・動詞・形容詞）|
| 翻訳 | iOS 18+ ネイティブ翻訳API / フォールバックなし |
| カードUI | 表（原語）→タップ→裏（翻訳）のフリップアニメーション |
| 進捗表示 | プログレスバー |
| 弱点登録 | 「もう一度」タップで WeakWord リストへ追加 |
| 言語対応 | `NLLanguageRecognizer` で自動判定（英語・日本語・中国語等）|

---

### 3-7. 弱点単語リスト（WeakWordListViewController / WeakWordService）

- ディクテーション不正解・フラッシュカード「もう一度」で蓄積
- 一覧表示・個別削除・全削除
- リストから直接フラッシュカード練習に移行可能

---

### 3-8. 区間リピート（SectionRepeatViewController）

- 再生中の任意の箇所をIN/OUT点としてリアルタイム設定
- ループON/OFFスイッチ
- 設定保存時に Firebase `section_repeat_save` イベント送信

---

## 4. 歌詞管理

| 取得方法 | 実装 |
|---|---|
| API取得 | `LyricsService.fetch(title:artist:)` |
| OCR | カメラ撮影 → Vision framework でテキスト認識 |
| AI文字起こし | WhisperKit（端末内推論）|
| YouTube字幕 | `YouTubeCaptionService` |
| 手動入力 | `LyricsTextEditorViewController` |
| 保存先 | CoreData（`MusicModel`） |

---

## 5. 収益・広告

| 種別 | 内容 |
|---|---|
| サブスクリプション | 月額500円（広告削除） |
| バナー広告 | ホーム・設定画面に常時表示（非サブスク時）|
| インタースティシャル | 4曲以上再生 かつ 前回表示から3分以上経過した場合のみ表示 |

---

## 6. Firebase Analytics（詳細は FA_spec.md 参照）

**計測画面（10画面）**: home / player / practice / settings / dictation_setup / dictation / section_repeat / flash_card / weak_words / speed_sheet

**カスタムイベント**: play_tap / stop_tap / next_track / prev_track / speed_change / speed_sheet_open / shuffle_toggle / repeat_toggle / section_repeat_toggle / section_repeat_save / dictation_start / flash_card_start / onboarding_complete / song_add / ad_interstitial_show

---

## 7. オンボーディング（OnboardingViewController）

- 初回起動時に目標（`music` / `youtube` / `earCopy`）を選択
- 完了時に `onboarding_complete` イベント送信

---

## 8. 既知の制限・注意事項

| 項目 | 内容 |
|---|---|
| フラッシュカード翻訳 | iOS 18以上のみ（それ未満は翻訳なし）|
| WhisperKit文字起こし | 初回はモデルダウンロードが発生 |
| 速度50x超 | 技術的上限（timePitch 8x × varispeed 6.25x）|
| 歌詞フィルタ精度 | NLLanguageRecognizer の精度依存（短い行は誤検出あり）|

---

## 9. バージョン履歴（主要変更）

| バージョン | 主な変更 |
|---|---|
| v5.1.5 | 発見タブ スケルトンシマー改善（速度均一化・初回表示修正）<br>ディクテーション 言語未指定時の自動検出フィルタ追加 |
| v5.1.4 | HighSpeedAudioPlayer全面書き直し（50x対応・自動次曲再生修正）<br>AdMob頻度制御実装・Firebase Analytics全画面実装 |
| v5.1.3 | 発見タブ スケルトンローディング初期実装 |
| v5.x以前 | 区間リピート・フラッシュカード・弱点単語・練習履歴 実装 |

---

---

# App Store アピールポイント

## 目玉機能（差別化ポイント）

### 1. 🎵 好きな曲で学べる、唯一の音楽×語学アプリ
教材ではなく「自分の好きな曲」で勉強できる点が最大の差別化。  
洋楽・K-POP・JPOPなど、聴いていて飽きない素材で継続率が高い。

### 2. ⚡ 最大50倍速再生（速聴・耳コピに対応）
- 0.5x〜50x の34段階スナップ
- 8x以下はピッチ保持（聞き取れる速度で）
- 速聴トレーニング・耳コピ・語学シャドーイングに最適
- 競合アプリの多くは最大2x〜4x止まり

### 3. ✍️ ディクテーション（歌詞穴埋め）
- 曲を流しながら聞こえた単語を入力
- 歌詞を複数言語に対応（英語・日本語・韓国語等を自動判別してフィルタ）
- 音声入力で手をキーボードから離しても回答可能
- 不正解ワードを自動で弱点リストへ登録

### 4. 🃏 フラッシュカード（歌詞から単語カード）
- 歌詞をAIが品詞解析して重要単語を自動抽出
- iOS 18のネイティブ翻訳APIで表・裏カード自動生成
- 知っている / もう一度 でわからない単語を記録

### 5. 🔁 区間リピート
- 聞き取れなかったフレーズをIN/OUT点で指定してループ
- 耳コピ・シャドーイング練習の定番操作をシームレスに

### 6. 📊 練習履歴・継続管理
- 連続練習日数（ストリーク）
- 週間・月次チャートで進捗可視化
- 学習の習慣化をアシスト

### 7. 🌍 発見タブ（世界の音楽チャート）
- 8カ国のiTunesランキングをリアルタイム取得
- YouTube検索との統合で素材探しが完結

---

## App Store キャッチコピー案

### メインキャッチ（30文字以内）
```
好きな曲で、語学が伸びる。
```
```
音楽で英語を攻略するアプリ
```
```
聴くだけで終わらせない音楽アプリ
```

### サブコピー（概要欄冒頭）
```
洋楽・K-POPを聴きながら、英語・韓国語が身につく。
ディクテーション・フラッシュカード・区間リピートを搭載した、
語学学習特化の音楽プレイヤーです。
```

### 機能別キャッチ
| 機能 | キャッチ |
|---|---|
| 高速再生 | 最大50倍速で、耳を鍛える |
| ディクテーション | 歌詞の穴埋めで、リスニング力UP |
| フラッシュカード | 歌詞から単語カードを自動生成 |
| 区間リピート | 聞き取れないフレーズを、何度でも |
| 発見タブ | 世界8カ国のチャートから素材を探す |

### ターゲット別メッセージ
| ターゲット | メッセージ |
|---|---|
| 英語学習者 | 教材は要らない。好きな洋楽が最高のテキストになる。 |
| 速聴ユーザー | 0.5x〜50xの速度変更。シャドーイングから超高速再生まで。 |
| K-POP好き | 韓国語歌詞を自動判別。K-POPで韓国語を学ぼう。 |
| 耳コピ勢 | 区間リピート×高速/低速で、完コピへの最短ルート。 |
