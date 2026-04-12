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

        var result = ""
        do {
            for try await token in processStream(rawText: trimmed) {
                result += token
            }
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return await fallback(trimmed)
        }
    }

    func processStream(rawText: String) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continuation.finish()
                return
            }
            guard !apiKey.isEmpty else {
                Task {
                    await continuation.yield(fallback(trimmed))
                    continuation.finish()
                }
                return
            }

            Task {
                do {
                    let requestBody = DeepseekRequest(
                        model: modelName,
                        messages: [
                            ChatMessage(role: "system", content: systemPrompt),
                            ChatMessage(role: "user", content: trimmed)
                        ],
                        temperature: 0.0,
                        maxTokens: 96,
                        stream: true
                    )

                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 20
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try JSONEncoder().encode(requestBody)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200 ..< 300).contains(httpResponse.statusCode) else {
                        await continuation.yield(fallback(trimmed))
                        continuation.finish()
                        return
                    }

                    var emittedToken = false
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }

                        let dataLine = String(line.dropFirst(6))
                        if dataLine == "[DONE]" { break }

                        guard let data = dataLine.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(DeepseekStreamResponse.self, from: data),
                              let content = chunk.choices.first?.delta.content,
                              !content.isEmpty else {
                            continue
                        }

                        emittedToken = true
                        continuation.yield(content)
                    }

                    if !emittedToken {
                        await continuation.yield(fallback(trimmed))
                    }
                    continuation.finish()
                } catch {
                    await continuation.yield(fallback(trimmed))
                    continuation.finish()
                }
            }
        }
    }

    private var systemPrompt: String {
        """
        You are a text post-processor for a voice input app. You receive spoken text that has been transcribed by ASR (speech recognition).
        Your ONLY task: fix transcription errors with the smallest possible edit.
        Rules:
        - NEVER answer questions, never add explanations, never add new content
        - NEVER change meaning, names, numbers, or intent
        - Only fix: missing punctuation, incorrect words that are obvious ASR mistakes, capitalization
        - If uncertain, leave it unchanged
        Return ONLY the corrected text. No quotes, no preamble, no follow-up.

        Examples:
        Input: "今天下午三点半开会"
        Output: "今天下午3:30开会"

        Input: "帮我review一下这个pr"
        Output: "帮我 review 一下这个 PR"

        Input: "我把代码体教上去了"
        Output: "我把代码提交上去了"

        Input: "今天天气真好啊我们出去玩吧"
        Output: "今天天气真好啊，我们出去玩吧。"

        Input: "发给张三"
        Output: "发给张三"
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
    let stream: Bool
}

private struct DeepseekStreamResponse: Decodable {
    let choices: [DeepseekStreamChoice]
}

private struct DeepseekStreamChoice: Decodable {
    let delta: DeepseekDelta
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
    let role: String?
    let content: String
}

private struct DeepseekDelta: Decodable {
    let role: String?
    let content: String?
}
