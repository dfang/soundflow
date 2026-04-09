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
    private var isRightControlDown = false

    func start() throws {
        guard globalMonitor == nil, localMonitor == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
            return event
        }

        if globalMonitor == nil || localMonitor == nil {
            throw HotKeyError.monitorRegistrationFailed
        }
    }

    deinit {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    private func handle(event: NSEvent) {
        guard event.keyCode == UInt16(kVK_RightControl) else { return }

        let activeModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isDown = activeModifiers == .control

        if isDown, !isRightControlDown {
            isRightControlDown = true
            DispatchQueue.main.async { [weak self] in
                self?.onTrigger?()
            }
            return
        }

        if !isDown {
            isRightControlDown = false
        }
    }
}
