import Foundation

/// The injectable HTTP seam for the Anthropic Messages API. A `struct` with
/// a single closure so tests can substitute a stub that returns recorded
/// JSON without any network — and so the real wire format stays isolated in
/// `.live`. The API key is passed per-call (read fresh from the Keychain by
/// the service) and never stored on the client.
struct ClaudeClient: Sendable {
    /// Send one request with the given API key, returning the parsed slice
    /// of the response the service needs. Throws `IntelligenceError` for
    /// auth / transient / bad-request / decode failures.
    var send: @Sendable (_ request: ClaudeRequest, _ apiKey: String) async throws -> ClaudeResponse

    /// The real `URLSession` implementation. The only place that touches the
    /// network or knows the header/HTTP-status contract.
    static let live = ClaudeClient { request, apiKey in
        var urlRequest = URLRequest(url: IntelligenceConfig.baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(IntelligenceConfig.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try request.httpBody()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            // Network/transport failure — treat as transient (retryable).
            throw IntelligenceError.transient(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw IntelligenceError.transient(nil)
        }

        switch http.statusCode {
        case 200...299:
            return try ClaudeResponse.decode(data)
        case 400:
            let detail = String(data: data, encoding: .utf8) ?? "bad request"
            throw IntelligenceError.badRequest(detail)
        case 401, 403:
            throw IntelligenceError.authFailed
        case 429, 500...599:
            // Includes Anthropic's 529 (overloaded).
            throw IntelligenceError.transient(nil)
        default:
            throw IntelligenceError.transient(nil)
        }
    }
}
