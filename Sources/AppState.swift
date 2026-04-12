import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    private init() {}

    @AppStorage("isFirstLaunch") var isFirstLaunch = true
    @AppStorage("selectedAudioDeviceID") var selectedAudioDeviceID: String?
    @AppStorage("hotKeyKeyCode") var hotKeyKeyCode = 62 // Right Control
    @AppStorage("hotKeyModifiers") var hotKeyModifiers: Int = .init(NSEvent.ModifierFlags.control
        .rawValue) // Control modifier
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("hudCorner") var hudCorner = 1 // Bottom Center
    @AppStorage("hudSize") var hudSize = 0.5

    @Published var showWizard = false

    func markWizardCompleted() {
        isFirstLaunch = false
        showWizard = false
        SoundFlowModel.shared.dismissWizard()
    }

    func resetToFirstLaunch() {
        isFirstLaunch = true
        showWizard = true
    }
}
