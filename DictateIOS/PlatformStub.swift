// Stub entry point for non-iOS platforms.
// The real @main is in DictateIOSApp.swift, guarded with #if os(iOS).
// This stub prevents linker errors when building on macOS.
#if !os(iOS)
@main
enum DictateIOSStub {
    static func main() {
        // This target is iOS-only. Build with Xcode for an iOS destination.
        print("DictateIOS is an iOS target. Build with: xcodebuild -destination 'platform=iOS Simulator'")
    }
}
#endif
