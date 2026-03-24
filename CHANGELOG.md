# Changelog

## [1.0.0] - 2026-03-24

### Added
- **Core Features**
  - AI voice dictation powered by Gemini 2.5 Flash
  - Real-time transcription preview via Deepgram Nova-3
  - Automatic filler word removal (えっと, あー, etc.)
  - Grammar correction and punctuation insertion
  - Text input to active application (macOS)

- **Recording**
  - Toggle mode (press to start, press to stop)
  - Push-to-Talk mode (hold to record, release to stop)
  - Real-time waveform visualization with RMS computation
  - 120-second recording timeout with auto-stop
  - Smooth waveform decay animation on stop

- **macOS App**
  - Native SwiftUI menu bar application (LSUIElement)
  - Floating overlay panel (non-activating NSPanel)
  - Dynamic menu bar icon (recording/processing/typing states)
  - Global keyboard shortcuts (customizable via KeyboardShortcuts)
  - CGEvent keystroke simulation (ASCII) + clipboard paste (non-ASCII)
  - Clipboard save/restore after paste
  - Sparkle 2 auto-updater
  - Login item support (SMAppService)
  - First-launch onboarding wizard
  - About window
  - Accessibility and microphone permission prompts

- **iOS App**
  - Recording with waveform visualization
  - Copy to clipboard and ShareLink
  - Haptic feedback on transcription completion
  - Transcription history list
  - Setup prompt for first-time users

- **Settings**
  - API key management (Gemini required, Deepgram optional)
  - Secure storage via macOS Keychain
  - Recording mode selection
  - Typing speed (instant/fast/natural)
  - Language selection (Japanese/English/Auto)
  - Keyboard shortcut customization

- **Data Management**
  - Custom dictionary with validation (100 char limit)
  - Transcription history (1000 entry limit, newest-first)
  - Electron version data migration
  - JSON persistence in Application Support

- **Quality**
  - 97 unit/integration tests across 9 suites
  - GitHub Actions CI (build + test on macOS-14)
  - GitHub Actions Release workflow (DMG creation)
  - Gitleaks secret scanning (pre-commit + pre-push)
  - Zero force unwraps
  - Comprehensive error handling with Japanese messages

### Tech Stack
- Swift 6 / SwiftUI (macOS 14+, iOS 17+)
- AVAudioEngine, URLSession, URLSessionWebSocketTask
- KeyboardShortcuts, Sparkle 2, Security.framework
- CGEvent + Process("osascript")
