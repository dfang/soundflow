import CoreAudio
import Foundation

struct AudioDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let isDefault: Bool
}

enum AudioDeviceManager {
    static func getInputDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            return [AudioDevice(id: "default", name: "系统默认麦克风", isDefault: true)]
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        guard status == noErr else {
            return [AudioDevice(id: "default", name: "系统默认麦克风", isDefault: true)]
        }

        // Get default input device
        var defaultDeviceID: AudioDeviceID = 0
        var defaultSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultAddress,
            0,
            nil,
            &defaultSize,
            &defaultDeviceID
        )

        var inputDevices: [AudioDevice] = []

        for deviceID in deviceIDs {
            // Check if device has input streams
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var inputSize: UInt32 = 0
            let inputStatus = AudioObjectGetPropertyDataSize(
                deviceID,
                &inputAddress,
                0,
                nil,
                &inputSize
            )

            guard inputStatus == noErr, inputSize > 0 else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var deviceName: UnsafeMutableRawPointer?
            var nameSize = UInt32(MemoryLayout<UnsafeMutableRawPointer?>.size)

            let nameStatus = AudioObjectGetPropertyData(
                deviceID,
                &nameAddress,
                0,
                nil,
                &nameSize,
                &deviceName
            )

            guard nameStatus == noErr, let deviceNamePtr = deviceName else { continue }
            let cfName = Unmanaged<CFString>.fromOpaque(deviceNamePtr).takeUnretainedValue()

            inputDevices.append(AudioDevice(
                id: String(deviceID),
                name: cfName as String,
                isDefault: deviceID == defaultDeviceID
            ))
        }

        if inputDevices.isEmpty {
            inputDevices = [AudioDevice(id: "default", name: "系统默认麦克风", isDefault: true)]
        }

        return inputDevices
    }
}
