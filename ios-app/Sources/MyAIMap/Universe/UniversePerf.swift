import OSLog

/// Performance instrumentation for the RealityKit universe scene
/// (backlog task 35). Wraps the two hot paths the project review flagged —
/// the one-time RealityView scene build and the per-transition entity
/// restyle/move loop — in `os_signpost` intervals so they are measurable
/// in Instruments before Phase C adds IBL/skybox/particles.
///
/// `OSSignposter` intervals are near-zero-cost when no Instruments tool is
/// attached (the runtime checks an enablement flag and returns early), so
/// there is no need to gate these behind `#if DEBUG` — they can ship.
///
/// Filter in Instruments by subsystem `com.iliaturilia.myaimap`,
/// category `universe`. See docs/perf-ios.md.
enum UniversePerf {
    static let signposter = OSSignposter(
        subsystem: "com.iliaturilia.myaimap",
        category: "universe"
    )

    /// Runs `body` inside a signpost interval named `name`, returning its
    /// result. The interval brackets the call so it never alters control
    /// flow or the returned value — pure instrumentation.
    ///
    /// The closure is non-escaping and `rethrows`, so it inherits the
    /// caller's actor isolation: call sites in the `@MainActor` RealityView
    /// closures can touch main-actor state inside `body` without a hop.
    static func interval<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try body()
    }
}
