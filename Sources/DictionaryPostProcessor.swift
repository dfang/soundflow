import Foundation

struct DictionaryPostProcessor: TextPostProcessing {
    let displayName: String
    let model: ModelDescriptor

    private let wrapped: any TextPostProcessing

    init(wrapping wrapped: any TextPostProcessing) {
        displayName = wrapped.displayName
        model = wrapped.model
        self.wrapped = wrapped
    }

    func process(_ text: String) async -> String {
        let corrected = TextDictionaries.applyDictionaries(to: text)
        return await wrapped.process(corrected)
    }

    func processStream(rawText: String) -> AsyncThrowingStream<String, Error> {
        let corrected = TextDictionaries.applyDictionaries(to: rawText)
        return wrapped.processStream(rawText: corrected)
    }
}
