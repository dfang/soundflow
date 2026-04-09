import Foundation

struct PassthroughPostProcessor: TextPostProcessing {
    let displayName = PostProcessorBackend.disabled.rawValue
    let model: ModelDescriptor

    func process(_ text: String) async -> String {
        text
    }
}
