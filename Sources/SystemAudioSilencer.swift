import AudioToolbox
import CoreAudio
import Foundation

protocol SystemAudioDeviceControlling {
    func defaultOutputDeviceID() throws -> AudioDeviceID
    func canSetMute(for deviceID: AudioDeviceID) -> Bool
    func muteState(for deviceID: AudioDeviceID) throws -> Bool
    func setMuted(_ muted: Bool, for deviceID: AudioDeviceID) throws
    func canSetVolume(for deviceID: AudioDeviceID) -> Bool
    func volume(for deviceID: AudioDeviceID) throws -> Float32
    func setVolume(_ volume: Float32, for deviceID: AudioDeviceID) throws
}

@MainActor
final class SystemAudioSilencer {
    static let shared = SystemAudioSilencer()

    private enum Snapshot {
        case mute(deviceID: AudioDeviceID, wasMuted: Bool)
        case volume(deviceID: AudioDeviceID, value: Float32)

        var deviceID: AudioDeviceID {
            switch self {
            case let .mute(deviceID, _), let .volume(deviceID, _):
                return deviceID
            }
        }
    }

    private let controller: any SystemAudioDeviceControlling
    private let log: (String) -> Void
    private var snapshot: Snapshot?

    init(
        controller: any SystemAudioDeviceControlling = CoreAudioSystemAudioController(),
        log: @escaping (String) -> Void = {
            AppLogger.warning($0, category: .audio)
        }
    ) {
        self.controller = controller
        self.log = log
    }

    func silence() {
        guard snapshot == nil else { return }

        do {
            let deviceID = try controller.defaultOutputDeviceID()

            if controller.canSetMute(for: deviceID) {
                let wasMuted = try controller.muteState(for: deviceID)
                snapshot = .mute(deviceID: deviceID, wasMuted: wasMuted)
                if !wasMuted {
                    try controller.setMuted(true, for: deviceID)
                }
            } else if controller.canSetVolume(for: deviceID) {
                let volume = try controller.volume(for: deviceID)
                snapshot = .volume(deviceID: deviceID, value: volume)
                if volume != 0 {
                    try controller.setVolume(0, for: deviceID)
                }
            } else {
                log("Default output device does not support software mute or volume")
            }
        } catch {
            snapshot = nil
            log("Failed to silence system audio: \(error.localizedDescription)")
        }
    }

    func restore() {
        guard let snapshot else { return }
        self.snapshot = nil

        do {
            switch snapshot {
            case let .mute(deviceID, wasMuted):
                try controller.setMuted(wasMuted, for: deviceID)
            case let .volume(deviceID, value):
                try controller.setVolume(value, for: deviceID)
            }
        } catch {
            log("Failed to restore system audio for device \(snapshot.deviceID): \(error.localizedDescription)")
        }
    }
}

struct CoreAudioSystemAudioController: SystemAudioDeviceControlling {
    func defaultOutputDeviceID() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        return try readValue(
            AudioDeviceID(kAudioObjectUnknown),
            from: AudioObjectID(kAudioObjectSystemObject),
            address: &address,
            operation: "Read default output device"
        )
    }

    func canSetMute(for deviceID: AudioDeviceID) -> Bool {
        var address = muteAddress
        return isSettable(on: deviceID, address: &address)
    }

    func muteState(for deviceID: AudioDeviceID) throws -> Bool {
        var address = muteAddress
        let value: UInt32 = try readValue(
            0,
            from: deviceID,
            address: &address,
            operation: "Read output mute"
        )
        return value != 0
    }

    func setMuted(_ muted: Bool, for deviceID: AudioDeviceID) throws {
        var address = muteAddress
        try writeValue(
            UInt32(muted ? 1 : 0),
            to: deviceID,
            address: &address,
            operation: "Write output mute"
        )
    }

    func canSetVolume(for deviceID: AudioDeviceID) -> Bool {
        var address = volumeAddress
        return isSettable(on: deviceID, address: &address)
    }

    func volume(for deviceID: AudioDeviceID) throws -> Float32 {
        var address = volumeAddress
        return try readValue(
            Float32.zero,
            from: deviceID,
            address: &address,
            operation: "Read output volume"
        )
    }

    func setVolume(_ volume: Float32, for deviceID: AudioDeviceID) throws {
        var address = volumeAddress
        try writeValue(
            volume,
            to: deviceID,
            address: &address,
            operation: "Write output volume"
        )
    }

    private var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private func isSettable(
        on objectID: AudioObjectID,
        address: inout AudioObjectPropertyAddress
    ) -> Bool {
        guard AudioObjectHasProperty(objectID, &address) else { return false }

        var settable = DarwinBoolean(false)
        let status = AudioObjectIsPropertySettable(objectID, &address, &settable)
        return status == noErr && settable.boolValue
    }

    private func readValue<T>(
        _ initialValue: T,
        from objectID: AudioObjectID,
        address: inout AudioObjectPropertyAddress,
        operation: String
    ) throws -> T {
        var value = initialValue
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutableBytes(of: &value) { buffer in
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &size,
                buffer.baseAddress!
            )
        }
        guard status == noErr else {
            throw CoreAudioControlError(operation: operation, status: status)
        }
        return value
    }

    private func writeValue(
        _ value: some Any,
        to objectID: AudioObjectID,
        address: inout AudioObjectPropertyAddress,
        operation: String
    ) throws {
        let status = withUnsafeBytes(of: value) { buffer in
            AudioObjectSetPropertyData(
                objectID,
                &address,
                0,
                nil,
                UInt32(buffer.count),
                buffer.baseAddress!
            )
        }
        guard status == noErr else {
            throw CoreAudioControlError(operation: operation, status: status)
        }
    }
}

private struct CoreAudioControlError: LocalizedError {
    let operation: String
    let status: OSStatus

    var errorDescription: String? {
        "\(operation) failed with OSStatus \(status)"
    }
}
