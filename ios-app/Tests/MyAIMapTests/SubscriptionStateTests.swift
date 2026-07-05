import Testing
import Foundation
@testable import MyAIMap

@Suite("SubscriptionState — placeholder usage math")
struct SubscriptionStateTests {

    @Test func freeDefaultHasFullRemaining() {
        let state = SubscriptionState.free
        #expect(state.plan == .free)
        #expect(state.aiRequestsUsed == 0)
        #expect(state.aiRequestsRemaining == state.aiRequestsLimit)
    }

    @Test func remainingDecrementsOnConsume() {
        var state = SubscriptionState(plan: .free, aiRequestsUsed: 0, aiRequestsLimit: 3)
        state.consumeRequest()
        #expect(state.aiRequestsUsed == 1)
        #expect(state.aiRequestsRemaining == 2)
    }

    @Test func remainingNeverGoesNegativeAndUsedClampsToLimit() {
        var state = SubscriptionState(plan: .free, aiRequestsUsed: 0, aiRequestsLimit: 2)
        state.consumeRequest()
        state.consumeRequest()
        state.consumeRequest() // over the cap
        #expect(state.aiRequestsUsed == 2)
        #expect(state.aiRequestsRemaining == 0)
    }

    @Test func initClampsNegativeInputs() {
        let state = SubscriptionState(plan: .pro, aiRequestsUsed: -5, aiRequestsLimit: -1)
        #expect(state.aiRequestsUsed == 0)
        #expect(state.aiRequestsLimit == 0)
        #expect(state.aiRequestsRemaining == 0)
    }

    @Test func roundTripsThroughCodable() throws {
        let original = SubscriptionState(plan: .pro, aiRequestsUsed: 4, aiRequestsLimit: 20)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SubscriptionState.self, from: data)
        #expect(decoded == original)
    }

    @Test func decodeClampsNegativeUsedToZero() throws {
        let json = #"{"plan":"free","aiRequestsUsed":-7,"aiRequestsLimit":20}"#
        let decoded = try JSONDecoder().decode(SubscriptionState.self, from: Data(json.utf8))
        #expect(decoded.aiRequestsUsed == 0)
        #expect(decoded.aiRequestsLimit == 20)
        #expect(decoded.aiRequestsRemaining == 20)
    }

    @Test func decodeWithUsedOverLimitMatchesMemberwiseInit() throws {
        // Memberwise init only clamps with max(0,…) — it does NOT clamp used to
        // limit — so `used` survives and `remaining` floors at 0.
        let json = #"{"plan":"free","aiRequestsUsed":30,"aiRequestsLimit":20}"#
        let decoded = try JSONDecoder().decode(SubscriptionState.self, from: Data(json.utf8))
        #expect(decoded.aiRequestsUsed == 30)
        #expect(decoded.aiRequestsLimit == 20)
        #expect(decoded.aiRequestsRemaining == 0)
    }

    @Test func decodeNormalPayloadIsUnchanged() throws {
        let json = #"{"plan":"pro","aiRequestsUsed":5,"aiRequestsLimit":20}"#
        let decoded = try JSONDecoder().decode(SubscriptionState.self, from: Data(json.utf8))
        #expect(decoded == SubscriptionState(plan: .pro, aiRequestsUsed: 5, aiRequestsLimit: 20))
    }
}

@Suite("AssistantBackend — debug-gated resolution")
struct AssistantBackendTests {

    @Test func defaultsToLocalWithoutDeveloperMode() {
        #expect(AssistantBackend.resolve(developerModeEnabled: false, hasDeepSeekKey: true) == .local)
        #expect(AssistantBackend.resolve(developerModeEnabled: false, hasDeepSeekKey: false) == .local)
    }

    @Test func usesDeepSeekOnlyWithDeveloperModeAndKey() {
        #expect(AssistantBackend.resolve(developerModeEnabled: true, hasDeepSeekKey: true) == .debugDeepSeek)
        #expect(AssistantBackend.resolve(developerModeEnabled: true, hasDeepSeekKey: false) == .local)
    }
}
