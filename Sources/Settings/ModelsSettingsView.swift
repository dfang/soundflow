import SwiftUI

struct ModelsSettingsView: View {
    @State private var senseVoicePath = ""
    @State private var vadPath = ""
    @State private var senseVoiceStatus: ModelCheckResult = .checking
    @State private var vadStatus: ModelCheckResult = .checking

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingSection(title: "ASR 模型") {
                modelRow(title: "SenseVoice 模型", status: senseVoiceStatus, path: senseVoicePath)
            }

            settingSection(title: "语音活动检测") {
                modelRow(title: "VAD 模型", status: vadStatus, path: vadPath)
            }

            settingSection(title: "") {
                Button("重新检测") {
                    checkModels()
                }
            }

            Spacer()
        }
        .foregroundColor(.white)
        .onAppear {
            checkModels()
        }
    }

    private func settingSection(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            content()
        }
    }

    private func modelRow(title: String, status: ModelCheckResult, path: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                statusBadge(status)
            }

            Text(path)
                .font(.caption)
                .foregroundStyle(.gray)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: ModelCheckResult) -> some View {
        switch status {
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .found:
            Label("已安装", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .missing:
            Label("未找到", systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func checkModels() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let modelsDir = home.appendingPathComponent("Library/Application Support/SoundFlow/models")

        senseVoiceStatus = .checking
        let senseVoiceCandidates = [
            modelsDir.appendingPathComponent("sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"),
            modelsDir.appendingPathComponent("sensevoice-small"),
        ]

        var found = false
        for candidate in senseVoiceCandidates {
            if fileManager.fileExists(atPath: candidate.path) {
                let modelFiles = try? fileManager.contentsOfDirectory(atPath: candidate.path)
                if let files = modelFiles, files.contains(where: { $0.hasSuffix(".onnx") || $0.hasSuffix(".txt") }) {
                    senseVoicePath = candidate.path
                    senseVoiceStatus = .found(candidate.path)
                    found = true
                    break
                }
            }
        }

        if !found {
            senseVoicePath = "~/Library/Application Support/SoundFlow/models/sensevoice-small"
            senseVoiceStatus = .missing(senseVoicePath)
        }

        vadStatus = .checking
        let vadCandidates = [
            modelsDir.appendingPathComponent("silero_vad.onnx"),
            home.appendingPathComponent("Library/Application Support/Shandianshuo/models/silero_vad.onnx"),
        ]

        found = false
        for candidate in vadCandidates {
            if fileManager.fileExists(atPath: candidate.path) {
                vadPath = candidate.path
                vadStatus = .found(candidate.path)
                found = true
                break
            }
        }

        if !found {
            vadPath = "~/Library/Application Support/SoundFlow/models/silero_vad.onnx"
            vadStatus = .missing(vadPath)
        }
    }
}
