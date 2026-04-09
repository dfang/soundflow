import Foundation

struct PlaceholderGemmaPostProcessor: TextPostProcessing {
    let displayName = PostProcessorBackend.mlxGemma.rawValue
    let model: ModelDescriptor

    func process(_ text: String) async -> String {
        text
    }
}
