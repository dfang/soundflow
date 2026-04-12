import SwiftUI

struct HotkeySettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var hotKey: HotKeyConfiguration = .default

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keyboard Shortcuts")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.leading, 4)

                    // Card
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Toggle Recording")
                                    .font(.system(.body, weight: .medium))
                                Text("Starts and stops recordings")
                                    .font(.system(.caption))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            KeyRecorderView(configuration: $hotKey)
                                .frame(width: 160)
                                .onChange(of: hotKey) { _, newValue in
                                    saveHotKey(newValue)
                                }
                        }
                        .padding(16)
                    }
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }

                Spacer()
            }
            .padding(32)
        }
        .onAppear {
            loadHotKey()
        }
    }

    private func loadHotKey() {
        hotKey = HotKeyConfiguration(
            keyCode: appState.hotKeyKeyCode,
            modifiers: appState.hotKeyModifiers
        )
    }

    private func saveHotKey(_ config: HotKeyConfiguration) {
        appState.hotKeyKeyCode = config.keyCode
        appState.hotKeyModifiers = config.modifiers
        NotificationCenter.default.post(name: .hotKeyConfigurationChanged, object: config)
    }
}
