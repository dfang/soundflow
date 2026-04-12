import AppKit
import Carbon
import Foundation

final class GlobalHotKeyService {
    enum HotKeyError: LocalizedError {
        case monitorRegistrationFailed

        var errorDescription: String? {
            switch self {
            case .monitorRegistrationFailed:
                return "Failed to install the global key monitor."
            }
        }
    }

    var onTrigger: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isKeyDown = false
    private var targetKeyCode: UInt16
    private var targetModifiers: NSEvent.ModifierFlags
    private let lock = NSLock()

    /// Maps key codes to their corresponding modifier flags
    private static let keyCodeToModifier: [UInt16: NSEvent.ModifierFlags] = [
        UInt16(kVK_RightControl): .control,
        UInt16(kVK_Control): .control,
        UInt16(kVK_Shift): .shift,
        UInt16(kVK_RightShift): .shift,
        UInt16(kVK_Option): .option,
        UInt16(kVK_RightOption): .option,
        UInt16(kVK_Command): .command,
        UInt16(kVK_RightCommand): .command,
    ]

    init(keyCode: Int = 17, modifiers: Int = 0) {
        targetKeyCode = UInt16(keyCode)
        targetModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiers))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChanged(_:)),
            name: .hotKeyConfigurationChanged,
            object: nil
        )
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleConfigurationChanged(_ notification: Notification) {
        guard let config = notification.object as? HotKeyConfiguration else { return }
        configure(keyCode: config.keyCode, modifiers: config.modifiers)
    }

    func configure(keyCode: Int, modifiers: Int) {
        lock.lock()
        defer { lock.unlock() }

        stopMonitors()

        targetKeyCode = UInt16(keyCode)
        targetModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifiers))

        startMonitors()
    }

    func start() throws {
        guard globalMonitor == nil, localMonitor == nil else { return }
        startMonitors()

        if globalMonitor == nil || localMonitor == nil {
            throw HotKeyError.monitorRegistrationFailed
        }
    }

    private func startMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
            return event
        }
    }

    private func stopMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        stopMonitors()
    }

    private func handle(event: NSEvent) {
        guard event.keyCode == targetKeyCode else { return }

        let activeModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Determine if the key is currently pressed
        let isDown: Bool
        if targetModifiers.isEmpty {
            // No additional modifiers required
            // Check if the key's own modifier is the ONLY thing active
            // This handles Right Control (keyCode 17) with no extra modifiers
            if let keyModifier = Self.keyCodeToModifier[targetKeyCode] {
                // Key is down only if its modifier is set and nothing else
                isDown = (activeModifiers == keyModifier)
            } else {
                // For keys without a modifier (like function keys), any modifier presence means not down
                isDown = activeModifiers.isEmpty == false
            }
        } else {
            // Has required modifiers - key is down if all required are present
            let requiredModifiers = targetModifiers.intersection(.deviceIndependentFlagsMask)
            isDown = activeModifiers.contains(requiredModifiers)
        }

        // Trigger on key DOWN (transition from not down to down)
        if isDown, !isKeyDown {
            isKeyDown = true
            DispatchQueue.main.async { [weak self] in
                self?.onTrigger?()
            }
            return
        }

        // Reset on key UP
        if !isDown {
            isKeyDown = false
        }
    }
}
