import Foundation
import Testing
@testable import MyAIMap

@Suite("DeepSeekClient — pure request/response pieces (no network)")
struct DeepSeekClientTests {
    @Test func requestBodyIncludesSystemAndUserMessages() {
        let body = DeepSeekClient.makeRequestBody(
            model: "deepseek-chat",
            systemPrompt: "ground rules",
            userQuery: "which tool for design?"
        )
        #expect(body.model == "deepseek-chat")
        #expect(body.stream == false)
        #expect(body.messages.count == 2)
        #expect(body.messages[0] == .init(role: "system", content: "ground rules"))
        #expect(body.messages[1] == .init(role: "user", content: "which tool for design?"))
    }

    @Test func requestBodyOmitsBlankSystemPrompt() {
        let body = DeepSeekClient.makeRequestBody(model: "deepseek-chat", systemPrompt: "   ", userQuery: "hi")
        #expect(body.messages.count == 1)
        #expect(body.messages[0].role == "user")

        let none = DeepSeekClient.makeRequestBody(model: "deepseek-chat", systemPrompt: nil, userQuery: "hi")
        #expect(none.messages.count == 1)
    }

    @Test func urlRequestTargetsChatCompletionsWithBearerAuth() throws {
        let body = DeepSeekClient.makeRequestBody(model: "deepseek-chat", systemPrompt: nil, userQuery: "hi")
        let request = try #require(
            DeepSeekClient.makeURLRequest(baseURL: DeepSeekClient.defaultBaseURL, apiKey: "sk-test", body: body)
        )
        #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody != nil)
    }

    @Test func decodesFirstAssistantReply() throws {
        let json = """
        {"choices":[{"message":{"role":"assistant","content":"Use Figma for design."}}]}
        """
        let text = try DeepSeekClient.firstReply(from: Data(json.utf8))
        #expect(text == "Use Figma for design.")
    }

    @Test func emptyChoicesThrowsEmptyResponse() {
        let json = #"{"choices":[]}"#
        #expect(throws: DeepSeekClient.ClientError.emptyResponse) {
            _ = try DeepSeekClient.firstReply(from: Data(json.utf8))
        }
    }

    @Test func malformedPayloadThrowsDecodingFailed() {
        #expect(throws: DeepSeekClient.ClientError.decodingFailed) {
            _ = try DeepSeekClient.firstReply(from: Data("not json".utf8))
        }
    }

    @Test func missingKeyGatesNetworkCall() async {
        // No apiKey passed and (in CI) no Keychain entry → missingAPIKey, never
        // touches the network.
        let client = DeepSeekClient()
        await #expect(throws: DeepSeekClient.ClientError.missingAPIKey) {
            _ = try await client.reply(to: "hi", systemPrompt: nil, apiKey: "   ")
        }
    }
}

@Suite("KeychainStore — save/load/delete round trip")
struct KeychainStoreTests {
    // Isolated account so the test never collides with a real user key.
    private let account = "deepseek.apiKey.test"

    @Test func saveLoadDeleteRoundTrip() {
        KeychainStore.delete(account: account)
        #expect(KeychainStore.hasValue(account: account) == false)

        #expect(KeychainStore.save("sk-secret", account: account))
        #expect(KeychainStore.load(account: account) == "sk-secret")
        #expect(KeychainStore.hasValue(account: account))

        // Overwrite.
        #expect(KeychainStore.save("sk-second", account: account))
        #expect(KeychainStore.load(account: account) == "sk-second")

        // Saving blank deletes.
        #expect(KeychainStore.save("   ", account: account))
        #expect(KeychainStore.hasValue(account: account) == false)
    }
}
