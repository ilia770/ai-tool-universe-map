import CoreGraphics
import Foundation

struct StarNode: Identifiable, Equatable, Sendable {
    let id: String
    let toolID: String?
    let title: String
    let category: ToolCategoryId
    let position: CGPoint
    let radius: CGFloat
    let isCore: Bool
}

struct ConstellationCluster: Identifiable, Equatable, Sendable {
    let id: ToolCategoryId
    let center: CGPoint
    let radius: CGFloat
    let starIDs: [String]
}

struct ConstellationLayoutResult: Equatable, Sendable {
    let stars: [StarNode]
    let clusters: [ConstellationCluster]
}

/// Deterministic clustered star-field. Core star centred; each category is a
/// cluster on an ellipse around it; each cluster's tools spiral around the
/// cluster centre. A relaxation pass removes circle overlaps. No randomness —
/// positions derive only from indices so the layout is stable + testable.
enum ConstellationLayout {

    private static func radius(for orbit: OrbitRing) -> CGFloat {
        switch orbit {
        case .core: return 26
        case .inner: return 12
        case .middle: return 10
        case .outer: return 8
        }
    }

    static func make(planets: [PlanetData], size: CGSize) -> ConstellationLayoutResult {
        guard !planets.isEmpty else { return ConstellationLayoutResult(stars: [], clusters: []) }

        let width = max(size.width, 320)
        let height = max(size.height, 560)
        let insetX: CGFloat = 28, insetTop: CGFloat = 120, insetBottom: CGFloat = 200
        let field = CGRect(x: insetX, y: insetTop,
                           width: width - insetX * 2,
                           height: height - insetTop - insetBottom)
        let center = CGPoint(x: field.midX, y: field.minY + field.height * 0.46)

        var stars: [StarNode] = []
        var clusters: [ConstellationCluster] = []

        let core = planets.first { $0.id == .core }
        let branches = planets.filter { $0.id != .core }

        if let core {
            stars.append(StarNode(id: "star:core", toolID: nil, title: core.title,
                                  category: .core, position: center,
                                  radius: radius(for: .core), isCore: true))
            // The core planet's other tools (e.g. OpenSwarm) orbit the core star
            // as a tight inner constellation so every tool becomes a star.
            let coreTools = core.tools.filter { $0.id != PlanetData.centralCoreToolID }
            for (ti, tool) in coreTools.enumerated() {
                let a = -CGFloat.pi / 2 + (2 * .pi) * CGFloat(ti) / CGFloat(max(coreTools.count, 1))
                let pos = CGPoint(x: center.x + cos(a) * 66, y: center.y + sin(a) * 60)
                stars.append(StarNode(id: "star:\(tool.id)", toolID: tool.id, title: tool.name,
                                      category: .core, position: pos,
                                      radius: radius(for: tool.orbit), isCore: false))
            }
        }

        let ringX = min(field.width * 0.42, 200)
        let ringY = min(field.height * 0.40, 230)
        for (index, planet) in branches.enumerated() {
            let angle = -CGFloat.pi / 2 + (2 * .pi) * CGFloat(index) / CGFloat(max(branches.count, 1))
            let clusterCenter = CGPoint(x: center.x + cos(angle) * ringX,
                                        y: center.y + sin(angle) * ringY)
            var clusterStarIDs: [String] = []
            let count = max(planet.tools.count, 1)
            let clusterRadius: CGFloat = min(54, 22 + CGFloat(count) * 4)

            for (ti, tool) in planet.tools.enumerated() where tool.id != PlanetData.centralCoreToolID {
                // Deterministic spiral around the cluster centre (golden angle).
                let t = CGFloat(ti)
                let a = t * 2.399963
                let r = clusterRadius * (((t + 0.5) / CGFloat(count)).squareRoot())
                let pos = CGPoint(x: clusterCenter.x + cos(a) * r,
                                  y: clusterCenter.y + sin(a) * r)
                let id = "star:\(tool.id)"
                stars.append(StarNode(id: id, toolID: tool.id, title: tool.name,
                                      category: planet.id, position: pos,
                                      radius: radius(for: tool.orbit), isCore: false))
                clusterStarIDs.append(id)
            }

            clusters.append(ConstellationCluster(id: planet.id, center: clusterCenter,
                                                 radius: clusterRadius, starIDs: clusterStarIDs))
        }

        resolveOverlaps(&stars, in: field)
        return ConstellationLayoutResult(stars: stars, clusters: clusters)
    }

    private static func resolveOverlaps(_ stars: inout [StarNode], in field: CGRect) {
        guard stars.count > 1 else { return }
        var pts = stars.map(\.position)
        let radii = stars.map(\.radius)
        let coreIndex = stars.firstIndex(where: { $0.isCore })
        for _ in 0..<60 {
            for i in pts.indices {
                for j in pts.indices where j > i {
                    let dx = pts[j].x - pts[i].x, dy = pts[j].y - pts[i].y
                    var dist = (dx * dx + dy * dy).squareRoot()
                    let minDist = radii[i] + radii[j] + 4
                    guard dist < minDist else { continue }
                    if dist < 0.001 { dist = 0.001 }
                    let push = (minDist - dist) / 2
                    let ux = dx / dist, uy = dy / dist
                    if coreIndex == i { pts[j].x += ux * push * 2; pts[j].y += uy * push * 2 }
                    else if coreIndex == j { pts[i].x -= ux * push * 2; pts[i].y -= uy * push * 2 }
                    else {
                        pts[i].x -= ux * push; pts[i].y -= uy * push
                        pts[j].x += ux * push; pts[j].y += uy * push
                    }
                }
            }
            for i in pts.indices where coreIndex != i {
                pts[i].x = min(max(pts[i].x, field.minX + radii[i]), field.maxX - radii[i])
                pts[i].y = min(max(pts[i].y, field.minY + radii[i]), field.maxY - radii[i])
            }
        }
        stars = zip(stars, pts).map { star, p in
            StarNode(id: star.id, toolID: star.toolID, title: star.title,
                     category: star.category, position: p, radius: star.radius, isCore: star.isCore)
        }
    }
}
