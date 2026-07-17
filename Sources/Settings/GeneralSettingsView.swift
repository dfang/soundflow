import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var launchAtLogin = false
    @State private var debugMode = false

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

            SettingsSectionContainer(title: "Developer") {
                Toggle("Developer Debug Mode", isOn: $debugMode)
                    .onChange(of: debugMode) { _, newValue in
                        appState.debugMode = newValue
                    }

                Text(
                    "Enable detailed logging (Info level) for all audio and transcription events. Use Console.app to view."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            launchAtLogin = appState.launchAtLogin
            debugMode = appState.debugMode
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
