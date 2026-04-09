import Foundation

protocol TranscriptionService: AnyObject {
    var displayName: String { get }
    var model: ModelDescriptor { get }
    var onPreview: ((String) -> Void)? { get set }

    func start() throws
    func appendAudio(samples: [Float], sampleRate: Int)
    func stop() async throws -> String
    func cancel()
}
