import AppKit
import SwiftUI

@MainActor
final class HUDWindowController {
    private let cornerRadius: CGFloat = 24
    private let panel: FloatingPanel
    private var isVisible = false

    init(model: SoundFlowModel) {
        let rootView = HUDView(model: model)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = cornerRadius
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 188),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = cornerRadius
        panel.contentView?.layer?.cornerCurve = .continuous
        panel.contentView?.layer?.masksToBounds = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.alphaValue = 0
    }

    func show() {
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        guard !isVisible else {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        isVisible = true
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        } completionHandler: { [panel] in
            panel.orderOut(nil)
        }
    }

    private func positionPanel() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }

        let width: CGFloat = 620
        let height: CGFloat = 188
        let origin = NSPoint(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.minY + 48
        )

        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
    }
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
