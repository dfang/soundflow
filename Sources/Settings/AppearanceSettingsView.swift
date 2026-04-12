import SwiftUI

struct AppearanceSettingsView: View {
    @StateObject private var appState = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingSection(title: "Theme") {
                Picker("Color Theme", selection: .constant(0)) {
                    Text("System").tag(0)
                    Text("Dark").tag(1)
                    Text("Light").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }

            settingSection(title: "Window Behavior") {
                Toggle("Remember window position", isOn: .constant(true))
                Toggle("Show in menu bar", isOn: .constant(true))
            }

            Spacer()
        }
        .foregroundColor(.white)
    }

    private func settingSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.gray)

            content()
        }
    }
}
