import AppKit
import Carbon

enum TextOutputResult {
    case pasted
    case copiedToClipboard
}

struct TextOutputService {
    private let permissionManager = PermissionManager()
    private let activationDelay: TimeInterval = 0.28

    func output(
        _ text: String,
        targetApplication: NSRunningApplication?,
        promptForAccessibility: Bool
    ) -> TextOutputResult {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard permissionManager.hasAccessibilityPermission(prompt: promptForAccessibility) else {
            return .copiedToClipboard
        }

        if let targetApplication, targetApplication != .current {
            targetApplication.unhide()
            let didActivate = targetApplication.activate(options: [.activateAllWindows])

            DispatchQueue.main.asyncAfter(deadline: .now() + activationDelay) {
                let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                let targetBundleID = targetApplication.bundleIdentifier

                if !didActivate || frontmostBundleID != targetBundleID {
                    targetApplication.unhide()
                    _ = targetApplication.activate(options: [.activateAllWindows])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        simulatePaste()
                    }
                    return
                }

                simulatePaste()
            }
        } else {
            simulatePaste()
        }

        return .pasted
    }

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }
}
