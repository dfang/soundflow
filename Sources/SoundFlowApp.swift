import AppKit
import SwiftUI

@MainActor
@main
struct SoundFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = SoundFlowModel.shared
    @State private var settingsWindowController: SettingsWindowController?
    @State private var setupWindowController: SetupWindowController?

    init() {
        SoundFlowModel.shared.bootstrap()
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(model: model, onOpenSettings: openSettings)
            Divider()
            Button("Setup Guide") {
                openSetup()
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Label(model.menuBarTitle, systemImage: model.menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)
    }

    private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSetup() {
        if setupWindowController == nil {
            setupWindowController = SetupWindowController()
        }
        setupWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class SettingsWindowController: NSWindowController {
    var contentView: SettingsContainerView = .init()

    init(initialSection: SettingsSection? = nil) {
        let cv = SettingsContainerView(initialSection: initialSection)
        let hostingController = NSHostingController(rootView: cv)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 900, height: 700))
        window.minSize = NSSize(width: 900, height: 700)
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        contentViewController = hostingController
        contentView = cv
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
