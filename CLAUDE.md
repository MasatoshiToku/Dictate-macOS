# Dictate macOS/iOS

## Build Commands
- `swift build` -- Build all targets (macOS)
- `swift test` -- Run tests (97 tests, 9 suites)
- `make bundle` -- Build .app bundle
- `make install` -- Install to ~/Applications
- `make clean` -- Clean build artifacts

## Architecture
- **DictateCore** -- Shared library (Models, Services, Utilities)
- **Dictate** -- macOS app (MenuBarExtra, NSPanel overlay, onboarding)
- **DictateIOS** -- iOS app (recording + copy to clipboard)
- **DictateTests** -- Tests for DictateCore

### DictateCore (shared cross-platform)
- Models: `AppSettings`, `DictionaryEntry`, `TranscriptionHistory`
- Services: `GeminiService/GeminiServiceManager`, `DeepgramService`, `KeychainService`, `DictionaryService`, `HistoryService`
- Utilities: `TextProcessing`, `WAVBuilder`, `Logger`

### Dictate (macOS app)
- `DictateApp` -- Menu bar app entry point with onboarding window
- `AppState` -- Central state coordinator (idle -> recording -> processing -> typing -> idle)
- Views: `OverlayView` (recording overlay with waveform + duration timer), `SettingsView` (tabs: General, API Keys, Shortcuts, Dictionary, History), `OnboardingView` (first-launch setup)
- Components: `WaveformView`, `StatusDotsView`
- Services: `AudioRecorderService`, `TextInputService`, `OverlayPanelController`, `MigrationService`, `UpdaterService`

### DictateIOS (iOS app)
- `DictateIOSApp`, `ContentView`, `DictationViewModel`, `IOSAudioRecorder`, `IOSSettingsView`, `PlatformStub`

## Key Decisions
- SPM-based project with Makefile for .app bundling
- No Xcode project file -- CLI builds with `swift build`
- **Info.plist must be embedded in the binary via linker flags** (`-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Dictate/Info.plist`). SPM executables don't automatically read Info.plist from the .app bundle; macOS requires the plist in the Mach-O `__TEXT.__info_plist` section for LSUIElement and other keys to take effect.
- Sparkle.framework must be bundled in .app/Contents/Frameworks/
- Non-sandboxed (requires Accessibility for CGEvent text input)
- Gemini API for transcription (primary), Deepgram for real-time interim text
- Custom dictionary support for specialized vocabulary correction
- Auto-update via Sparkle framework
- First-launch onboarding window for API key setup

## Notes
- SourceKit shows false positives for cross-module types -- `swift build` is the truth
- Deepgram audio: PCM Int16, 16kHz, mono (must match URL params)
- Recording auto-stops after 120 seconds (configurable in AppState)
- Recording overlay shows real-time waveform, interim transcript, and elapsed duration
- Push-to-talk and toggle recording modes supported
- Electron -> Native migration handled by MigrationService
