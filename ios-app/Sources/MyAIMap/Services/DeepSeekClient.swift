import Foundation

/// Thin OpenAI-compatible client for the DeepSeek chat completions API.
///
/// Used as an optional, cheaper backend for the in-app assistant. The key is
/// user-provided and read from the Keychain at call time — it is never stored
/// here, never logged, and never committed. When no key is present or the call
/// fails, callers fall back to the local rule-based assistant.
///
/// No third-party dependencies — plain URLSession + Codable.
struct DeepSeekClient {
    /// Default OpenAI-compatible base URL.
    static let defaultBaseURL = URL(string: "https://api.deepseek.com")!
    /// Cheaper general chat model.
    static let defaultModel = "deepseek-chat"

    enum ClientError: Error, Equatable {
        case missingAPIKey
        case requestEncodingFailed
        case http(status: Int)
        case emptyResponse
        case decodingFailed
    }

    // MARK: - Wire types (Codable, pure — covered by unit tests)

    struct Message: Codable, Equatable {
        let role: String
        let content: String
    }

    struct ChatRequest: Codable, Equatable {
        let model: String
        let messages: [Message]
        let stream: Bool
    }

    struct ChatResponse: Codable, Equatable {
        struct Choice: Codable, Equatable {
            let message: Message
        }
        let choices: [Choice]
    }

    let baseURL: URL
    let model: String
    private let session: URLSession

    init(
        baseURL: URL = DeepSeekClient.defaultBaseURL,
        model: String = DeepSeekClient.defaultModel,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.model = model
        self.session = session
    }

    // MARK: - Pure helpers (testable without networking)

    /// Builds the request body for a user query plus optional system prompt.
    static func makeRequestBody(
        model: String,
        systemPrompt: String?,
        userQuery: String
    ) -> ChatRequest {
        var messages: [Message] = []
        if let systemPrompt, !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(Message(role: "system", content: systemPrompt))
        }
        messages.append(Message(role: "user", content: userQuery))
        return ChatRequest(model: model, messages: messages, stream: false)
    }

    /// Builds the authorized URLRequest. Returns nil only if the body cannot be
    /// encoded (should not happen for our value types).
    static func makeURLRequest(
        baseURL: URL,
        apiKey: String,
        body: ChatRequest,
        timeout: TimeInterval = 30
    ) -> URLRequest? {
        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        guard let data = try? JSONEncoder().encode(body) else { return nil }
        request.httpBody = data
        return request
    }

    /// Decodes the first non-empty assistant message from a response payload.
    static func firstReply(from data: Data) throws -> String {
        guard let response = try? JSONDecoder().decode(ChatResponse.self, from: data) else {
            throw ClientError.decodingFailed
        }
        guard let text = response.choices.first?.message.content,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.emptyResponse
        }
        return text
    }

    // MARK: - Network

    /// Sends `userQuery` (with optional `systemPrompt`) and returns the
    /// assistant text. Reads the key from the Keychain unless one is passed in.
    /// Throws `ClientError` (missing key, HTTP, decoding) so callers can fall
    /// back to the local assistant.
    func reply(
        to userQuery: String,
        systemPrompt: String? = nil,
        apiKey: String? = nil
    ) async throws -> String {
        let key = apiKey ?? KeychainStore.load(account: KeychainStore.deepSeekAPIKeyAccount)
        guard let key, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.missingAPIKey
        }

        let body = Self.makeRequestBody(model: model, systemPrompt: systemPrompt, userQuery: userQuery)
        guard let request = Self.makeURLRequest(baseURL: baseURL, apiKey: key, body: body) else {
            throw ClientError.requestEncodingFailed
        }

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ClientError.http(status: http.statusCode)
        }
        return try Self.firstReply(from: data)
    }
}

/// The production assistant backend. The existing `reply(to:systemPrompt:apiKey:)`
/// already matches the requirement, so conformance is declaration-only.
extension DeepSeekClient: AssistantResponder {}
