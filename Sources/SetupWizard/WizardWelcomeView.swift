import SwiftUI

struct WizardWelcomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SoundFlow 是一款本地语音输入工具，通过全局快捷键触发录音，将语音实时转为文字并插入到当前应用。")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                featureRow(icon: "mic.fill", title: "本地 ASR", desc: "SenseVoice 模型，完全离线运行")
                featureRow(icon: "bolt.fill", title: "低延迟", desc: "实时预览，无需等待")
                featureRow(icon: "lock.fill", title: "隐私安全", desc: "所有数据仅在本地处理")
            }
            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
