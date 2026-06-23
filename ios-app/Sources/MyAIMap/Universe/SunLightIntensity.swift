/// Per-mode brightness for a category sun's PointLight, so lighting follows the
/// same focus hierarchy as mesh opacity: the focused system is lit, the rest
/// recede, and overview glows softly without blowing out (8 suns at once).
enum SunLightIntensity {
    static func intensity(for mode: UniverseMode, isFocused: Bool) -> Float {
        switch mode {
        case .overview:
            return 2200
        case .branchFocus, .toolSelected:
            return isFocused ? 5200 : 1400
        case .detail:
            return isFocused ? 3000 : 500
        case .chatOpen:
            return isFocused ? 2600 : 1000
        }
    }
}
