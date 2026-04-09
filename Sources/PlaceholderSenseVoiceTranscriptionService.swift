import Foundation

final class PlaceholderSenseVoiceTranscriptionService: TranscriptionService {
    let displayName = ASRBackend.sherpaSenseVoice.rawValue
    let model: ModelDescriptor
    var onPreview: ((String) -> Void)?

    init(model: ModelDescriptor) {
        self.model = model
    }

    func start() throws {
        onPreview?("SenseVoice integration pending...")
    }

    func appendAudio(samples: [Float], sampleRate: Int) {
        _ = samples
        _ = sampleRate
    }

    func stop() async throws -> String {
        "SenseVoice integration pending"
    }

    func cancel() {}
}
