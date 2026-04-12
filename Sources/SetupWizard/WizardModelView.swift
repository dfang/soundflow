import SwiftUI

struct ModelStatus {
    var senseVoice: ModelCheckResult = .checking
    var vad: ModelCheckResult = .checking
}

enum ModelCheckResult {
    case checking
    case found(String)
    case missing(String)
}

struct WizardModelView: View {
    @State private var status = ModelStatus()
    @State private var hasChecked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SoundFlow 需要本地 ASR 模型来识别语音")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 16) {
                modelRow(
                    icon: "brain.head.profile",
                    title: "SenseVoice 模型",
                    description: "语音识别模型 (ONNX)",
                    status: status.senseVoice
                )

                modelRow(
                    icon: "waveform.badge.magnifyingglass",
                    title: "VAD 模型",
                    description: "语音活动检测模型 (Silero VAD)",
                    status: status.vad
                )
            }

            Spacer()

            if case .missing = status.senseVoice {
                Text("模型文件请放置在 ~/Library/Application Support/SoundFlow/models/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            checkModels()
        }
    }

    private func modelRow(
        icon: String,
        title: String,
        description: String,
        status: ModelCheckResult
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(statusColor(status))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusView(status)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }

    @ViewBuilder
    private func statusView(_ status: ModelCheckResult) -> some View {
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

    private func statusColor(_ status: ModelCheckResult) -> Color {
        switch status {
        case .checking: return .secondary
        case .found: return .green
        case .missing: return .orange
        }
    }

    private func checkModels() {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let modelsDir = home.appendingPathComponent("Library/Application Support/SoundFlow/models")

        DispatchQueue.global().async {
            let senseVoiceCandidates = [
                modelsDir.appendingPathComponent("sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2024-07-17"),
                modelsDir.appendingPathComponent("sensevoice-small")
            ]

            var found = false
            for candidate in senseVoiceCandidates {
                if fileManager.fileExists(atPath: candidate.path) {
                    let modelFiles = try? fileManager.contentsOfDirectory(atPath: candidate.path)
                    if let files = modelFiles,
                       files.contains(where: { $0.hasSuffix(".onnx") || $0.hasSuffix(".txt") }) {
                        DispatchQueue.main.async {
                            status.senseVoice = .found(candidate.path)
                        }
                        found = true
                        break
                    }
                }
            }

            if !found {
                DispatchQueue.main.async {
                    status.senseVoice = .missing("~/Library/Application Support/SoundFlow/models/sensevoice-small")
                }
            }
        }

        DispatchQueue.global().async {
            let vadCandidates = [
                modelsDir.appendingPathComponent("silero_vad.onnx"),
                home.appendingPathComponent("Library/Application Support/Shandianshuo/models/silero_vad.onnx")
            ]

            var found = false
            for candidate in vadCandidates {
                if fileManager.fileExists(atPath: candidate.path) {
                    DispatchQueue.main.async {
                        status.vad = .found(candidate.path)
                    }
                    found = true
                    break
                }
            }

            if !found {
                DispatchQueue.main.async {
                    status.vad = .missing("~/Library/Application Support/SoundFlow/models/silero_vad.onnx")
                }
            }
        }
    }
}
