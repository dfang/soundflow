import SwiftUI

@MainActor
@main
struct SoundFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = SoundFlowModel.shared

    init() {
        SoundFlowModel.shared.bootstrap()
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(model: model)
        } label: {
            Label(model.menuBarTitle, systemImage: model.menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
                .frame(width: 420)
                .padding(20)
        }
    }
}
