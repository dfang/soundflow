import Carbon
import CoreGraphics
import Foundation

enum HUDKeyCommand: Equatable {
    case cancel
    case confirm
}

enum HUDKeyCommandRouter {
    static func command(for keyCode: CGKeyCode) -> HUDKeyCommand? {
        switch Int(keyCode) {
        case Int(kVK_Escape):
            return .cancel
        case Int(kVK_Return), Int(kVK_ANSI_KeypadEnter):
            return .confirm
        default:
            return nil
        }
    }
}

final class HUDKeyCommandMonitor {
    var onCommand: ((HUDKeyCommand) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: opaqueSelf
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    deinit {
        stop()
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<HUDKeyCommandMonitor>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = monitor.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard let command = HUDKeyCommandRouter.command(for: keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        DispatchQueue.main.async {
            monitor.onCommand?(command)
        }
        return nil
    }
}
