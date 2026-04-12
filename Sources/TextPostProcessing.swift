import Foundation

protocol TextPostProcessing {
    var displayName: String { get }
    var model: ModelDescriptor { get }
    func process(_ text: String) async -> String
    func processStream(rawText: String) -> AsyncThrowingStream<String, Error>
}
