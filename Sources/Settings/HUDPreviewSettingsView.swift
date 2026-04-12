import SwiftUI

struct HUDPreviewSettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var selectedCorner: Int = 0
    @State private var hudSize: Double = 0.5

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingSection(title: "Position") {
                Picker("Screen Corner", selection: $selectedCorner) {
                    Text("Bottom Left").tag(0)
                    Text("Bottom Center").tag(1)
                    Text("Bottom Right").tag(2)
                    Text("Top Left").tag(3)
                    Text("Top Center").tag(4)
                    Text("Top Right").tag(5)
                }
                .pickerStyle(.menu)
                .onChange(of: selectedCorner) { _, newValue in
                    appState.hudCorner = newValue
                }
            }

            settingSection(title: "Size") {
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $hudSize, in: 0.3 ... 1.0, step: 0.1)
                        .frame(width: 250)
                        .onChange(of: hudSize) { _, newValue in
                            appState.hudSize = newValue
                        }

                    Text("Preview size: \(Int(hudSize * 100))%")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            settingSection(title: "Opacity") {
                Slider(value: .constant(0.9), in: 0.5 ... 1.0, step: 0.1)
                    .frame(width: 250)
            }

            Spacer()
        }
        .foregroundColor(.white)
        .onAppear {
            selectedCorner = appState.hudCorner
            hudSize = appState.hudSize
        }
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
