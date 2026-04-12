import CoreAudio
import SwiftUI

struct WizardAudioDeviceView: View {
    @StateObject private var appState = AppState.shared
    @State private var devices: [AudioDevice] = []
    @State private var selectedDeviceID: String?
    @State private var hasLoaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择语音输入使用的麦克风设备")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if devices.isEmpty {
                HStack {
                    ProgressView()
                    Text("正在加载设备列表...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                deviceList
            }

            Spacer()
        }
        .onAppear {
            loadDevices()
        }
    }

    private var deviceList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(devices) { device in
                    deviceRow(device)
                }
            }
        }
    }

    private func deviceRow(_ device: AudioDevice) -> some View {
        let isSelected = selectedDeviceID == device.id

        return HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .foregroundColor(isSelected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.subheadline)
                if device.isDefault {
                    Text("系统默认")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(Color.accentColor)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected
                    ? Color.accentColor.opacity(0.2)
                    : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDeviceID = device.id
            appState.selectedAudioDeviceID = device.id
        }
    }

    private func loadDevices() {
        devices = AudioDeviceManager.getInputDevices()
        selectedDeviceID = appState.selectedAudioDeviceID ?? (devices.first(where: { $0.isDefault })?.id)
        hasLoaded = true
    }
}
