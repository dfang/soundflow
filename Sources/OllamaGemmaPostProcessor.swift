import Foundation

struct OllamaGemmaPostProcessor: TextPostProcessing {
    let displayName = PostProcessorBackend.ollamaGemma.rawValue
    let model: ModelDescriptor

    private let endpoint = URL(string: "http://127.0.0.1:11434/api/generate")!
    private let ollamaModelName = "gemma4:e4b"

    func processStream(rawText: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let result = await process(rawText)
                continuation.yield(result)
                continuation.finish()
            }
        }
    }

    func process(_ text: String) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        do {
            let requestBody = OllamaGenerateRequest(
                model: ollamaModelName,
                prompt: prompt(for: trimmed),
                stream: false,
                think: false,
                options: OllamaOptions(
                    temperature: 0.0,
                    topP: 0.9,
                    numPredict: 96
                )
            )

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode)
            else {
                return await MockPostProcessor(model: model).process(trimmed)
            }

            let payload = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
            let candidate = normalize(payload.response)
            guard !candidate.isEmpty else {
                return await MockPostProcessor(model: model).process(trimmed)
            }

            return candidate
        } catch {
            return await MockPostProcessor(model: model).process(trimmed)
        }
    }

    private func prompt(for text: String) -> String {
        """
        Fix the ASR text with minimal edits. Keep meaning unchanged.
        Only fix punctuation, spacing, capitalization, and obvious ASR mistakes.
        Return only the corrected text.
        ASR:
        \(text)
        """
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

private struct OllamaGenerateRequest: Encodable {
    let model: String
    let prompt: String
    let stream: Bool
    let think: Bool
    let options: OllamaOptions
}

private struct OllamaOptions: Encodable {
    let temperature: Double
    let topP: Double
    let numPredict: Int

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP = "top_p"
        case numPredict = "num_predict"
    }
}

private struct OllamaGenerateResponse: Decodable {
    let response: String
}
