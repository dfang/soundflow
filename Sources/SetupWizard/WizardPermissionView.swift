import ApplicationServices
import AVFoundation
import SwiftUI

struct PermissionStatus {
    var microphone = false
    var accessibility = false
    var microphoneChecked = false
    var accessibilityChecked = false
}

struct WizardPermissionView: View {
    @State private var status = PermissionStatus()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SoundFlow 需要以下权限才能正常工作")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 16) {
                permissionRow(
                    icon: "mic.fill",
                    title: "麦克风权限",
                    description: "用于采集语音输入",
                    isGranted: status.microphone,
                    isChecked: status.microphoneChecked
                ) {
                    requestMicrophone()
                }

                permissionRow(
                    icon: "hand.raised.fill",
                    title: "无障碍权限",
                    description: "用于将文字粘贴到其他应用",
                    isGranted: status.accessibility,
                    isChecked: status.accessibilityChecked
                ) {
                    requestAccessibility()
                }
            }
            Spacer()
        }
        .onAppear {
            checkPermissions()
        }
    }

    private func permissionRow(
        icon: String,
        title: String,
        description: String,
        isGranted: Bool,
        isChecked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isChecked {
                if isGranted {
                    Label("已授权", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button("申请权限") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }

    private func checkPermissions() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        status.microphoneChecked = true
        status.microphone = micStatus == .authorized

        status.accessibilityChecked = true
        status.accessibility = AXIsProcessTrusted()
    }

    private func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                status.microphoneChecked = true
                status.microphone = granted
            }
        }
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            status.accessibilityChecked = true
            status.accessibility = AXIsProcessTrusted()
        }
    }
}
