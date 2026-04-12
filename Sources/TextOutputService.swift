import AppKit

enum TextOutputResult {
    case inserted
    case accessibilityUnavailable
    case injectionFailed
}

struct TextOutputService {
    private let permissionManager = PermissionManager()
    private let activationRetryDelay: TimeInterval = 0.06
    private let activationRetryCount = 4

    @discardableResult
    func output(
        _ text: String,
        targetApplication: NSRunningApplication?,
        promptForAccessibility: Bool
    ) -> TextOutputResult {
        guard permissionManager.hasAccessibilityPermission(prompt: promptForAccessibility) else {
            return .accessibilityUnavailable
        }

        if !activateTargetApplication(targetApplication) {
            return .injectionFailed
        }

        return injectTextWithKeyboardEvents(text, targetApplication: targetApplication) ? .inserted : .injectionFailed
    }

    private func activateTargetApplication(_ targetApplication: NSRunningApplication?) -> Bool {
        guard let targetApplication, targetApplication != .current else { return true }

        let targetBundleID = targetApplication.bundleIdentifier

        for attempt in 0 ..< activationRetryCount {
            targetApplication.unhide()
            _ = targetApplication.activate(options: [.activateAllWindows])

            let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if frontmostBundleID == targetBundleID {
                return true
            }

            if attempt < activationRetryCount - 1 {
                usleep(UInt32(activationRetryDelay * 1_000_000))
            }
        }

        return false
    }

    private func injectTextWithKeyboardEvents(_ text: String, targetApplication: NSRunningApplication?) -> Bool {
        // 1. 注入前最终焦点确认
        if let target = targetApplication, NSWorkspace.shared.frontmostApplication != target {
            print(
                "[SoundFlow] Injection aborted: Target app \(target.bundleIdentifier ?? "unknown") is no longer frontmost."
            )
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("[SoundFlow] Injection failed: Could not create CGEventSource.")
            return false
        }

        let scalars = Array(text.utf16)
        guard !scalars.isEmpty else { return true }

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else
        {
            print("[SoundFlow] Injection failed: Could not create CGEvent.")
            return false
        }

        keyDown.keyboardSetUnicodeString(stringLength: scalars.count, unicodeString: scalars)
        keyUp.keyboardSetUnicodeString(stringLength: scalars.count, unicodeString: scalars)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        return true
    }
}
