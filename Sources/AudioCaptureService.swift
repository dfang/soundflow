import AVFoundation
import Foundation

final class AudioCaptureService {
    var onLevel: ((Double) -> Void)?
    var onSamples: (([Float], Int) -> Void)?

    private let engine = AVAudioEngine()
    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let samples = Self.samples(from: buffer)
            let level = Self.level(from: buffer)
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
        guard isRunning else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false

        DispatchQueue.main.async {
            self.onLevel?(0)
        }
    }

    deinit {
        stop()
    }

    private static func level(from buffer: AVAudioPCMBuffer) -> Double {
        let samples = samples(from: buffer)
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
              let channelData = buffer.floatChannelData else {
            return []
        }

        if channelCount == 1 {
            let channel = channelData[0]
            return Array(UnsafeBufferPointer(start: channel, count: frameLength))
        }

        var mono = Array(repeating: Float.zero, count: frameLength)
        for channelIndex in 0..<channelCount {
            let channel = channelData[channelIndex]
            for frame in 0..<frameLength {
                mono[frame] += channel[frame]
            }
        }

        let divisor = Float(channelCount)
        for frame in 0..<frameLength {
            mono[frame] /= divisor
        }

        return mono
    }
}
