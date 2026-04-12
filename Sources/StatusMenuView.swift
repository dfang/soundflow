import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var model: SoundFlowModel
    var onOpenSettings: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Device info
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.currentAudioDeviceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)

            Divider()
                .padding(.horizontal, -8)

            // Status
            VStack(alignment: .leading, spacing: 4) {
                Text("SoundFlow")
                    .font(.headline)
                Text(model.phaseLabel)
                    .font(.subheadline)
                    .foregroundStyle(model.phaseColor)
            }

            Divider()
                .padding(.horizontal, -8)

            // Recording controls
            Button(model.phase == .recording ? "确认输入" : "开始录音") {
                if model.phase == .recording {
                    model.commitRecordingFromUI()
                } else {
                    model.beginRecordingFromUI()
                }
            }

            Button("取消") {
                model.cancelRecordingFromUI()
            }
            .disabled(model.phase != .recording)

            Divider()
                .padding(.horizontal, -8)

            // Settings button
            Button("设置 ⌘,") {
                onOpenSettings?()
            }

            Divider()
                .padding(.horizontal, -8)

            // About
            Button("关于") {
                showAbout()
            }

            // Check for updates (mock)
            Button("检查更新") {
                showUpdateAlert()
            }

        }
        .padding(.vertical, 4)
        .frame(width: 240)
    }

    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "SoundFlow"
        alert.informativeText = "版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")\n\n本地语音输入工具"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "检查更新"
        alert.informativeText = "当前已是最新版本"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
      }
}
