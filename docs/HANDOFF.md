# Dictate-macOS — Handoff

## Current State
- **Version**: 1.0.0 (development)
- **Build**: swift build (SPM) + Makefile for .app bundle
- **Tests**: 104 tests, 10 suites, all passing
- **Install**: `make install` → /Applications/Dictate.app
- **Release build warnings**: Zero

## Architecture
- Pure AppKit lifecycle (main.swift + AppDelegate + NSStatusItem)
- @Observable AppState split across 4 files (263 + 231 + 66 + 17 lines)
- DeepgramService as Swift actor
- TranscriptionServiceProtocol for DI
- NSEvent-based escape monitoring (recording only)

## Recent Changes (2026-03-26)
- Ultimate Review (11-agent): 27+ issues fixed across 12 commits
- CRITICAL: API key moved from URL param to x-goog-api-key header
- CRITICAL: KeychainService documented as plaintext UserDefaults
- AppState split into Extension files (God Object remediation)
- DeepgramService converted to actor (was @unchecked Sendable + NSLock)
- All Sendable warnings eliminated
- Test coverage improved (97→104)
- Escape key bug fixed (was captured globally, now recording-only)

## Known Issues / Tech Debt
- KeychainService uses UserDefaults (plaintext) — needs Keychain migration after proper code signing
- SUPublicEDKey in Info.plist is PLACEHOLDER — needs real Ed25519 key for Sparkle updates
- No E2E / UI tests for macOS-specific features (AudioRecorder, TextInput, Overlay)
- AppState not yet @MainActor annotated (works via DispatchQueue.main.async)

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

## How to Build & Run
```bash
swift build                    # Debug build
swift test                     # Run 104 tests
make bundle                    # Create .app bundle
make install                   # Install to /Applications
open /Applications/Dictate.app # Launch
```

## Next Steps
- [ ] Proper code signing (Developer ID) + Keychain migration
- [ ] Generate Ed25519 key pair for Sparkle auto-updates
- [ ] @MainActor annotation for AppState
- [ ] E2E test coverage for recording flow
