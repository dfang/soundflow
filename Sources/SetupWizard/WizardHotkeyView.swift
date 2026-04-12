import SwiftUI

struct WizardHotkeyView: View {
    @StateObject private var appState = AppState.shared
    @State private var hotKey: HotKeyConfiguration = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置全局快捷键来触发语音输入")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 16) {
                Text("按下快捷键开始录音，再次按下确认输入")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                KeyRecorderView(configuration: $hotKey)
                    .onChange(of: hotKey) { _, newValue in
                        saveHotKey(newValue)
                    }

                Text("推荐使用右侧 Control 键或其他不常用的按键作为修饰键")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            loadHotKey()
        }
    }

    private func loadHotKey() {
        hotKey = HotKeyConfiguration(
            keyCode: appState.hotKeyKeyCode,
            modifiers: appState.hotKeyModifiers
        )
    }

    private func saveHotKey(_ config: HotKeyConfiguration) {
        appState.hotKeyKeyCode = config.keyCode
        appState.hotKeyModifiers = config.modifiers
    }
}
