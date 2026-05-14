# musica アプリ仕様書 & ユーザー獲得改善提案

> 更新日: 2026-04-29 （バージョン 4.2.65 時点）

---

## アプリ概要

**コンセプト**: iPhone の音楽ライブラリ管理 × YouTube お気に入り動画 × 歌詞・練習 をひとつにまとめた音楽総合アプリ

**ターゲットユーザー**: 音楽を能動的に楽しむ人（カラオケ練習・語学リスニング・耳コピ・楽器練習）

---

## 画面構成（タブ5本）

| タブ | 画面名 | 主な機能 |
|------|--------|---------|
| Home | ライブラリ一覧 | カスタムライブラリ管理・お気に入り動画リスト |
| 練習 | 練習ダッシュボード | 速度プリセット・区間リピート・ディクテーション |
| 検索 | YouTube検索 | キーワード検索・急上昇ワード・お気に入り登録 |
| スキャン | OCR/翻訳 | 歌詞スキャン・翻訳 |
| 設定 | 設定 | テーマ・課金管理・通知 |

---

## 機能一覧

### 🎵 ライブラリ管理（Home）
- カスタムライブラリの作成 / リネーム / 削除 / 並べ替え
- ライブラリ内への曲追加・削除（iOS ミュージックライブラリから）
- 再生中インジケーター表示（ネイティブ波形アニメーション）

### 📹 お気に入り動画（Home → お気に入り動画）
- YouTube動画のお気に入り登録
- グリッド表示（2列）
- 並べ替え（長押し → ドラッグ、iOS ホーム風ジグルアニメーション）
- 削除（編集モード中のバツボタン）
- 動画ごとにディクテーション練習・字幕登録が可能

### ▶️ 音楽再生（MusicPlayList → PlayMusic）
- バックグラウンド再生
- 再生速度変更（`SpeedSheetViewController` ボトムシート。プリセット5種 + スライダー）
- 区間リピート（`RegionRepeatSheetViewController` ボトムシート、`RangeTrackView` でドラッグ指定）
- コマンドセンター対応（ロック画面・AirPlay）
- 歌詞表示（タップでアルバムアートと切り替え）
- 文字サイズ設定（7段階）
- シャッフル / リピート（ラベル付き状態表示）

### 🧠 練習機能（練習タブ）— v4.2.x で追加

**ディクテーション（DictationViewController）**
- 歌詞を1行ずつ穴埋めで回答する聴き取り練習
- AVSpeechSynthesizer（TTS）で問題文を読み上げ
- SFSpeechRecognizer でマイク入力して採点
- 練習中もミニプレイヤーで音楽再生可能

**テキスト準備（DictationSetupViewController）**
- WhisperKit（オンデバイス AI）で音声を自動文字起こし
- スクリーンショット OCR（Vision Framework、複数枚対応）
- YouTube字幕自動取得（InnerTube API + WKWebView フォールバック）
- 言語指定（日本語 / 英語 / 中国語 / 韓国語 / 自動）

**区間リピート（SectionRepeatViewController）**
- RangeTrackView でドラッグして開始・終了点を指定
- AVAudioPlayer による指定区間のループ再生

**速度プリセット（PracticeViewController）**
- 0.5x〜2.0x の9段階を横スクロールでワンタップ切り替え
- 現在の速度をカードでハイライト表示

### 📝 歌詞登録フロー
1. 練習タブのディクテーションカード → 「テキストを準備する」
2. 取得方法を選択（WhisperKit 文字起こし / OCR / YouTube字幕 / 手入力）
3. `LyricsTextEditorViewController` でテキストを確認・編集
4. 「保存」→ `LyricsService.saveFetchedLyrics` で CoreData + メモリキャッシュに保存

### 🎬 YouTube字幕入力（CaptionTextEditorViewController）
- お気に入り動画の字幕なし動画で表示される「字幕を入力する」ルート
- YouTube アプリ連携（字幕取得手順ガイドカード）
- スクリーンショット OCR（複数枚を上から順に追記）
- 入力テキストをレビュー・保存

### 🔍 YouTube検索（Search タブ）
- キーワード検索（複数ジャンル対応）
- 人気動画ピックアップ
- 急上昇ワード表示
- 検索結果からお気に入り登録

### 📷 OCR・翻訳（スキャンタブ）
- カメラ撮影 → Google Vision API でテキスト抽出
- 日本語・英語・中国語に翻訳
- 翻訳残回数表示

### 🚀 オンボーディング（OnboardingViewController）
- 3ステップ（Welcome → ゴール選択 → 使い方説明）
- ゴール：カラオケ練習 / 語学リスニング / 耳コピ
- 初回起動時に表示

### 💰 マネタイズ
- AdMob（バナー・ネイティブ・インタースティシャル・Reward広告）
- Reward広告：文字起こし前・翻訳残回数補充に使用
- 月額サブスク：広告削除

---

## 技術スタック

| 領域 | 使用技術 |
|------|---------|
| 言語 | Swift (UIKit) |
| データ永続化 | CoreData |
| 音楽再生 | AVFoundation, MPNowPlayingInfoCenter |
| 動画再生 | YoutubePlayer-in-WKWebView |
| AI 文字起こし | WhisperKit（オンデバイス Whisper） |
| OCR | Vision Framework（ローカル）, Google Vision API（クラウド） |
| 音声認識 | SFSpeechRecognizer（ディクテーション回答用） |
| TTS | AVSpeechSynthesizer |
| YouTube字幕 | InnerTube API + WKWebView フォールバック |
| 広告 | Google Mobile Ads (AdMob), Five, AppVador |
| 分析 | Firebase Analytics |
| クラッシュ解析 | Firebase Crashlytics |
| リモート設定 | Firebase Remote Config |
| 画像 | SDWebImage |
| 通信 | Alamofire |
| UI拡張 | SWTableViewCell, RAMAnimatedTabBar, DGElasticPullToRefresh, Instructions |

---

## デザインシステム

| トークン | 用途 |
|---------|------|
| `AppColor.accent` | テーマカラー（ボタン・選択状態） |
| `AppColor.background` | 画面背景 |
| `AppColor.surface` | カード・セル背景 |
| `AppColor.surfaceSecondary` | 第2サーフェス |
| `AppColor.textPrimary` | メインテキスト |
| `AppColor.textSecondary` | サブテキスト |
| `AppColor.separator` | 区切り線 |
| `AppFont.headline` | セル見出し（17pt Semibold） |
| `AppFont.footnote` | 補足テキスト（13pt Regular） |
| `AppFont.caption` | バッジ・小ラベル（12pt Regular） |

ナビゲーションバー: glassmorphism（`UIBlurEffect .systemMaterial` + 透過背景）

---

## ユーザー獲得・改善提案

### 1. 【実装完了】コア体験の磨き込み

v4.2.x で「練習特化」の機能を実装済み：
- ディクテーション（WhisperKit文字起こし → 穴埋め練習）
- 区間リピート（専用画面 + ボトムシート）
- 速度プリセット（練習タブでワンタップ切り替え）

**次のアクション**: 実装した機能が App Store スクリーンショット・説明文に反映されていないため、ASO 更新が急務。

---

### 2. App Store 最適化（ASO）

- **スクリーンショット**: 練習タブ・ディクテーション・WhisperKit文字起こしの画面をキャプチャして差し替える
- **キーワード候補**: 「カラオケ練習」「速度変更」「区間リピート」「歌詞表示」「語学リスニング」「耳コピ」「ディクテーション」「文字起こし」
- **タイトル/サブタイトル案**: `musica - 耳コピ・カラオケ練習プレイヤー`

---

### 3. サブスクの価値向上

**問題**: 現状は「広告を消すだけ」のサブスク。

**改善案:**

| プラン | 価格 | 内容 |
|--------|------|------|
| Free | 無料 | 広告あり。ディクテーションは Reward広告要 |
| Pro | 月額480円 or 年額2,400円 | 広告なし＋ディクテーション無制限＋高精度モデル（WhisperKit Large）解放＋テーマ全解放 |

WhisperKit の高精度モデル（Large）を Pro 限定にすることで、「使ってみたら手放せない」有料機能になる。

---

### 4. リテンション改善

| 改善 | 期待効果 | 状況 |
|------|---------|------|
| オンボーディング改善 | 離脱率低下 | `OnboardingViewController` 実装済み。表示条件の最終調整が残る |
| 練習の継続促進 | DAU 向上 | 練習履歴・連続日数バッジなどの実装が未着手 |
| ウィジェット対応 | ホーム画面に常駐 | 未実装 |
| Spotlight サーチ対応 | 曲名から直接起動 | 未実装 |

---

### 5. SNS流入・口コミ設計

- **シェア機能**: 「○○を区間リピートで練習中！」という練習シェアカード（SNS向け画像生成）
- **レビュー誘導**: ディクテーション初回クリア or 3回目練習後（成功体験の直後）
- **デモ動画**: 「WhisperKitで自動文字起こし → ディクテーション練習」のフローは TikTok / Reels で訴求しやすい

---

## 優先度ロードマップ

```
✅ 完了
  ① デザインシステム（AppColor / AppFont）導入
  ② 速度選択をボトムシートに移行（SpeedSheetViewController）
  ③ 区間リピートを専用画面に分離（SectionRepeatViewController）
  ④ 練習タブ追加（PracticeViewController）
  ⑤ WhisperKit オンデバイス文字起こし
  ⑥ ディクテーション機能（DictationViewController）
  ⑦ YouTube字幕取得（CaptionTextEditorViewController）
  ⑧ オンボーディング画面（OnboardingViewController）
  ⑨ デバッグログをリリースビルドから除去
  ⑩ キーボード表示時のレイアウト崩れ修正（練習タブ・字幕入力）
  ⑪ 歌詞保存フローのバグ修正（dismiss → onSave の順序）

🔴 すぐやる（収益・評価に直結）
  A. App Store スクリーンショット更新（新機能を全面に出す）
  B. ASO（キーワード・説明文見直し）
  C. オンボーディング表示条件の確認・調整

🟡 3ヶ月以内（収益改善）
  D. サブスクプランの価値向上（WhisperKit Large モデル解放など）
  E. 練習履歴・連続日数バッジ（リテンション）
  F. PlayMusicViewController のコードリファクタリング（新旧UI統合）

🟢 半年以内（成長施策）
  G. ウィジェット対応
  H. 練習シェアカード機能
  I. Spotlight サーチ対応
  J. スキャンタブの役割見直し（練習タブへの統合 or 削除）
```
