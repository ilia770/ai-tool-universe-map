import CoreGraphics
import Foundation
import OSLog

/// Force-directed Bloom graph engine (variant K). Holds node positions + the
/// progressive-reveal state (a stack of expansion steps). `revealed` is derived
/// from the stack so expand = push, collapse = truncate, and the two can never
/// disagree. The view ticks the sim each frame and reads `nodes`.
final class BloomEngine {
    struct Node {
        let id: String
        var x: Double, y: Double
        var vx: Double = 0, vy: Double = 0
        var appear: Double           // 0→1 spring-in (collapse fades back to 0)
        var collapsing: Bool = false
        var px: Double, py: Double    // spring-home target while collapsing
    }

    static let nodeRadius: Double = 30

    /// Perf instrumentation only — inert unless an Instruments trace is running.
    private let signposter = OSSignposter(subsystem: "com.iliaturilia.myaimap", category: "bloom")

    private let adjacency: [String: [String]]
    let seedID: String

    private(set) var nodes: [String: Node] = [:]
    private(set) var stack: [(parent: String, introduced: [String])] = []
    private(set) var focusID: String
    private var fanSeed: [String: (px: Double, py: Double)] = [:]
    var camX: Double = 0
    var camY: Double = 0

    init(adjacency: [String: [String]], seedID: String) {
        self.adjacency = adjacency
        self.seedID = seedID
        self.focusID = seedID
        let seedNeighbours = adjacency[seedID] ?? []
        stack = [(seedID, seedNeighbours)]
        syncNodes()
    }

    var revealed: Set<String> {
        var s = Set<String>()
        for step in stack { s.insert(step.parent); s.formUnion(step.introduced) }
        return s
    }

    func hasHidden(_ id: String) -> Bool {
        let r = revealed
        return (adjacency[id] ?? []).contains { !r.contains($0) }
    }

    func isExpanded(_ id: String) -> Bool {
        guard let idx = stack.lastIndex(where: { $0.parent == id }) else { return false }
        return idx > 0 || id == seedID
    }

    /// Visible edges (both endpoints revealed, neither collapsing).
    func visibleEdges(_ allEdges: [(a: String, b: String)]) -> [(a: String, b: String)] {
        allEdges.filter { e in
            guard let na = nodes[e.a], let nb = nodes[e.b] else { return false }
            return !na.collapsing && !nb.collapsing
        }
    }

    // MARK: - Reveal mechanic

    func tap(_ id: String) {
        if hasHidden(id) {
            expand(id)
        } else if isExpanded(id) && id != seedID {
            collapse(id)
        } else {
            focusID = id
        }
    }

    func expand(_ id: String) {
        guard revealed.contains(id), let node = nodes[id] else { return }
        let r = revealed
        let hidden = (adjacency[id] ?? []).filter { !r.contains($0) }
        guard !hidden.isEmpty else { return }

        // Radial fan: seed each hidden node around the parent, opening outward.
        let baseAngle = atan2(node.y - camY, node.x - camX)
        let spread = min(Double.pi * 1.5, 0.55 * Double(hidden.count) + 0.6)
        for (i, nb) in hidden.enumerated() {
            let t = hidden.count == 1 ? 0.5 : Double(i) / Double(hidden.count - 1)
            let jitter = (sin(Double(i) * 53.13) * 0.5) * 0.12
            let ang = baseAngle + (t - 0.5) * spread + jitter
            let nudge = Self.nodeRadius * 0.9 + Double(i) * 0.4
            fanSeed[nb] = (node.x + cos(ang) * nudge, node.y + sin(ang) * nudge)
        }
        stack.append((id, hidden))
        focusID = id
        syncNodes()
    }

    func collapse(_ id: String) {
        guard let idx = stack.lastIndex(where: { $0.parent == id }), idx > 0 else { return }
        stack = Array(stack[0..<idx])
        focusID = stack.last?.parent ?? seedID
        syncNodes()
    }

    /// Truncate the stack to `count` steps (breadcrumb jump). `count >= 1`.
    func collapseTo(stepCount: Int) {
        let n = max(1, min(stepCount, stack.count))
        guard n < stack.count else { return }
        stack = Array(stack[0..<n])
        focusID = stack.last?.parent ?? seedID
        syncNodes()
    }

    func collapseLast() {
        guard stack.count > 1 else { return }
        stack.removeLast()
        focusID = stack.last?.parent ?? seedID
        syncNodes()
    }

    func reset() {
        stack = [(seedID, adjacency[seedID] ?? [])]
        focusID = seedID
        syncNodes()
    }

    func focus(_ id: String) { focusID = id }

    /// Breadcrumb labels (one per stack step's parent).
    var breadcrumb: [String] { stack.map(\.parent) }

    // MARK: - Sim

    private func syncNodes() {
        let r = revealed
        for id in r where nodes[id] == nil {
            if let seed = fanSeed[id] {
                nodes[id] = Node(id: id, x: seed.px, y: seed.py, appear: 0, px: seed.px, py: seed.py)
                fanSeed[id] = nil
            } else if id == seedID {
                nodes[id] = Node(id: id, x: 0, y: 0, appear: 1, px: 0, py: 0)
            } else {
                let anchor = (adjacency[id] ?? []).compactMap { nodes[$0] }.first
                let ox = (anchor?.x ?? 0) + 1, oy = (anchor?.y ?? 0) + 1
                nodes[id] = Node(id: id, x: ox, y: oy, appear: 0, px: ox, py: oy)
            }
        }
        for (id, var node) in nodes {
            if r.contains(id) {
                if node.collapsing { node.collapsing = false; nodes[id] = node }
            } else if !node.collapsing {
                node.collapsing = true
                let anchor = (adjacency[id] ?? []).compactMap { nodes[$0] }
                    .first { r.contains($0.id) && !$0.collapsing }
                node.px = anchor?.x ?? 0
                node.py = anchor?.y ?? 0
                nodes[id] = node
            }
        }
    }

    func tick(dt: Double, reduced: Bool, allEdges: [(a: String, b: String)]) {
        let signpostState = signposter.beginInterval("bloom.tick")
        defer { signposter.endInterval("bloom.tick", signpostState) }

        let rest = Self.nodeRadius * 4.6
        var ids = Array(nodes.keys)

        // Repulsion (O(n²) — fine for the revealed subset).
        for i in 0..<ids.count {
            guard var a = nodes[ids[i]], !a.collapsing else { continue }
            for j in (i + 1)..<ids.count {
                guard let b0 = nodes[ids[j]], !b0.collapsing else { continue }
                var dx = a.x - b0.x, dy = a.y - b0.y
                var d2 = dx * dx + dy * dy
                if d2 < 0.01 { dx = Double(i - j) * 0.5 + 0.1; dy = 0.1; d2 = dx * dx + dy * dy }
                let d = d2.squareRoot()
                let f = 18000 / d2
                let fx = (dx / d) * f, fy = (dy / d) * f
                a.vx += fx; a.vy += fy
                var b = b0; b.vx -= fx; b.vy -= fy; nodes[ids[j]] = b
            }
            nodes[ids[i]] = a
        }

        // Springs on visible edges.
        for e in visibleEdges(allEdges) {
            guard var a = nodes[e.a], var b = nodes[e.b] else { continue }
            let dx = b.x - a.x, dy = b.y - a.y
            let d = max((dx * dx + dy * dy).squareRoot(), 0.001)
            let k = (d - rest) * 0.012
            let fx = (dx / d) * k, fy = (dy / d) * k
            a.vx += fx; a.vy += fy; b.vx -= fx; b.vy -= fy
            nodes[e.a] = a; nodes[e.b] = b
        }

        // Integrate + appear ramp + collapse fade.
        let appearGain = reduced ? 0.2 : 0.12
        let appearBias = reduced ? 0.02 : 0.012
        for id in ids {
            guard var n = nodes[id] else { continue }
            if n.collapsing {
                n.x += (n.px - n.x) * 0.16
                n.y += (n.py - n.y) * 0.16
                n.vx = 0; n.vy = 0
                n.appear += (0 - n.appear) * 0.18 - 0.012
                if n.appear <= 0.02 { nodes[id] = nil; continue }
                nodes[id] = n
                continue
            }
            n.vx += -n.x * 0.0009
            n.vy += -n.y * 0.0009
            n.vx *= 0.86; n.vy *= 0.86
            n.x += n.vx; n.y += n.vy
            if n.appear < 1 { n.appear = min(1, n.appear + (1 - n.appear) * appearGain + appearBias) }
            nodes[id] = n
        }

        // Camera eases toward the focused node.
        let camEase = reduced ? 0.16 : 0.09
        if let f = nodes[focusID], !f.collapsing {
            camX += (f.x - camX) * camEase
            camY += (f.y - camY) * camEase
        }
    }
}
