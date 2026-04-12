import CoreAudio
import SwiftUI

struct AudioSettingsView: View {
    @StateObject private var appState = AppState.shared
    @State private var devices: [AudioDevice] = []
    @State private var selectedDeviceID: String?
    @State private var audioLevel: Float = 0
    @State private var isMonitoring = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            settingSection(title: "输入设备") {
                Picker("", selection: $selectedDeviceID) {
                    ForEach(devices) { device in
                        HStack {
                            Text(device.name)
                            if device.isDefault {
                                Text("(默认)")
                                    .foregroundStyle(.gray)
                            }
                        }
                        .tag(device.id as String?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedDeviceID) { _, newValue in
                    if let id = newValue {
                        appState.selectedAudioDeviceID = id
                        NotificationCenter.default.post(name: .audioDeviceChanged, object: id)
                    }
                }
            }

            settingSection(title: "实时电平") {
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(levelColor)
                                .frame(width: geometry.size.width * CGFloat(audioLevel))
                        }
                    }
                    .frame(height: 8)

                    Button(isMonitoring ? "停止监听" : "开始监听") {
                        isMonitoring.toggle()
                        NotificationCenter.default.post(name: .audioMonitoringToggled, object: isMonitoring)
                    }
                }
            }

            Spacer()
        }
        .foregroundColor(.white)
        .onAppear {
            loadDevices()
            selectedDeviceID = appState.selectedAudioDeviceID
        }
    }

    private var levelColor: Color {
        if audioLevel > 0.8 {
            return .red
        } else if audioLevel > 0.6 {
            return .orange
        } else {
            return .green
        }
    }

    private func settingSection(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.gray)

            content()
        }
    }

    private func loadDevices() {
        devices = AudioDeviceManager.getInputDevices()
    }
}
