import AppKit
import SwiftUI

class SetupWindowController: NSWindowController {
    convenience init() {
        // 使用标准的窗口样式，并允许控制关闭行为
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "SoundFlow 设置向导"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: SetupWizardView())
        window.contentView = hostingView
        window.center()

        // 确保窗口不会因为点击外部而自动关闭 (非 Modal)
        window.isReleasedWhenClosed = false

        self.init(window: window)
    }
}
