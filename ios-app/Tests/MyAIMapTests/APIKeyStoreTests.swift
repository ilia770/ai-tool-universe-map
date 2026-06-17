import Testing
import Foundation
@testable import MyAIMap

@Suite("APIKeyStore — Keychain round-trips")
struct APIKeyStoreTests {

    /// Each test gets a unique service string so tests are fully isolated
    /// and no prior Keychain state leaks between runs.
    private func freshStore() -> APIKeyStore {
        let service = "com.myaimap.test.apiKey.\(UUID().uuidString)"
        return APIKeyStore(service: service)
    }

    @Test func saveAndReadRoundTrip() throws {
        let store = freshStore()
        defer { store.delete() }

        try store.save("sk-ant-test-key-1")
        #expect(store.read() == "sk-ant-test-key-1")
    }

    @Test func overwriteUpdatesExistingKey() throws {
        let store = freshStore()
        defer { store.delete() }

        try store.save("sk-ant-first")
        try store.save("sk-ant-second")
        #expect(store.read() == "sk-ant-second")
    }

    @Test func deleteRemovesKey() throws {
        let store = freshStore()

        try store.save("sk-ant-ephemeral")
        store.delete()
        #expect(store.read() == nil)
    }

    @Test func readReturnsNilWhenAbsent() {
        let store = freshStore()
        defer { store.delete() }

        #expect(store.read() == nil)
    }

    @Test func hasKeyReflectsPresence() throws {
        let store = freshStore()
        defer { store.delete() }

        #expect(store.hasKey == false)
        try store.save("sk-ant-abc")
        #expect(store.hasKey == true)
        store.delete()
        #expect(store.hasKey == false)
    }
}
