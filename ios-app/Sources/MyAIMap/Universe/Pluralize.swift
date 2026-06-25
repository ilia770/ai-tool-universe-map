/// Tiny pure pluralization helper so count labels read naturally: "1 tool"
/// instead of "1 tools", "2 satellites" instead of "2 satellite".
enum Pluralize {
    /// Returns "\(n) \(singular)" when n == 1, otherwise "\(n) \(plural)".
    /// `plural` defaults to `singular + "s"`.
    static func count(_ n: Int, _ singular: String, _ plural: String? = nil) -> String {
        let word = n == 1 ? singular : (plural ?? singular + "s")
        return "\(n) \(word)"
    }
}
