import ApplicationServices
import os

// MARK: - Permissions
// Internal: used by AppState extensions only

extension AppState {

    // Internal: used by AppState extensions only
    func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            logger.warning("[AppState] Accessibility permission not granted")
        }
    }
}
