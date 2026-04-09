import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SoundFlowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("SoundFlow MVP")
                .font(.title2.bold())

            Group {
                settingsRow("Hotkey", value: "Right Control")
                settingsRow("ASR Backend", value: model.asrBackendName)
                settingsRow("ASR Model", value: model.asrModelName)
                settingsRow("ASR Source", value: model.asrModelSource)
                settingsRow("Post-Processing", value: "\(model.postProcessorName) / \(model.postProcessorModelName)")
                settingsRow("Preview UI", value: "Bottom floating HUD")
            }

            Divider()

            Text("Current behavior")
                .font(.headline)
            Text("This build uses the local SenseVoice ONNX model through sherpa-onnx for ASR, while keeping post-processing pluggable. The menu bar app, global hotkey, audio capture, bottom HUD, confirm/cancel flow, and focused-app output all stay behind the same runtime abstraction.")
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
