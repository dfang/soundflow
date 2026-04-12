import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case hudPreview
    case audio
    case hotkey
    case models
    case about

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general: return "General"
        case .appearance: return "Appearance"
        case .hudPreview: return "HUD Preview"
        case .audio: return "Audio Input"
        case .hotkey: return "Hotkeys"
        case .models: return "Model Settings"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        case .hudPreview: return "rectangle.bottomhalf.filled"
        case .audio: return "mic.fill"
        case .hotkey: return "keyboard.fill"
        case .models: return "books.vertical.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsWindow: View {
    var body: some View {
        SettingsContainerView()
            .frame(minWidth: 900, minHeight: 700)
    }
}

struct SettingsContainerView: View {
    @State var selectedSection: SettingsSection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(initialSection: SettingsSection? = .general) {
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar area
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SoundFlow")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        } detail: {
            VStack(spacing: 0) {
                // Custom header - integrated into the detail area
                HStack {
                    // Traffic lights area spacer
                    Color.clear.frame(width: 60, height: 20)

                    Spacer()

                    Text("UGREEN MIC-CM770 Wired (Default) 🎧")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                ScrollView {
                    if let section = selectedSection {
                        sectionDetail(for: section)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .background(.ultraThinMaterial)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func sectionDetail(for section: SettingsSection) -> some View {
        switch section {
        case .general: GeneralSettingsView().frame(maxWidth: .infinity)
        case .appearance: AppearanceSettingsView().frame(maxWidth: .infinity)
        case .hudPreview: HUDPreviewSettingsView().frame(maxWidth: .infinity)
        case .hotkey: HotkeySettingsView().frame(maxWidth: .infinity)
        case .audio: AudioSettingsView().frame(maxWidth: .infinity)
        case .models: ModelsSettingsView().frame(maxWidth: .infinity)
        case .about: AboutSettingsView().frame(maxWidth: .infinity)
        }
    }
}
