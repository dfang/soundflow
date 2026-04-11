import Foundation

struct SmartPostProcessor: TextPostProcessing {
    let displayName: String
    let model: ModelDescriptor

    private let wrapped: any TextPostProcessing

    init(wrapping wrapped: any TextPostProcessing) {
        self.displayName = wrapped.displayName
        self.model = wrapped.model
        self.wrapped = wrapped
    }

    func process(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard shouldPostProcess(trimmed) else { return trimmed }

        let candidate = await wrapped.process(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return trimmed }
        guard !looksLikeExpansion(original: trimmed, candidate: candidate) else { return trimmed }

        return candidate
    }

    private func shouldPostProcess(_ text: String) -> Bool {
        if text.count <= 6 {
            return false
        }

        if hasFillerWord(in: text) {
            return true
        }

        if hasRepeatedToken(in: text) {
            return true
        }

        if hasExcessWhitespace(in: text) {
            return true
        }

        if hasRepeatedPunctuation(in: text) {
            return true
        }

        if hasAbnormalSymbols(in: text) {
            return true
        }

        if hasMixedScriptSpacingIssue(in: text) && isLongRunWithoutPunctuation(text) {
            return true
        }

        if isLongRunWithoutPunctuation(text) {
            return true
        }

        if hasTerminalPunctuation(text) {
            return false
        }

        if text.count <= 12 {
            return false
        }

        return false
    }

    private func hasFillerWord(in text: String) -> Bool {
        text.range(
            of: "(嗯|呃|额|啊这个|那个|就是|然后就是|怎么说呢|你知道吧)",
            options: .regularExpression
        ) != nil
    }

    private func hasRepeatedToken(in text: String) -> Bool {
        text.range(
            of: "([\\p{Han}A-Za-z]{1,6})\\s*\\1",
            options: .regularExpression
        ) != nil
    }

    private func hasMixedScriptSpacingIssue(in text: String) -> Bool {
        text.range(of: "([\\p{Han}])([A-Za-z0-9])", options: .regularExpression) != nil ||
        text.range(of: "([A-Za-z0-9])([\\p{Han}])", options: .regularExpression) != nil
    }

    private func hasExcessWhitespace(in text: String) -> Bool {
        text.range(of: "\\s{2,}", options: .regularExpression) != nil
    }

    private func hasRepeatedPunctuation(in text: String) -> Bool {
        text.range(of: "[，。！？；：,.!?;:]{2,}", options: .regularExpression) != nil
    }

    private func hasAbnormalSymbols(in text: String) -> Bool {
        text.range(of: "[^\\p{Han}A-Za-z0-9\\s，。！？；：,.!?;:'\"()\\-]", options: .regularExpression) != nil
    }

    private func isLongRunWithoutPunctuation(_ text: String) -> Bool {
        let compact = text.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        guard compact.count >= 18 else { return false }
        return compact.range(of: "[，。！？；：,.!?;:]", options: .regularExpression) == nil
    }

    private func hasTerminalPunctuation(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespacesAndNewlines).last else { return false }
        return ".,!?;:。？！；：".contains(last)
    }

    private func looksLikeExpansion(original: String, candidate: String) -> Bool {
        candidate.count > max(original.count * 3 / 2, original.count + 12)
    }
}
