import AVFoundation
import CoreAudio
import Foundation

final class AudioCaptureService {
    var onLevel: ((Double) -> Void)?
    var onSamples: (([Float], Int) -> Void)?

    private let engine = AVAudioEngine()
    private var isRunning = false
    private var selectedDeviceID: String?
    private let lock = NSLock()

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceChanged(_:)),
            name: .audioDeviceChanged,
            object: nil
        )
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleDeviceChanged(_ notification: Notification) {
        guard let deviceID = notification.object as? String else { return }
        selectDevice(deviceID: deviceID)
    }

    func selectDevice(deviceID: String) {
        lock.lock()
        defer { lock.unlock() }

        let wasRunning = isRunning
        if isRunning {
            stopEngine()
        }

        selectedDeviceID = deviceID

        if wasRunning {
            try? startEngine()
        }
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        try startEngine()
    }

    private func startEngine() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode

        if let deviceID = selectedDeviceID {
            setInputDevice(deviceID: deviceID)
        }

        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let samples = AudioCaptureService.samples(from: buffer)
            let level = AudioCaptureService.level(from: buffer)
            self?.onSamples?(samples, Int(format.sampleRate))
            DispatchQueue.main.async {
                self?.onLevel?(level)
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        stopEngine()
    }

    private func stopEngine() {
        guard isRunning else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false

        DispatchQueue.main.async {
            self.onLevel?(0)
        }
    }

    private func setInputDevice(deviceID: String) {
        guard let deviceIDScalar = UInt32(deviceID, radix: 10).map({ AudioDeviceID($0) }) else { return }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var device = deviceIDScalar
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            size,
            &device
        )
    }

    private static func level(from buffer: AVAudioPCMBuffer) -> Double {
        let samples = Self.samples(from: buffer)
        guard !samples.isEmpty else { return 0 }

        var rms = Float(0)
        for sample in samples {
            rms += sample * sample
        }

        rms = sqrt(rms / Float(samples.count))
        return min(max(Double(rms) * 20, 0), 1)
    }

    private static func samples(from buffer: AVAudioPCMBuffer) -> [Float] {
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        guard frameLength > 0,
              channelCount > 0,
              let channelData = buffer.floatChannelData else
        {
            return []
        }

        if channelCount == 1 {
            let channel = channelData[0]
            return Array(UnsafeBufferPointer(start: channel, count: frameLength))
        }

        var mono = Array(repeating: Float.zero, count: frameLength)
        for channelIndex in 0 ..< channelCount {
            let channel = channelData[channelIndex]
            for frame in 0 ..< frameLength {
                mono[frame] += channel[frame]
            }
        }

        let divisor = Float(channelCount)
        for frame in 0 ..< frameLength {
            mono[frame] /= divisor
        }

        return mono
    }
}
