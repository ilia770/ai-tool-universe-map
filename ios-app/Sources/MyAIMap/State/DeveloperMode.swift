import Foundation

/// Hidden developer-mode flag. OFF by default and NOT toggleable from the
/// consumer Settings UI. Gates the DeepSeek API-key entry surface so a normal
/// user never sees or manages a raw provider key (see SETTINGS_PROFILE_SPEC §1).
///
/// The whole type compiles out of release builds (`#if DEBUG`); even in DEBUG
/// it stays off until explicitly enabled via the `developer.modeEnabled`
/// UserDefaults key (e.g. from a test or a debugger).
enum DeveloperMode {
    static let defaultsKey = "developer.modeEnabled"

    /// True only in a DEBUG build with the hidden flag set. Always false in
    /// release, so the key-entry UI cannot appear in a shipping build.
    static var isEnabled: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: defaultsKey)
        #else
        return false
        #endif
    }
}
