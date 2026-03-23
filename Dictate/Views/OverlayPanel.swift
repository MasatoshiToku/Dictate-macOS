import AppKit
import SwiftUI

/// Non-activating floating panel for recording overlay.
/// Does not steal focus from the target application.
final class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false

        // Prevent the panel from becoming key or main window
        isReleasedWhenClosed = false
    }

    // Never become key window (don't steal focus)
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// SwiftUI wrapper that manages the NSPanel lifecycle
@Observable
final class OverlayPanelController {
    private var panel: OverlayPanel?
    private let bottomMargin: CGFloat = 40

    func showOverlay(content: some View) {
        if panel == nil {
            panel = OverlayPanel()
        }

        guard let panel else { return }

        let hostingView = NSHostingView(rootView: content)
        panel.contentView = hostingView

        positionOnCurrentScreen()
        panel.orderFrontRegardless()
    }

    func hideOverlay() {
        panel?.orderOut(nil)
    }

    func positionOnCurrentScreen() {
        guard let panel else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
                ?? NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.origin.x + (screenFrame.width - panelSize.width) / 2
        let y = screenFrame.origin.y + bottomMargin

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
