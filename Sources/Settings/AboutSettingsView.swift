import SwiftUI

struct AboutSettingsView: View {
    @State private var showUpdateAlert = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App info
            HStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("SoundFlow")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    Text("版本 \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            // Check update button
            Button("检查更新") {
                showUpdateAlert = true
            }
            .alert("检查更新", isPresented: $showUpdateAlert) {
                Button("确定", role: .cancel) {}
            } message: {
                Text("当前已是最新版本")
            }

            // Credits
            VStack(alignment: .leading, spacing: 8) {
                Text("致谢")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray)

                Text("• SenseVoice — 阿里云语音识别模型")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text("• sherpa-onnx — ONNX 推理引擎")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Text("• MLX — Apple Silicon 机器学习框架")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer()
        }
        .foregroundColor(.white)
        .padding(.top, 8)
    }
}
