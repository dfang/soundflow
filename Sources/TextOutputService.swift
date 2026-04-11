import AppKit

enum TextOutputResult {
    case inserted
    case accessibilityUnavailable
    case injectionFailed
}

struct TextOutputService {
    private let permissionManager = PermissionManager()
    private let activationDelay: TimeInterval = 0.28

    @discardableResult
    func output(
        _ text: String,
        targetApplication: NSRunningApplication?,
        promptForAccessibility: Bool
    ) -> TextOutputResult {
        guard permissionManager.hasAccessibilityPermission(prompt: promptForAccessibility) else {
            return .accessibilityUnavailable
        }

        bringTargetToFront(targetApplication)
        usleep(UInt32(activationDelay * 1_000_000))

        if let targetApplication,
           targetApplication != .current,
           NSWorkspace.shared.frontmostApplication?.bundleIdentifier != targetApplication.bundleIdentifier {
            return .injectionFailed
        }

        return injectTextWithKeyboardEvents(text) ? .inserted : .injectionFailed
    }

    private func bringTargetToFront(_ targetApplication: NSRunningApplication?) {
        guard let targetApplication, targetApplication != .current else { return }
        targetApplication.unhide()
        _ = targetApplication.activate(options: [.activateAllWindows])
    }

    private func injectTextWithKeyboardEvents(_ text: String) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        let scalars = Array(text.utf16)
        guard !scalars.isEmpty else {
            return true
        }

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else {
            return false
        }

        keyDown.keyboardSetUnicodeString(stringLength: scalars.count, unicodeString: scalars)
        keyUp.keyboardSetUnicodeString(stringLength: scalars.count, unicodeString: scalars)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
