import Foundation

struct DeepseekPostProcessor: TextPostProcessing {
    let displayName = PostProcessorBackend.deepseek.rawValue
    let model: ModelDescriptor

    private let endpoint = URL(string: "https://api.deepseek.com/v1/chat/completions")!
    private let modelName = "deepseek-chat"

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "deepseekApiKey") ?? ""
    }

    func process(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard !apiKey.isEmpty else {
            return await fallback(trimmed)
        }

        do {
            let requestBody = DeepseekRequest(
                model: modelName,
                messages: [
                    ChatMessage(role: "system", content: systemPrompt),
                    ChatMessage(role: "user", content: trimmed)
                ],
                temperature: 0.0,
                maxTokens: 96
            )

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return await fallback(trimmed)
            }

            let payload = try JSONDecoder().decode(DeepseekResponse.self, from: data)
            let candidate = payload.choices.first?.message.content
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !candidate.isEmpty else {
                return await fallback(trimmed)
            }

            return candidate
        } catch {
            return await fallback(trimmed)
        }
    }

    private var systemPrompt: String {
        """
        You are a text post-processor for a voice input app.
        Fix ASR text with minimal edits. Keep meaning unchanged.
        Only fix: punctuation, spacing, capitalization, obvious ASR mistakes.
        Return ONLY the corrected text. No explanation, no quotes.
        """
    }

    private func fallback(_ text: String) async -> String {
        await MockPostProcessor(model: model).process(text)
    }
}

private struct DeepseekRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct DeepseekResponse: Decodable {
    let choices: [DeepseekChoice]
}

private struct DeepseekChoice: Decodable {
    let message: ChatMessageContent
}

private struct ChatMessageContent: Decodable {
    let role: String
    let content: String
}
