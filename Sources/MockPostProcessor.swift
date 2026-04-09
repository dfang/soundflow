import Foundation

struct MockPostProcessor: TextPostProcessing {
    let displayName = PostProcessorBackend.mockGemma.rawValue
    let model: ModelDescriptor

    func process(_ text: String) async -> String {
        var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else { return "你好，SoundFlow。" }

        output = output.replacingOccurrences(
            of: "(?i)github",
            with: "GitHub",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "(?i)\\bpr\\b",
            with: "PR",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "(?i)\\breview\\b",
            with: "review",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "([\\p{Han}])([A-Za-z0-9])",
            with: "$1 $2",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "([A-Za-z0-9])([\\p{Han}])",
            with: "$1 $2",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        output = output.trimmingCharacters(in: .whitespacesAndNewlines)

        if !output.hasTerminalPunctuation {
            output += output.containsChinese ? "。" : "."
        }

        return output
    }
}

private extension String {
    var containsChinese: Bool {
        range(of: "\\p{Han}", options: .regularExpression) != nil
    }

    var hasTerminalPunctuation: Bool {
        guard let lastCharacter = last else { return false }
        return ".,!?;:。？！；：".contains(lastCharacter)
    }
}
