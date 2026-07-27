import Foundation
import simd
import SwiftUI
import UIKit

/// Scene-facing planet model for the premium RealityKit universe map.
///
/// `ToolCategory`/`Tool` remain the source of truth for product data; this
/// struct stores the 3D presentation contract so the renderer does not need
/// to know how seed data is arranged.
struct PlanetData: Identifiable, Sendable {
    let id: ToolCategoryId
    let title: String
    let subtitle: String
    let color: ColorHex
    let accent: ColorHex
    let position3D: SIMD3<Float>
    let radius: Float
    let toolCount: Int
    let tools: [Tool]
    let categoryType: ToolCategoryId

    /// The core tool rendered as the central planet (Founder OS). Its sibling
    /// core tools render as satellites around it instead of as the core itself.
    static let centralCoreToolID = UniverseIdentity.centralCoreToolID

    var swiftUIColor: Color { color.swiftUIColor }
    var uiColor: UIColor { color.uiColor }
    var accentUIColor: UIColor { accent.uiColor }

    static func makePlanets(categories: [ToolCategory], tools: [Tool]) -> [PlanetData] {
        let branches = categories.filter { $0.id != .core }
        return categories.compactMap { category in
            let categoryTools = tools.filter { $0.category == category.id }
            // A planet only exists once it holds at least one tool. An empty
            // universe renders no planets (blank starfield); the user grows it
            // by adding tools, and each new category lights up its planet.
            guard !categoryTools.isEmpty else { return nil }
            let isCore = category.id == .core
            let branchIndex = branches.firstIndex { $0.id == category.id } ?? 0
            return PlanetData(
                id: category.id,
                title: isCore ? "Founder OS" : category.shortName,
                subtitle: category.description,
                color: category.color,
                accent: category.glow,
                position3D: isCore ? .zero : UniverseSpatialLayout.categoryPosition(
                    for: category,
                    branchIndex: branchIndex,
                    branchCount: branches.count
                ),
                radius: isCore ? 0.94 : 0.62 + min(Float(categoryTools.count), 4) * 0.045,
                toolCount: categoryTools.count,
                tools: categoryTools,
                categoryType: category.id
            )
        }
    }

    /// A core planet for callers that need a non-optional fallback (e.g. the
    /// selected-planet projection). Safe even when the universe is empty: with
    /// no core tools `makePlanets` yields nothing, so synthesize an empty core
    /// at the origin rather than crash.
    static func core(from tools: [Tool]) -> PlanetData {
        let category = UniverseSeed.category(.core)
        if let planet = makePlanets(categories: [category], tools: tools).first {
            return planet
        }
        return PlanetData(
            id: .core,
            title: "Founder OS",
            subtitle: category.description,
            color: category.color,
            accent: category.glow,
            position3D: .zero,
            radius: 0.94,
            toolCount: 0,
            tools: [],
            categoryType: .core
        )
    }
}

struct UniverseLabelProjection: Equatable {
    let point: CGPoint
    let scale: CGFloat
    let opacity: Double
    let isVisible: Bool
}
