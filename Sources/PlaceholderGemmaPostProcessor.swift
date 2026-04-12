import Foundation

struct PlaceholderGemmaPostProcessor: TextPostProcessing {
    let displayName = PostProcessorBackend.mlxGemma.rawValue
    let model: ModelDescriptor

    func processStream(rawText: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            continuation.yield(rawText)
            continuation.finish()
        }
    }

    func process(_ text: String) async -> String {
        text
    }
}
