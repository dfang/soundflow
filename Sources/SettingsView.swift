import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SoundFlowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SoundFlow MVP")
                .font(.title2.bold())

            Group {
                settingsRow("Hotkey", value: "Right Control")
                settingsRow("ASR", value: "SenseVoice Small (integration placeholder)")
                settingsRow("Post-Processing", value: "Gemma 4 E4B (commit-time placeholder)")
                settingsRow("Preview UI", value: "Bottom floating HUD")
            }

            Divider()

            Text("Current behavior")
                .font(.headline)
            Text("This MVP wires the menu bar app, global hotkey, audio capture, bottom HUD, confirm/cancel flow, and focused-app output. MLX model integration points are scaffolded with mock transcription and mock post-processing.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
