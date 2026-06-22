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
        if developerModeEnabled && hasDeepSeekKey {
            return .debugDeepSeek
        }
        return .local
    }
}
