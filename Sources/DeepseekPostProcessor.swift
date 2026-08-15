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
            return fallback(trimmed)
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
                    continuation.yield(fallback(trimmed))
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
                        continuation.yield(fallback(trimmed))
                        continuation.finish()
                        return
                    }

                    var bufferedOutput = ""
                    var receivedDone = false
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }

                        let dataLine = String(line.dropFirst(6))
                        if dataLine == "[DONE]" {
                            receivedDone = true
                            break
                        }

                        guard let data = dataLine.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(DeepseekStreamResponse.self, from: data),
                              let content = chunk.choices.first?.delta.content,
                              !content.isEmpty else {
                            continue
                        }

                        bufferedOutput += content
                    }

                    if !receivedDone || bufferedOutput.isEmpty {
                        continuation.yield(fallback(trimmed))
                    } else {
                        continuation.yield(bufferedOutput)
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(fallback(trimmed))
                    continuation.finish()
                }
            }
        }
    }

    private var systemPrompt: String {
        """
        You are a text post-processor for a voice input app used by developers and general users. You receive spoken text that has been transcribed by ASR (speech recognition).
        Your ONLY task: fix transcription errors with the smallest possible edit.
        Rules:
        - NEVER answer questions, never add explanations, never add new content
        - NEVER change meaning, names, numbers, or intent
        - Preserve the input's existing punctuation by default
        - Add punctuation only when omitting it would create clear ambiguity
        - Do not automatically add sentence-ending punctuation
        - Only fix obvious ASR mistakes, capitalization, spacing, and ambiguity-resolving punctuation
        - Preserve mixed Chinese-English speech; correct homophones for technical/programming terms, Git commands, tools, and frameworks (e.g. PR, Git, GitHub, async/await, Docker, Kubernetes, API, TypeScript, JSON, SQL, GraphQL)
        - Insert a space between Chinese characters and English words/numbers (Pangu spacing)
        - If uncertain, leave it unchanged
        Return ONLY the corrected text. No quotes, no preamble, no follow-up.

        Examples:
        Input: "今天下午三点半开会"
        Output: "今天下午 3:30 开会"

        Input: "帮我review一下这个pr"
        Output: "帮我 review 一下这个 PR"

        Input: "把这个函数重构为啊星克二喂特"
        Output: "把这个函数重构为 async await"

        Input: "重新跑一下达克肯破死"
        Output: "重新跑一下 docker-compose"

        Input: "在controller里面加一个get接口"
        Output: "在 controller 里面加一个 GET 接口"

        Input: "我把代码体教上去了"
        Output: "我把代码提交上去了"

        Input: "如果你明天有空我们一起开会"
        Output: "如果你明天有空，我们一起开会"

        Input: "发给张三"
        Output: "发给张三"
        """
    }

    private func fallback(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
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
