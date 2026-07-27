import Foundation

/// Seam for where assistant replies come from (see SETTINGS_PROFILE_SPEC §1).
///
/// The UI never references `DeepSeekClient` directly; it asks the view-model
/// which backend is configured. The default and only offline path is `.local`
/// (the rule-based `UniverseAssistantCore`). `.hosted` is the future app-owned
/// service that holds credentials and enforces quota — NOT built yet. DeepSeek
/// is reachable only through `.debugDeepSeek`, gated behind developer mode, so
/// a normal build always resolves to `.local`.
enum AssistantBackend: Equatable, Sendable {
    /// Rule-based on-device assistant. Default; always available; offline.
    case local
    /// Future app-owned hosted service. Not implemented.
    case hosted
    /// DEBUG/developer-only DeepSeek path, keyed from the Keychain.
    case debugDeepSeek

    /// Resolves the active backend from current configuration. Release builds
    /// (and any build without developer mode + a stored key) get `.local`.
    static func resolve(developerModeEnabled: Bool, hasDeepSeekKey: Bool) -> AssistantBackend {
        #if DEBUG
        if developerModeEnabled && hasDeepSeekKey {
            return .debugDeepSeek
        }
        #endif
        return .local
    }
}

/// One-method seam over the network assistant so the `.debugDeepSeek`
/// success/failure paths are unit-testable without hitting the network.
/// `DeepSeekClient` is the only production conformer; tests inject a stub.
protocol AssistantResponder: Sendable {
    func reply(to userQuery: String, systemPrompt: String?, apiKey: String?) async throws -> String
}

/// Release builds have no provider client or API-key store. This responder
/// exists solely to preserve the view-model's injectable seam; it is never
/// selected by the release backend resolver.
struct UnavailableAssistantResponder: AssistantResponder {
    func reply(to userQuery: String, systemPrompt: String?, apiKey: String?) async throws -> String {
        throw CancellationError()
    }
}

enum AssistantResponderFactory {
    static let defaultResponder: any AssistantResponder = {
        #if DEBUG
        return DeepSeekClient()
        #else
        return UnavailableAssistantResponder()
        #endif
    }()
}
