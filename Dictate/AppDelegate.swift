import AppKit
import SwiftUI
import DictateCore

/// NSApplicationDelegate that owns the NSStatusItem (menu bar icon) and AppState.
/// Uses pure AppKit lifecycle (main.swift entry point) instead of SwiftUI App protocol.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: - Shared accessor (used by SettingsView / other views that need appState)
    static weak var shared: AppDelegate?

    // MARK: - Owned state
    let appState = AppState()

    // MARK: - Status item
    private var statusItem: NSStatusItem!

    // MARK: - Menu item references for dynamic updates
    private var recordingMenuItem: NSMenuItem!
    private var errorSeparator: NSMenuItem!
    private var errorLabelItem: NSMenuItem!
    private var dismissItem: NSMenuItem!
    private var transcriptionSeparator: NSMenuItem!
    private var transcriptionItem: NSMenuItem!
    private var copyItem: NSMenuItem!

    // MARK: - Managed windows
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    // MARK: - Application lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // LSUIElement=true in Info.plist handles Dock hiding

        // Set up main menu (required for Cmd+V paste, Cmd+C copy, etc.)
        setupMainMenu()

        // Build the status item
        setupStatusItem()

        // Initialise AppState (registers shortcuts, Gemini, etc.)
        appState.initialize()

        // Show onboarding on first launch
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            openOnboardingWindow()
        }

        // Log shortcut registration status
    }

    // MARK: - Main menu (enables Cmd+V paste in text fields)

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Edit menu (Undo, Cut, Copy, Paste, Select All)
        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status item setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem.button else {
            // This should never happen with a properly created status item
            return
        }
        let img = iconImage(for: appState.status)
        if let img = img {
            img.isTemplate = true
            button.image = img
        }

        // Build and attach the menu
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // "Dictate" header (disabled, bold)
        let headerItem = NSMenuItem(title: "Dictate", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        let headerFont = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        headerItem.attributedTitle = NSAttributedString(
            string: "Dictate",
            attributes: [.font: headerFont]
        )
        menu.addItem(headerItem)

        menu.addItem(.separator())

        // Recording toggle
        recordingMenuItem = NSMenuItem(
            title: recordingTitle,
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        recordingMenuItem.target = self
        recordingMenuItem.isEnabled = !(appState.status == .processing || appState.status == .typing)
        menu.addItem(recordingMenuItem)

        menu.addItem(.separator())

        // Error section (shown conditionally)
        errorSeparator = NSMenuItem.separator()
        errorSeparator.isHidden = true
        menu.addItem(errorSeparator)

        errorLabelItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        errorLabelItem.isEnabled = false
        errorLabelItem.isHidden = true
        menu.addItem(errorLabelItem)

        dismissItem = NSMenuItem(title: "Dismiss", action: #selector(dismissError), keyEquivalent: "")
        dismissItem.target = self
        dismissItem.isHidden = true
        menu.addItem(dismissItem)

        // Last transcription section (shown conditionally)
        transcriptionSeparator = NSMenuItem.separator()
        transcriptionSeparator.isHidden = true
        menu.addItem(transcriptionSeparator)

        transcriptionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        transcriptionItem.isEnabled = false
        transcriptionItem.isHidden = true
        menu.addItem(transcriptionItem)

        copyItem = NSMenuItem(
            title: "Copy Last Result",
            action: #selector(copyLastResult),
            keyEquivalent: ""
        )
        copyItem.target = self
        copyItem.isHidden = true
        menu.addItem(copyItem)

        menu.addItem(.separator())

        // About
        let aboutItem = NSMenuItem(title: "About Dictate", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Settings (Cmd+,)
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for Updates
        let updatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updatesItem.target = self
        updatesItem.isEnabled = appState.updaterService.canCheckForUpdates
        menu.addItem(updatesItem)

        menu.addItem(.separator())

        // Quit (Cmd+Q)
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - NSMenuDelegate — refresh before showing

    func menuWillOpen(_ menu: NSMenu) {
        updateIcon()
        updateDynamicItems()
    }

    // MARK: - Dynamic item helpers

    /// Updates icon in the status bar button to reflect current AppState.status.
    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = iconImage(for: appState.status)
        button.image?.isTemplate = true
    }

    /// Refreshes menu items that depend on mutable AppState properties.
    private func updateDynamicItems() {
        // Recording toggle label and enabled state
        recordingMenuItem.title = recordingTitle
        recordingMenuItem.isEnabled = !(appState.status == .processing || appState.status == .typing)

        // Error section
        if let error = appState.errorMessage {
            errorSeparator.isHidden = false
            errorLabelItem.isHidden = false
            errorLabelItem.title = error
            dismissItem.isHidden = false
        } else {
            errorSeparator.isHidden = true
            errorLabelItem.isHidden = true
            dismissItem.isHidden = true
        }

        // Last transcription section
        let hasTranscription = !appState.lastTranscription.isEmpty
        transcriptionSeparator.isHidden = !hasTranscription
        transcriptionItem.isHidden = !hasTranscription
        copyItem.isHidden = !hasTranscription
        if hasTranscription {
            // Truncate long transcriptions for display
            let display = String(appState.lastTranscription.prefix(120))
            transcriptionItem.title = display
        }
    }

    private var recordingTitle: String {
        appState.status == .recording ? "Stop Recording (⌥Space)" : "Start Recording (⌥Space)"
    }

    // MARK: - Icon images

    private func iconImage(for status: AppState.Status) -> NSImage? {
        let name: String
        switch status {
        case .idle:       name = "mic"
        case .recording:  name = "waveform"
        case .processing: name = "ellipsis.circle"
        case .typing:     name = "keyboard"
        case .error:      name = "exclamationmark.triangle"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: status.rawValue)
    }

    // MARK: - Menu actions

    @objc private func toggleRecording() {
        appState.toggleRecording()
    }

    @objc private func dismissError() {
        appState.errorMessage = nil
    }

    @objc private func copyLastResult() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(appState.lastTranscription, forType: .string)
    }

    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Dictate",
            .applicationVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            .credits: NSAttributedString(
                string: "AI-powered voice dictation for macOS\nMIT License",
                attributes: [.font: NSFont.systemFont(ofSize: 11)]
            ),
        ])
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let hostingController = NSHostingController(rootView: SettingsView(appState: appState))
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Dictate Settings"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 600, height: 500))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates() {
        appState.updaterService.checkForUpdates()
    }

    // MARK: - Onboarding window

    private func openOnboardingWindow() {
        if onboardingWindow == nil {
            let hostingController = NSHostingController(rootView: OnboardingView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Welcome to Dictate"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 420, height: 460))
            window.center()
            onboardingWindow = window
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
