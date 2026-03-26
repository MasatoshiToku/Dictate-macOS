import AppKit
import SwiftUI

/// Non-activating floating panel for recording overlay.
/// Does not steal focus from the target application.
final class OverlayPanel: NSPanel {
    init() {
        // Fixed compact overlay size
        let overlayWidth: CGFloat = 280
        let overlayHeight: CGFloat = 200

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: overlayWidth, height: overlayHeight),
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

/// SwiftUI wrapper that manages the NSPanel lifecycle.
/// NSPanel/NSWindow must be created and manipulated on the main thread.
/// Methods dispatch to the main thread internally to prevent crashes
/// when called from async contexts (Swift concurrency cooperative threads).
@Observable
final class OverlayPanelController {
    private var panel: OverlayPanel?
    private let bottomMargin: CGFloat = 40

    func showOverlay(content: some View) {
        let block = { [self] in
            if self.panel == nil {
                self.panel = OverlayPanel()
            }

            guard let panel = self.panel else { return }

            let hostingView = NSHostingView(rootView: content)
            panel.contentView = hostingView

            self.positionOnCurrentScreen()
            panel.orderFrontRegardless()
        }

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    func hideOverlay() {
        let block = { [self] in
            self.panel?.orderOut(nil)
        }

        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async { block() }
        }
    }

    /// Force NSHostingView to redraw. Non-key/non-main panels may skip layout passes,
    /// so we explicitly mark the content view as needing display.
    func invalidateDisplay() {
        panel?.contentView?.needsDisplay = true
        panel?.contentView?.needsLayout = true
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
