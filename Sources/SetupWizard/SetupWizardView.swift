import SwiftUI

enum WizardStep: Int, CaseIterable {
    case welcome = 0
    case permissions
    case models
    case hotkey
    case audioDevice

    var title: String {
        switch self {
        case .welcome: return "欢迎"
        case .permissions: return "权限申请"
        case .models: return "本地模型"
        case .hotkey: return "快捷键"
        case .audioDevice: return "音频设备"
        }
    }

    var icon: String {
        switch self {
        case .welcome: return "waveform.circle.fill"
        case .permissions: return "lock.shield.fill"
        case .models: return "arrow.down.circle.fill"
        case .hotkey: return "keyboard.fill"
        case .audioDevice: return "mic.fill"
        }
    }
}

struct SetupWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var appState = AppState.shared
    @State private var currentStep: WizardStep = .welcome

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 16) {
                Text("配置向导")
                    .font(.headline)
                    .padding(.bottom, 8)

                ForEach(WizardStep.allCases, id: \.rawValue) { step in
                    HStack(spacing: 12) {
                        Image(systemName: step.icon)
                            .frame(width: 20)
                        Text(step.title)
                    }
                    .foregroundStyle(step == currentStep ? Color.accentColor : .primary.opacity(0.6))
                    .font(.system(.body, design: .rounded, weight: step == currentStep ? .bold : .regular))
                    .padding(.vertical, 8)
                }
                Spacer()
            }
            .padding(20)
            .frame(width: 180)
            .background(.regularMaterial)

            // Main Content
            VStack(spacing: 0) {
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(32)

                // Footer
                HStack {
                    if currentStep != .welcome {
                        Button("上一步") {
                            withAnimation {
                                currentStep = WizardStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                            }
                        }
                    }
                    Spacer()
                    Button(currentStep == .audioDevice ? "完成" : "下一步") {
                        if currentStep == .audioDevice {
                            appState.markWizardCompleted()
                            dismiss()
                        } else {
                            withAnimation {
                                currentStep = WizardStep(rawValue: currentStep.rawValue + 1) ?? .welcome
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .background(.background.opacity(0.8))
            }
            .background(.background)
        }
        .frame(width: 720, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    private var stepContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(currentStep.title)
                .font(.largeTitle.bold())

            switch currentStep {
            case .welcome: WizardWelcomeView()
            case .permissions: WizardPermissionView()
            case .models: WizardModelView()
            case .hotkey: WizardHotkeyView()
            case .audioDevice: WizardAudioDeviceView()
            }
        }
    }
}
