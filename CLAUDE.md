# Dictate macOS/iOS

## Build Commands
- `swift build` -- Build all targets (macOS)
- `swift test` -- Run tests (29 tests, 5 suites)
- `make bundle` -- Build .app bundle
- `make install` -- Install to ~/Applications
- `make clean` -- Clean build artifacts

## Architecture
- **DictateCore** -- Shared library (Models, Services, Utilities)
- **Dictate** -- macOS app (MenuBarExtra, NSPanel overlay)
- **DictateIOS** -- iOS app (recording + copy to clipboard)
- **DictateTests** -- Tests for DictateCore

## Key Decisions
- SPM-based project with Makefile for .app bundling
- No Xcode project file -- CLI builds with `swift build`
- Sparkle.framework must be bundled in .app/Contents/Frameworks/
- Non-sandboxed (requires Accessibility for CGEvent text input)

## Notes
- SourceKit shows false positives for cross-module types -- `swift build` is the truth
- Deepgram audio: PCM Int16, 16kHz, mono (must match URL params)
