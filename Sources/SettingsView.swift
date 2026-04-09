import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SoundFlowModel
    @AppStorage("deepseekApiKey") private var apiKey = ""

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

            Text("DeepSeek API Key")
                .font(.headline)
            SecureField("sk-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
            Text("Required for cloud post-processing via DeepSeek")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("Current behavior")
                .font(.headline)
            Text("This build uses the local SenseVoice ONNX model through sherpa-onnx for ASR. Post-processing is currently disabled so you can validate the raw ASR path without Gemma or fallback formatting.")
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
