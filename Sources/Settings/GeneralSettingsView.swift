import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSectionContainer(title: "Startup") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        appState.launchAtLogin = newValue
                        updateLaunchAtLogin(newValue)
                    }

                Text("Launch SoundFlow automatically when you log in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            launchAtLogin = appState.launchAtLogin
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}
