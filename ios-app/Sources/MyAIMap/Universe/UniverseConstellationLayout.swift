import CoreGraphics
import Foundation

/// Pure screen-space layout for the 2D constellation renderer.
///
/// The renderer owns visual taste; this type owns deterministic placement so
/// tests can guard the "readable 2D first" contract without hosting SwiftUI.
enum UniverseConstellationLayout {
    static let overviewCategoryDiameter: CGFloat = 46
    static let categoryLabelWidth: CGFloat = 88
    static let categoryLabelHeight: CGFloat = 32
    static let categoryLabelGap: CGFloat = 6
    static let toolLabelWidth: CGFloat = 84
    static let toolLabelHeight: CGFloat = 18
    static let toolLabelGap: CGFloat = 6

    struct CategoryNode: Identifiable {
        let id: String
        let categoryID: ToolCategoryId
        let point: CGPoint
        let diameter: CGFloat
        let isFocused: Bool
        let isContext: Bool
    }

    struct ToolNode: Identifiable {
        let id: String
        let toolID: String
        let categoryID: ToolCategoryId
        let point: CGPoint
        let diameter: CGFloat
        let isSelected: Bool
        let priority: Int
    }

    struct Edge: Identifiable {
        let id: String
        let from: CGPoint
        let to: CGPoint
        let categoryID: ToolCategoryId
        let isStrong: Bool
    }

    struct Layout {
        let corePoint: CGPoint?
        let categoryNodes: [CategoryNode]
        let toolNodes: [ToolNode]
        let edges: [Edge]
    }

    static func categoryVisualFrames(for node: CategoryNode) -> [CGRect] {
        let ringDiameter = node.diameter + (node.isFocused ? 18 : 10)
        let ringFrame = CGRect(
            x: node.point.x - ringDiameter / 2,
            y: node.point.y - ringDiameter / 2,
            width: ringDiameter,
            height: ringDiameter
        )
        guard !node.isContext else { return [ringFrame] }

        let width: CGFloat = node.isFocused ? 112 : categoryLabelWidth
        let height: CGFloat = node.isFocused ? 40 : categoryLabelHeight
        let labelFrame = CGRect(
            x: node.point.x - width / 2,
            y: node.point.y + ringDiameter / 2 + categoryLabelGap,
            width: width,
            height: height
        )
        return [ringFrame, labelFrame]
    }

    static func categoryVisualFrame(for node: CategoryNode) -> CGRect {
        categoryVisualFrames(for: node).reduce(.null) { $0.union($1) }
    }

    static func toolVisualFrame(for node: ToolNode) -> CGRect {
        let ringDiameter = node.diameter + (node.isSelected ? 18 : 10)
        let ringFrame = CGRect(
            x: node.point.x - ringDiameter / 2,
            y: node.point.y - ringDiameter / 2,
            width: ringDiameter,
            height: ringDiameter
        )
        let width: CGFloat = node.isSelected ? 104 : toolLabelWidth
        let height: CGFloat = node.isSelected ? 34 : toolLabelHeight
        let labelFrame = CGRect(
            x: node.point.x - width / 2,
            y: node.point.y + ringDiameter / 2 + toolLabelGap,
            width: width,
            height: height
        )
        return ringFrame.union(labelFrame)
    }

    static func make(planets: [PlanetData], mode: UniverseMode, size: CGSize) -> Layout {
        guard size.width > 1, size.height > 1, !planets.isEmpty else {
            return Layout(corePoint: nil, categoryNodes: [], toolNodes: [], edges: [])
        }

        let content = contentRect(in: size)
        let center = CGPoint(x: content.midX, y: content.minY + content.height * 0.48)
        let corePoint = planets.contains(where: { $0.id == .core }) ? center : nil

        switch displayMode(for: mode) {
        case .overview:
            return overviewLayout(planets: planets, center: center, content: content, corePoint: corePoint)
        case .branch(let category, let selectedToolID):
            return branchLayout(
                planets: planets,
                focusedCategory: category,
                selectedToolID: selectedToolID,
                center: center,
                content: content,
                corePoint: corePoint
            )
        }
    }

    static func contentRect(in size: CGSize) -> CGRect {
        let top = min(max(size.height * 0.18, 144), 188)
        let bottom = min(max(size.height * 0.25, 214), 292)
        let horizontal = min(max(size.width * 0.10, 36), 72)
        return CGRect(
            x: horizontal,
            y: top,
            width: max(1, size.width - horizontal * 2),
            height: max(1, size.height - top - bottom)
        )
    }

    private enum DisplayMode {
        case overview
        case branch(ToolCategoryId, String?)
    }

    private static func displayMode(for mode: UniverseMode) -> DisplayMode {
        switch mode {
        case .overview:
            return .overview
        case .branchFocus(let category),
             .detail(let category, _):
            return category == .core ? .overview : .branch(category, nil)
        case .toolSelected(let category, let toolID):
            return category == .core ? .branch(category, toolID) : .branch(category, toolID)
        case .chatOpen(let category, let toolID):
            guard let category else { return .overview }
            return category == .core && toolID == nil ? .overview : .branch(category, toolID)
        }
    }

    private static func overviewLayout(
        planets: [PlanetData],
        center: CGPoint,
        content: CGRect,
        corePoint: CGPoint?
    ) -> Layout {
        let branches = sortedBranches(planets)
        let radiusX = min(content.width * 0.42, 174)
        let radiusY = min(content.height * 0.38, 164)
        var nodes: [CategoryNode] = []
        var edges: [Edge] = []

        for (index, planet) in branches.enumerated() {
            let angle = overviewAngle(for: planet, index: index, count: branches.count)
            let point = CGPoint(
                x: center.x + cos(angle) * radiusX,
                y: center.y + sin(angle) * radiusY
            )
            nodes.append(
                CategoryNode(
                    id: "category.\(planet.id.rawValue)",
                    categoryID: planet.id,
                    point: point,
                    diameter: overviewCategoryDiameter,
                    isFocused: false,
                    isContext: false
                )
            )
            if let corePoint {
                edges.append(
                    Edge(
                        id: "core-\(planet.id.rawValue)",
                        from: corePoint,
                        to: point,
                        categoryID: planet.id,
                        isStrong: false
                    )
                )
            }
        }

        return Layout(corePoint: corePoint, categoryNodes: nodes, toolNodes: [], edges: edges)
    }

    private static func branchLayout(
        planets: [PlanetData],
        focusedCategory: ToolCategoryId,
        selectedToolID: String?,
        center: CGPoint,
        content: CGRect,
        corePoint: CGPoint?
    ) -> Layout {
        guard let focused = planets.first(where: { $0.id == focusedCategory }) else {
            return overviewLayout(planets: planets, center: center, content: content, corePoint: corePoint)
        }

        let categoryNode = CategoryNode(
            id: "category.\(focused.id.rawValue)",
            categoryID: focused.id,
            point: center,
            diameter: focused.id == .core ? 60 : 56,
            isFocused: true,
            isContext: false
        )

        let tools = focused.tools.filter { !(focused.id == .core && $0.id == PlanetData.centralCoreToolID) }
        var toolNodes: [ToolNode] = []
        var edges: [Edge] = []

        let hasDenseToolSet = tools.count > 8
        let leftCount = (tools.count + 1) / 2
        let rightCount = tools.count / 2
        let columnTop = content.minY + 90
        let columnBottom = content.maxY - (hasDenseToolSet ? 54 : 104)
        let leftX = content.minX + 38
        let rightX = content.maxX - 38

        for (index, tool) in tools.enumerated() {
            let isSelected = tool.id == selectedToolID
            let isLeft = index.isMultiple(of: 2)
            let row = index / 2
            let rowCount = isLeft ? leftCount : rightCount
            let point = columnPoint(
                x: isLeft ? leftX : rightX,
                row: row,
                count: rowCount,
                top: columnTop,
                bottom: columnBottom
            )
            toolNodes.append(
                ToolNode(
                    id: "tool.\(tool.id)",
                    toolID: tool.id,
                    categoryID: focused.id,
                    point: point,
                    diameter: isSelected ? 42 : 34,
                    isSelected: isSelected,
                    priority: index
                )
            )
            edges.append(
                Edge(
                    id: "\(focused.id.rawValue)-\(tool.id)",
                    from: center,
                    to: point,
                    categoryID: focused.id,
                    isStrong: isSelected
                )
            )
        }

        let contextNodes = hasDenseToolSet ? [] : contextCategoryNodes(
            planets: planets,
            focusedCategory: focused.id,
            center: center,
            content: content
        )
        return Layout(
            corePoint: focused.id == .core ? nil : corePoint,
            categoryNodes: [categoryNode] + contextNodes,
            toolNodes: toolNodes,
            edges: edges
        )
    }

    private static func contextCategoryNodes(
        planets: [PlanetData],
        focusedCategory: ToolCategoryId,
        center: CGPoint,
        content: CGRect
    ) -> [CategoryNode] {
        let branches = sortedBranches(planets).filter { $0.id != focusedCategory }
        guard !branches.isEmpty else { return [] }
        let radiusX = min(content.width * 0.46, 188)
        let y = content.maxY - 16

        return branches.enumerated().map { index, planet in
            let progress = branches.count == 1 ? 0.5 : CGFloat(index) / CGFloat(branches.count - 1)
            let x = center.x - radiusX + radiusX * 2 * progress
            return CategoryNode(
                id: "context.\(planet.id.rawValue)",
                categoryID: planet.id,
                point: CGPoint(x: x, y: y),
                diameter: 22,
                isFocused: false,
                isContext: true
            )
        }
    }

    private static func sortedBranches(_ planets: [PlanetData]) -> [PlanetData] {
        planets
            .filter { $0.id != .core }
            .sorted { lhs, rhs in
                let left = atan2(CGFloat(lhs.position3D.z), CGFloat(lhs.position3D.x))
                let right = atan2(CGFloat(rhs.position3D.z), CGFloat(rhs.position3D.x))
                if left != right { return left < right }
                return lhs.id.rawValue < rhs.id.rawValue
            }
    }

    private static func overviewAngle(for planet: PlanetData, index: Int, count: Int) -> CGFloat {
        guard planet.id.isBuiltin else {
            let step = CGFloat.pi * 2 / CGFloat(max(count, 1))
            return -CGFloat.pi * 0.82 + CGFloat(index) * step
        }
        return atan2(CGFloat(planet.position3D.z), CGFloat(planet.position3D.x))
    }

    private static func columnPoint(
        x: CGFloat,
        row: Int,
        count: Int,
        top: CGFloat,
        bottom: CGFloat
    ) -> CGPoint {
        guard count > 1 else { return CGPoint(x: x, y: (top + bottom) / 2) }
        let progress = CGFloat(row) / CGFloat(count - 1)
        return CGPoint(x: x, y: top + (bottom - top) * progress)
    }
}
