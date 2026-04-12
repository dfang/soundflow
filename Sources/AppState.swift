import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    private init() {}

    @AppStorage("isFirstLaunch") var isFirstLaunch = true
    @AppStorage("selectedAudioDeviceID") var selectedAudioDeviceID: String?
    @AppStorage("hotKeyKeyCode") var hotKeyKeyCode: Int = 62 // Right Control
    @AppStorage("hotKeyModifiers") var hotKeyModifiers: Int = .init(NSEvent.ModifierFlags.control.rawValue) // Control modifier
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("hudCorner") var hudCorner: Int = 1 // Bottom Center
    @AppStorage("hudSize") var hudSize: Double = 0.5

    @Published var showWizard = false

    func markWizardCompleted() {
        isFirstLaunch = false
        showWizard = false
    }

    func resetToFirstLaunch() {
        isFirstLaunch = true
        showWizard = true
    }
}
