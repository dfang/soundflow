import Foundation

final class MockTranscriptionService {
    var onPreview: ((String) -> Void)?

    private let tokens = [
        "今天",
        " review",
        " 一下",
        " 这个",
        " github",
        " pr",
    ]

    private var timer: Timer?
    private var currentText = ""
    private var tokenIndex = 0

    func start() {
        stopTimer()

        currentText = ""
        tokenIndex = 0
        onPreview?("Listening...")

        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            self?.emitNextToken()
        }
    }

    func stop() -> String {
        stopTimer()

        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "帮我 review 一下这个 github pr" : trimmed
    }

    private func emitNextToken() {
        guard tokenIndex < tokens.count else { return }

        currentText += tokens[tokenIndex]
        tokenIndex += 1
        onPreview?(currentText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
