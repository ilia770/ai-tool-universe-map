import Foundation

/// PLACEHOLDER subscription / usage model — no real billing, no StoreKit, no
/// network (see SETTINGS_PROFILE_SPEC §2). It exists only to lay out the
/// Account / Plan settings group and a local AI-usage counter so the numbers
/// visibly move. A real backend will own quota enforcement later; until then
/// these are local counters for layout only.
enum SubscriptionPlan: String, Codable, Equatable, Sendable {
    case free
    case pro

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        }
    }
}

/// Local placeholder usage + plan snapshot. Persisted like
/// `hapticsEnabled`. `aiRequestsUsed` increments on each Ask-AI send so the
/// "remaining" number decrements perceptibly; clamping keeps it sane.
struct SubscriptionState: Codable, Equatable, Sendable {
    var plan: SubscriptionPlan
    var aiRequestsUsed: Int
    var aiRequestsLimit: Int

    /// Default free tier: a small monthly placeholder cap.
    static let free = SubscriptionState(plan: .free, aiRequestsUsed: 0, aiRequestsLimit: 20)

    init(plan: SubscriptionPlan = .free, aiRequestsUsed: Int = 0, aiRequestsLimit: Int = 20) {
        self.plan = plan
        self.aiRequestsUsed = max(0, aiRequestsUsed)
        self.aiRequestsLimit = max(0, aiRequestsLimit)
    }

    private enum CodingKeys: String, CodingKey {
        case plan
        case aiRequestsUsed
        case aiRequestsLimit
    }

    /// Decodes persisted state through the SAME clamping as the memberwise init,
    /// so a corrupted payload (e.g. negative `aiRequestsUsed`) round-trips sane.
    /// Keys match the synthesized encoder, so existing saved data still loads.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            plan: try container.decode(SubscriptionPlan.self, forKey: .plan),
            aiRequestsUsed: try container.decode(Int.self, forKey: .aiRequestsUsed),
            aiRequestsLimit: try container.decode(Int.self, forKey: .aiRequestsLimit)
        )
    }

    /// Remaining requests, never negative even if used exceeds the cap.
    var aiRequestsRemaining: Int {
        max(0, aiRequestsLimit - aiRequestsUsed)
    }

    /// Records one AI request against the local counter, clamped to the cap so
    /// the placeholder never shows a negative remaining count.
    mutating func consumeRequest() {
        aiRequestsUsed = min(aiRequestsLimit, aiRequestsUsed + 1)
    }
}
