import AppKit
import Carbon.HIToolbox
import DictateCore
import Foundation
import os

final class TextInputService: Sendable {
    private let logger = Logger(subsystem: "io.dictate.app", category: "TextInput")

    private static let typingDelays: [TypingSpeed: UInt64] = [
        .instant: 0,
        .fast: 10_000_000,     // 10ms in nanoseconds
        .natural: 50_000_000,  // 50ms in nanoseconds
    ]
    private static let chunkSize = 50
    private static let pasteDelayNs: UInt64 = 100_000_000 // 100ms
    private static let clipboardRestoreDelayMs: UInt64 = 500 // Delay before restoring clipboard

    /// Get the name of the currently frontmost application (process name for System Events)
    static func getFrontmostApp() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        let processName = app.localizedName
        return processName
    }

    /// Get the bundle identifier of the currently frontmost application
    static func getFrontmostAppBundleId() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    /// Type text into the currently focused application
    func typeText(_ text: String, speed: TypingSpeed = .fast, targetApp: String? = nil) async throws {
        guard !text.isEmpty else {
            return
        }


        if TextProcessing.requiresClipboard(for: text) {
            try await setClipboardAndPaste(text, targetApp: targetApp)
            return
        }

        // ASCII-only: use CGEvent keystroke simulation (faster than AppleScript)
        let delay = Self.typingDelays[speed] ?? 0

        if speed == .instant && text.count <= 500 {
            try typeCGEventChunk(text)
            return
        }

        // Split into chunks for CGEvent typing
        var index = text.startIndex
        while index < text.endIndex {
            let end = text.index(index, offsetBy: Self.chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[index..<end])
            try typeCGEventChunk(chunk)
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
            index = end
        }
    }

    /// Save current clipboard contents for later restoration
    private func saveClipboard() -> [(NSPasteboard.PasteboardType, Data)] {
        var saved: [(NSPasteboard.PasteboardType, Data)] = []
        guard let items = NSPasteboard.general.pasteboardItems else { return saved }
        for item in items {
            for type in item.types {
                if let data = item.data(forType: type) {
                    saved.append((type, data))
                }
            }
        }
        return saved
    }

    /// Restore previously saved clipboard contents after a delay
    private func restoreClipboard(_ savedItems: [(NSPasteboard.PasteboardType, Data)]) {
        Task {
            try? await Task.sleep(nanoseconds: Self.clipboardRestoreDelayMs * 1_000_000)
            NSPasteboard.general.clearContents()
            for (type, data) in savedItems {
                NSPasteboard.general.setData(data, forType: type)
            }
        }
    }

    /// Paste text from clipboard using Cmd+V via osascript
    func setClipboardAndPaste(_ text: String, targetApp: String? = nil) async throws {

        let savedItems = saveClipboard()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        // Activate target app before pasting
        if let app = targetApp {
            activateApp(named: app)
            // Wait for app activation
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }

        try await Task.sleep(nanoseconds: Self.pasteDelayNs)

        let script = pasteScript(targetApp: targetApp)
        do {
            try runOsascript(script)
        } catch {
            logger.error("[TextInput] Paste via osascript failed: \(error.localizedDescription)")
            throw error
        }

        restoreClipboard(savedItems)
    }

    /// Activate an application by name using NSWorkspace
    private func activateApp(named appName: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.localizedName == appName }) {
            app.activate()
        }
    }

    /// Delete N characters backwards then paste replacement
    func deleteBackwardsAndPaste(charCount: Int, newText: String, targetApp: String? = nil) async throws {
        let savedItems = saveClipboard()

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(newText, forType: .string)

        let batchSize = 10
        let fullBatches = charCount / batchSize
        let remainder = charCount % batchSize

        var script = "tell application \"System Events\"\n"
        if let app = targetApp {
            let safeApp = Self.escapeAppleScript(app)
            script += "  try\n    set frontmost of process \"\(safeApp)\" to true\n  end try\n"
        }
        script += "  delay 0.3\n"

        for _ in 0..<fullBatches {
            script += "  repeat \(batchSize) times\n    key code 51\n  end repeat\n"
            script += "  delay 0.03\n"
        }
        if remainder > 0 {
            script += "  repeat \(remainder) times\n    key code 51\n  end repeat\n"
        }

        script += "  delay 0.15\n"
        script += "  keystroke \"v\" using command down\n"
        script += "end tell"

        try runOsascript(script)

        restoreClipboard(savedItems)
    }

    /// Check if accessibility permission is granted
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permission (shows system dialog)
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Private: CGEvent for ASCII text (fast path)

    /// Type ASCII text using CGEvent (no osascript overhead)
    private func typeCGEventChunk(_ text: String) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        for char in text {
            guard let scalar = char.unicodeScalars.first, scalar.value <= 0x7E else {
                throw TextInputError.nonAsciiInCGEvent
            }
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

            var unichar = UniChar(scalar.value)
            keyDown?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)
            keyUp?.keyboardSetUnicodeString(stringLength: 1, unicodeString: &unichar)

            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Private: osascript via Foundation.Process (safe for non-ASCII)

    /// Run an AppleScript via Foundation.Process("osascript"), which is safe from any thread
    /// and matches the Electron version's execFile("osascript") approach.
    private func runOsascript(_ script: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw TextInputError.osascriptFailed("Failed to launch osascript: \(error.localizedDescription)")
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw TextInputError.osascriptFailed("osascript exited with \(process.terminationStatus): \(errorMessage)")
        }
    }

    private func pasteScript(targetApp: String? = nil) -> String {
        if let app = targetApp {
            let safeApp = Self.escapeAppleScript(app)
            return """
            tell application "System Events"
                try
                    set frontmost of process "\(safeApp)" to true
                end try
                delay 0.3
                keystroke "v" using command down
            end tell
            """
        } else {
            return """
            tell application "System Events"
                delay 0.2
                keystroke "v" using command down
            end tell
            """
        }
    }

    static func escapeAppleScript(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    enum TextInputError: Error, LocalizedError {
        case osascriptFailed(String)
        case nonAsciiInCGEvent

        var errorDescription: String? {
            switch self {
            case .osascriptFailed(let message):
                return "Failed to type text: \(message). Please check accessibility permissions."
            case .nonAsciiInCGEvent:
                return "Non-ASCII character passed to CGEvent path. Use clipboard paste instead."
            }
        }
    }
}
