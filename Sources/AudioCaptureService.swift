import AVFoundation
import Foundation

final class AudioCaptureService {
    var onLevel: ((Double) -> Void)?

    private let engine = AVAudioEngine()
    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let level = Self.level(from: buffer)
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
        guard let channelData = buffer.floatChannelData else { return 0 }

        let channel = channelData[0]
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        var rms = Float(0)
        for frame in 0..<frameLength {
            let sample = channel[frame]
            rms += sample * sample
        }

        rms = sqrt(rms / Float(frameLength))
        return min(max(Double(rms) * 20, 0), 1)
    }
}
