import Foundation

struct PassthroughPostProcessor: TextPostProcessing {
    let displayName = PostProcessorBackend.disabled.rawValue
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
