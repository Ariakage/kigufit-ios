import Foundation

nonisolated struct LLMMessage: Codable, Sendable {
    var role: String
    var content: String
}

nonisolated struct LLMClient: Sendable {
    var baseURL: String
    var apiKey: String
    var model: String

    enum ClientError: Error, LocalizedError {
        case invalidURL
        case badResponse
        case http(Int, String)
        case emptyReply

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Base URL 无效"
            case .badResponse: return "服务器响应异常"
            case let .http(code, message): return "请求失败（HTTP \(code)）：\(message)"
            case .emptyReply: return "模型返回了空内容"
            }
        }
    }

    func complete(messages: [LLMMessage], maxTokens: Int = 1200) async throws -> String {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if base.hasSuffix("/") { base.removeLast() }
        let endpoint = base.hasSuffix("/chat/completions") ? base : base + "/chat/completions"
        guard let url = URL(string: endpoint) else { throw ClientError.invalidURL }

        struct Body: Encodable {
            var model: String
            var messages: [LLMMessage]
            var max_tokens: Int
            var stream: Bool
            var temperature: Double
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Body(
            model: model,
            messages: messages,
            max_tokens: maxTokens,
            stream: false,
            temperature: 0.4
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw ClientError.http(http.statusCode, String(text.prefix(300)))
        }
        return try Self.parseContent(from: data)
    }

    static func parseContent(from data: Data) throws -> String {
        struct Reply: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    var content: String?
                }
                var message: Message
            }
            var choices: [Choice]
        }

        let reply: Reply
        do {
            reply = try JSONDecoder().decode(Reply.self, from: data)
        } catch {
            throw ClientError.badResponse
        }
        guard let content = reply.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.emptyReply
        }
        return content
    }
}
