# musica 実装予定バックログ

最終更新: 2026-05-17

---

## Apple Music 楽曲の再生対応

### 背景・課題

現在、ホームタブのライブラリに Apple Music の楽曲（サブスクリプション曲）が表示されるが、再生できない。

**原因：**  
アプリは `HighSpeedAudioPlayer`（= `AVAudioFile` + `AVAudioEngine`）で再生している。  
Apple Music トラックは **FairPlay DRM** により `assetURL` が `nil` になるか、`AVAudioFile` での読み込みが失敗する。  
Apple Music トラックは `MPMusicPlayerController` 経由でのみ再生可能。

---

### 判定方法

`MPMediaItem` の `hasProtectedAsset` プロパティで判定する。

```swift
let isAppleMusic = mediaItem.hasProtectedAsset  // true → Apple Music DRM トラック
```

---

### 実装方針

#### フェーズ 1：再生対応（最小実装）

| 対象 | 実装内容 |
|---|---|
| `MusicController.playMusic()` | `playData.isCloudItem == true` の場合、`MPMusicPlayerController.applicationQueuePlayer` で再生するパスを追加 |
| `PlayMusicViewController` | `audioPlayer` が nil のケース（Apple Music）でも UI を動作させる（再生中フラグ、シークバー、停止ボタン） |
| シークバー | `MPMusicPlayerController.currentPlaybackTime` を `Timer` でポーリングして進捗を反映 |
| 速度変更ボタン | Apple Music トラックでは `MPMusicPlayerController.currentPlaybackRate`（0.5〜2.0 倍）で対応。AVAudioEngine の高精度速度変更は不可のため UI 上で明示 |
| WhisperKit ボタン（ディクテーション） | Apple Music トラック選択中は無効化・グレーアウト（生音声データ取得不可のため） |
| 区間リピート | `currentPlaybackTime` のタイマー監視で疑似的に実装（精度はやや劣る） |

**変更対象ファイル（想定）：**
- `musica/util.swift` — `MusicController.playMusic()` に分岐追加
- `musica/PlayMusicViewController.swift` — Apple Music モード時の UI 制御
- `musica/PlayMusicViewControllerNewUI.swift` — 新 UI への同期
- `musica/TrackData.swift`（または `define.swift`）— `isCloudItem` / `hasProtectedAsset` フラグ確認

---

#### フェーズ 2：歌詞自動取得（MusicKit 連携）

Apple Music トラックには Apple のサーバー上に歌詞データが存在する場合が多い。  
`MPMediaItemPropertyLyrics` はローカルタグのみ返すため別 API が必要。

| 対象 | 実装内容 |
|---|---|
| MusicKit 追加 | `import MusicKit` を追加（iOS 15+）。`MusicAuthorization.request()` で権限取得 |
| 楽曲の識別 | `MPMediaItem.persistentID` → `MusicItemID` に変換して `MusicCatalogResourceRequest<Song>` を投げる |
| 歌詞取得 | `Song.lyrics`（プレーンテキスト）を取得し、musica の歌詞フィールド（`TrackData.lyric`）にセット |
| 取得タイミング | Apple Music トラック選択時に非同期取得。取得完了後に歌詞エリアを更新 |
| フォールバック | 歌詞取得失敗 or 歌詞なしの場合は「歌詞が登録されていません」の空状態 UI を表示（既存実装） |

**変更対象ファイル（想定）：**
- `musica/LyricsService.swift` — MusicKit での歌詞取得ロジック追加
- `musica/CustomMusicLibraryAlbumViewController.swift` — Apple Music トラック取り込み時に `hasProtectedAsset` を保存
- `musica/PlayMusicViewControllerNewUI.swift` — 歌詞エリア更新

---

### 機能比較（実装後）

| 機能 | 端末内音楽 | Apple Music |
|---|---|---|
| 再生 | ✅ AVAudioEngine | ✅ MPMusicPlayerController |
| 速度変更 | ✅ 高精度 | ⚠️ 0.5〜2.0 倍のみ |
| 区間リピート | ✅ 精密 | ⚠️ タイマー監視で疑似実装 |
| シークバー | ✅ | ✅ |
| WhisperKit 音声抽出 | ✅ | ❌ 無効化 |
| 歌詞自動取得 | ❌（手動登録） | ✅ MusicKit（フェーズ2） |
| アートワーク | ✅ | ✅ |

---

### 必要な権限・設定

- `NSAppleMusicUsageDescription`（Info.plist）— すでに存在する可能性あり、要確認
- MusicKit の場合: Xcode の Capabilities → MusicKit を有効化
- Apple Developer Portal でアプリに MusicKit エンタイトルメント追加

---

### 優先度・依存関係

- フェーズ 1 は独立して実装可能
- フェーズ 2 は iOS 15+ 限定（`MusicKit` の制約）。フェーズ 1 の完了後に着手
- フェーズ 2 は Apple Music サブスクリプション未加入ユーザーへの影響なし（DRM フラグで分岐するため）
