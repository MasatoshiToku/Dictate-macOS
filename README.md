# Dictate (macOS / iOS)

AI音声ディクテーションアプリ。話した内容をAIが自動でテキスト化・整形します。

macOSではメニューバーアプリとして動作し、アクティブなアプリに直接入力。iOSではスタンドアロンアプリとしてクリップボードにコピーできます。

## プロジェクト構成

Swift Package Manager マルチターゲット構成:

| ターゲット | プラットフォーム | 説明 |
|-----------|---------------|------|
| **DictateCore** | macOS / iOS | 共有ライブラリ (Models, Services, Utilities) |
| **Dictate** | macOS 14+ | メニューバーアプリ (録音 → 文字起こし → テキスト入力) |
| **DictateIOS** | iOS 17+ | iOSアプリ (録音 → 文字起こし → クリップボードコピー) |
| **DictateTests** | any | DictateCoreのユニットテスト |

## 機能

- **音声録音** -- Option+Space(macOS) / タップ(iOS) で録音開始/停止
- **AI文字起こし** -- Gemini APIで音声をテキスト化
- **テキスト整形** -- フィラーワード除去、句読点挿入、文法修正
- **リアルタイムプレビュー** -- Deepgramによる録音中のプレビュー表示
- **アクティブアプリに入力** -- 文字起こし結果を直接入力 (macOS)
- **クリップボードコピー** -- ワンタップでコピー (iOS)
- **カスタム辞書** -- 特定の単語変換ルール
- **文字起こし履歴** -- 過去の結果を検索・管理
- **グローバルショートカット** -- カスタマイズ可能 (macOS)
- **自動アップデート** -- Sparkle経由 (macOS)

## 動作要件

- macOS 14.0+ / iOS 17.0+
- Gemini API Key (必須)
- Deepgram API Key (オプション、リアルタイムプレビュー用)

## ビルド

```bash
# 依存関係解決 + ビルド (macOS)
swift build

# デバッグ実行
swift run

# リリースビルド
swift build -c release

# .appバンドル作成 (macOS)
make bundle

# ~/Applications にインストール
make install

# テスト
swift test
```

iOS版はXcodeで `DictateIOS` スキームを選択してビルドしてください。

## 初期設定

1. アプリ起動後、メニューバーのマイクアイコンをクリック (macOS) / 設定画面を開く (iOS)
2. Settings > API Keys でGemini API Keyを設定
3. システム設定 > プライバシーとセキュリティ > マイク でDictateを許可
4. システム設定 > プライバシーとセキュリティ > アクセシビリティ でDictateを許可 (macOS)

## Tech Stack

- Swift 6 / SwiftUI (macOS 14+ / iOS 17+)
- AVAudioEngine (音声録音)
- Gemini REST API (文字起こし)
- Deepgram WebSocket API (リアルタイムプレビュー)
- CGEvent + osascript (テキスト入力, macOS)
- KeyboardShortcuts (グローバルショートカット, macOS)
- Sparkle 2 (自動アップデート, macOS)
- Security.framework (Keychain APIキー保存)

## License

MIT
