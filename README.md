# Dictate (macOS Native)

macOS向けAI音声ディクテーションアプリ。話した内容をAIが自動でテキスト化・整形し、アクティブなアプリに直接入力します。

ネイティブSwift/SwiftUIで構築された軽量なmacOSメニューバーアプリです。

## 機能

- **音声録音** — Option+Spaceで録音開始/停止
- **AI文字起こし** — Gemini APIで音声をテキスト化
- **テキスト整形** — フィラーワード除去、句読点挿入、文法修正
- **リアルタイムプレビュー** — Deepgramによる録音中のプレビュー表示
- **アクティブアプリに入力** — 文字起こし結果を直接入力
- **カスタム辞書** — 特定の単語変換ルール
- **文字起こし履歴** — 過去の結果を検索・管理
- **グローバルショートカット** — カスタマイズ可能
- **自動アップデート** — Sparkle経由

## 動作要件

- macOS 14.0+
- Gemini API Key（必須）
- Deepgram API Key（オプション、リアルタイムプレビュー用）

## ビルド

```bash
# 依存関係解決 + ビルド
swift build

# デバッグ実行
swift run

# リリースビルド
swift build -c release

# .appバンドル作成
make bundle

# テスト
swift test
```

## 初期設定

1. アプリ起動後、メニューバーのマイクアイコンをクリック
2. Settings > API Keys でGemini API Keyを設定
3. システム設定 > プライバシーとセキュリティ > マイク でDictateを許可
4. システム設定 > プライバシーとセキュリティ > アクセシビリティ でDictateを許可

## Tech Stack

- Swift 6 / SwiftUI (macOS 14+)
- AVAudioEngine（音声録音）
- Gemini REST API（文字起こし）
- Deepgram WebSocket API（リアルタイムプレビュー）
- CGEvent + osascript（テキスト入力）
- KeyboardShortcuts（グローバルショートカット）
- Sparkle 2（自動アップデート）
- Security.framework（Keychain APIキー保存）

## License

MIT
