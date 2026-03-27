# Dictate-macOS — Handoff

## Current State
- **Version**: 1.0.0
- **Build**: swift build (SPM) + Makefile for .app bundle / dist pipeline
- **Tests**: 104 tests, 10 suites, all passing
- **Install**: `make install` → /Applications/Dictate.app
- **Release build warnings**: Zero
- **Distribution**: Developer ID署名 + Apple公証 + DMG 構築済み
  - GitHub Release v1.0.0 に DMG アップロード済み
  - `make dist` で署名・公証・DMG作成を一括実行可能
- **Landing page**: dictate-site.vercel.app にダウンロードボタン追加済み
- **Xcode対応**: Package.swift に linkerSettings 追加済み（Xcode からのビルド・実行対応）

## Architecture
- Pure AppKit lifecycle (main.swift + AppDelegate + NSStatusItem)
- @Observable AppState split across 4 files (263 + 231 + 66 + 17 lines)
- DeepgramService as Swift actor
- TranscriptionServiceProtocol for DI
- NSEvent-based escape monitoring (recording only)

## Recent Changes (2026-03-26〜27)
1. **Ultimate Review (11-agent並列)**: CRITICAL 2件 + HIGH 12件 + MEDIUM 20+件を修正（12コミット）
   - CRITICAL: API key → x-goog-api-key header（URLパラメータから移行）
   - CRITICAL: KeychainService の UserDefaults 平文保存をドキュメント化
2. Escape キーバグ修正（録音中のみ NSEvent モニター）
3. @Observable 統一、saveToDisk throws 化
4. テスト増強 97→104
5. AppState God Object 分割（500→263行、Extension 3ファイル）
6. DeepgramService actor 化
7. TranscriptionService DI 導入
8. Sendable 警告ゼロ化
9. **Xcode 対応**: Package.swift に linkerSettings 追加
10. **配布パイプライン構築**: Developer ID 署名 + Apple 公証 + DMG
11. **GitHub Release v1.0.0** 作成・DMG アップロード
12. **dictate-site ダウンロードボタン**更新
13. /Applications へのインストール対応
14. CLAUDE.md 更新

## Known Issues / Tech Debt
- KeychainService uses UserDefaults (plaintext) — needs Keychain migration after proper code signing
- SUPublicEDKey in Info.plist is PLACEHOLDER — needs real Ed25519 key for Sparkle updates
- No E2E / UI tests for macOS-specific features (AudioRecorder, TextInput, Overlay)
- AppState not yet @MainActor annotated (works via DispatchQueue.main.async)
- DMG にApplicationsフォルダへのシンボリックリンクが未追加（ドラッグ&ドロップインストール非対応）

## Key Files
| File | Purpose |
|------|---------|
| Dictate/Models/AppState.swift | Central state coordinator |
| Dictate/Models/AppState+Recording.swift | Recording lifecycle |
| Dictate/AppDelegate.swift | Menu bar setup, windows |
| DictateCore/Services/GeminiService.swift | Gemini API transcription |
| DictateCore/Services/DeepgramService.swift | WebSocket real-time preview |
| Dictate/Services/AudioRecorderService.swift | AVAudioEngine recording |
| Dictate/Services/TextInputService.swift | CGEvent + osascript input |
| Makefile | Build / install / dist pipeline |
| Package.swift | SPM + linkerSettings for Xcode |

## How to Build & Run
```bash
swift build                    # Debug build
swift test                     # Run 104 tests
make bundle                    # Create .app bundle
make install                   # Install to /Applications
make dist                      # Sign + Notarize + DMG (requires Developer ID cert)
open /Applications/Dictate.app # Launch
```

## Next Steps

### 最優先
- [ ] DMG に /Applications へのシンボリックリンクを追加（ドラッグ&ドロップインストーラー）
  - `hdiutil create` で背景画像付き DMG + /Applications symlink
  - Makefile の `dist` ターゲットを更新

### その他
- [ ] Sparkle Ed25519 キーペア生成 + SUPublicEDKey 設定
- [ ] @MainActor annotation for AppState
- [ ] E2E test coverage for recording flow
- [ ] KeychainService — Keychain への移行（コード署名後）
