import Foundation
import Testing
@testable import MyAIMap

@Suite("IntelligenceService — Claude core, offline-graceful")
struct IntelligenceServiceTests {

    // MARK: - Test fixtures

    /// A trivial schema-shaped payload the stub returns and the service
    /// decodes. Stands in for the four real job DTOs.
    private struct Sample: Codable, Sendable, Equatable {
        let name: String
        let score: Int
    }

    /// A throwaway schema — the stub client ignores it (wire format is
    /// exercised only by `.live`, which tests never hit).
    private let schema = JSONSchema([
        "type": "object",
        "properties": ["name": ["type": "string"], "score": ["type": "integer"]],
        "required": ["name", "score"],
    ])

    /// Counts stub `send` invocations across the actor boundary so a test
    /// can assert the client was (or was NOT) called.
    private final class CallCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0
        func increment() { lock.lock(); value += 1; lock.unlock() }
        var count: Int { lock.lock(); defer { lock.unlock() }; return value }
    }

    /// A unique, empty Keychain-backed store per test. Caller cleans up in
    /// `defer` so no Keychain item leaks between runs.
    private func uniqueStore() -> APIKeyStore {
        APIKeyStore(service: "com.myaimap.tests.\(UUID().uuidString)")
    }

    /// Build a stub client returning a fixed response, recording calls.
    private func stub(
        counter: CallCounter,
        response: @escaping @Sendable () throws -> ClaudeResponse
    ) -> ClaudeClient {
        ClaudeClient { _, _ in
            counter.increment()
            return try response()
        }
    }

    /// A success response whose `tool_use.input` matches `Sample`.
    private func successResponse(name: String, score: Int) -> ClaudeResponse {
        let body = """
        {
          "stop_reason": "tool_use",
          "content": [
            { "type": "tool_use", "name": "emit", "input": { "name": "\(name)", "score": \(score) } }
          ]
        }
        """
        return try! ClaudeResponse.decode(Data(body.utf8))
    }

    // MARK: - Tests

    @Test func noKeyReturnsOfflineNudge() async {
        let store = uniqueStore()
        defer { store.delete() }
        let counter = CallCounter()
        let client = stub(counter: counter) {
            Issue.record("client must not be invoked when no key is present")
            return ClaudeResponse(stopReason: nil, toolInput: nil)
        }
        let service = IntelligenceService(keychain: store, client: client)

        let result = await service.complete(
            job: .identify, system: "s", user: "u", schema: schema, as: Sample.self
        )

        guard case .offline(.noKey) = result else {
            Issue.record("expected .offline(.noKey), got \(result)")
            return
        }
        #expect(counter.count == 0)
    }

    @Test func isConfiguredReflectsKeyPresence() async throws {
        let store = uniqueStore()
        defer { store.delete() }
        let service = IntelligenceService(keychain: store, client: .live)

        #expect(await service.isConfigured() == false)
        try store.save("sk-test")
        #expect(await service.isConfigured() == true)
    }

    @Test func authErrorMapsToOffline() async throws {
        let store = uniqueStore()
        defer { store.delete() }
        try store.save("sk-bad")
        let counter = CallCounter()
        let client = stub(counter: counter) { throw IntelligenceError.authFailed }
        let service = IntelligenceService(keychain: store, client: client)

        let result = await service.complete(
            job: .place, system: "s", user: "u", schema: schema, as: Sample.self
        )

        guard case .offline(.authFailed) = result else {
            Issue.record("expected .offline(.authFailed), got \(result)")
            return
        }
        #expect(counter.count == 1)
    }

    @Test func transientErrorMapsToOffline() async throws {
        let store = uniqueStore()
        defer { store.delete() }
        try store.save("sk-ok")
        let counter = CallCounter()
        // Simulate a 529 overloaded surfaced as a transient error.
        let client = stub(counter: counter) { throw IntelligenceError.transient(nil) }
        let service = IntelligenceService(keychain: store, client: client)

        let result = await service.complete(
            job: .infer, system: "s", user: "u", schema: schema, as: Sample.self
        )

        guard case .offline(.transient) = result else {
            Issue.record("expected .offline(.transient), got \(result)")
            return
        }
    }

    @Test func refusalIsNotOk() async throws {
        let store = uniqueStore()
        defer { store.delete() }
        try store.save("sk-ok")
        let counter = CallCounter()
        // Refusal with NO usable tool_use content — proves stop_reason is
        // checked before any attempt to read/decode content.
        let refusal = ClaudeResponse(stopReason: "refusal", toolInput: nil)
        let client = stub(counter: counter) { refusal }
        let service = IntelligenceService(keychain: store, client: client)

        let result = await service.complete(
            job: .chatCreate, system: "s", user: "u", schema: schema, as: Sample.self
        )

        guard case .refused = result else {
            Issue.record("expected .refused, got \(result)")
            return
        }
    }

    @Test func malformedJSONDegrades() async throws {
        let store = uniqueStore()
        defer { store.delete() }
        try store.save("sk-ok")
        let counter = CallCounter()
        // Valid response envelope, but tool_use input is the wrong shape for
        // Sample — decode fails, must degrade (not crash).
        let body = """
        { "stop_reason": "tool_use",
          "content": [ { "type": "tool_use", "name": "emit", "input": { "unexpected": true } } ] }
        """
        let response = try ClaudeResponse.decode(Data(body.utf8))
        let client = stub(counter: counter) { response }
        let service = IntelligenceService(keychain: store, client: client)

        let result = await service.complete(
            job: .identify, system: "s", user: "u", schema: schema, as: Sample.self
        )

        guard case .offline(.transient) = result else {
            Issue.record("expected .offline(.transient), got \(result)")
            return
        }
    }

    @Test func validResponseDecodes() async throws {
        let store = uniqueStore()
        defer { store.delete() }
        try store.save("sk-ok")
        let counter = CallCounter()
        let response = successResponse(name: "Figma", score: 9)
        let client = stub(counter: counter) { response }
        let service = IntelligenceService(keychain: store, client: client)

        let result = await service.complete(
            job: .identify, system: "s", user: "u", schema: schema, as: Sample.self
        )

        guard case .ok(let value) = result else {
            Issue.record("expected .ok, got \(result)")
            return
        }
        #expect(value == Sample(name: "Figma", score: 9))
        #expect(counter.count == 1)
    }
}
