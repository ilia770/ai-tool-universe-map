import SwiftUI
import simd

/// Native universe scene for the iOS TestFlight track.
///
/// This version intentionally uses plain SwiftUI primitives (`Circle`,
/// `Path`, `Text`) instead of Canvas/RealityKit so the first TestFlight
/// build is visually reliable on Simulator and device. The projection
/// still uses the same 3D layout vectors as the web map.
struct UniverseView: View {
    let selectedCategory: ToolCategoryId
    let selectedToolId: String
    let onToolSelect: @MainActor (String) -> Void
    let onProximityEvent: @MainActor (ProximityWatcherCore.Event) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ambientPulse = false
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var orbitYaw: CGFloat = 0
    @State private var baseOrbitYaw: CGFloat = 0
    @State private var orbitPitch: CGFloat = 0
    @State private var baseOrbitPitch: CGFloat = 0

    private var selectedCategoryModel: ToolCategory {
        UniverseSeed.category(selectedCategory)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    RadialGradient(
                        colors: [
                            selectedCategoryModel.color.swiftUIColor.opacity(0.24),
                            Color(red: 0.015, green: 0.025, blue: 0.06),
                            .black
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 680
                    )
                    .ignoresSafeArea()

                    starfield(in: size)
                    connections(in: size)
                    nodes(in: size)
                    categoryHitTargets(in: size)
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            guard !reduceMotion else { return }
            ambientPulse = true
        }
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    zoom = min(max(baseZoom * value.magnification, 0.72), 1.72)
                }
                .onEnded { _ in
                    baseZoom = zoom
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    orbitYaw = baseOrbitYaw + value.translation.width * 0.006
                    let nextPitch = Float(baseOrbitPitch + value.translation.height * 0.004)
                    orbitPitch = CGFloat(CameraController.clampedOrbitPitch(nextPitch))
                }
                .onEnded { _ in
                    baseOrbitYaw = orbitYaw
                    baseOrbitPitch = orbitPitch
                }
        )
        .onTapGesture(count: 2) {
            resetCameraPose()
        }
        .brandAnimation(BrandMotion.flow, value: selectedCategory)
        .brandAnimation(BrandMotion.flow, value: selectedToolId)
    }

    private func starfield(in size: CGSize) -> some View {
        ZStack {
            ForEach(0..<110, id: \.self) { index in
                let point = starPosition(index, in: size)
                let radius: CGFloat = index.isMultiple(of: 13) ? 2.1 : 1.15
                Circle()
                    .fill(.white.opacity(index.isMultiple(of: 7) ? 0.70 : 0.38))
                    .frame(width: radius, height: radius)
                    .position(point)
            }
        }
    }

    private func connections(in size: CGSize) -> some View {
        ZStack {
            let corePoint = project(.zero, in: size)
            ForEach(UniverseSeed.categories.filter { $0.id != .core }) { category in
                let center = UniverseLayout.categoryPosition(angleDegrees: category.angle)
                let categoryPoint = project(center, in: size)
                connectionLine(from: corePoint, to: categoryPoint, color: category.color.swiftUIColor, opacity: 0.30)

                let tools = UniverseSeed.tools(in: category.id)
                ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                    let isPocket = category.id == selectedCategory
                    let position = toolPosition(tool, category: category, index: index, count: tools.count, pocketed: isPocket)
                    connectionLine(
                        from: categoryPoint,
                        to: project(position, in: size),
                        color: category.color.swiftUIColor,
                        opacity: isPocket ? 0.36 : 0.13
                    )
                }
            }
        }
    }

    private func nodes(in size: CGSize) -> some View {
        ZStack {
            ForEach(UniverseSeed.categories.filter { $0.id != .core }) { category in
                let center = UniverseLayout.categoryPosition(angleDegrees: category.angle)
                let categoryPoint = project(center, in: size)
                let categorySelected = category.id == selectedCategory

                let tools = UniverseSeed.tools(in: category.id)
                ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                    let isPocket = category.id == selectedCategory
                    let position = toolPosition(tool, category: category, index: index, count: tools.count, pocketed: isPocket)
                    let selected = tool.id == selectedToolId
                    node(
                        color: category.color.swiftUIColor,
                        radius: selected ? 15 : isPocket ? 10 : 7,
                        selected: selected,
                        pulse: selected && ambientPulse
                    )
                    .position(project(position, in: size))
                }

                node(
                    color: category.color.swiftUIColor,
                    radius: categorySelected ? 24 : 16,
                    selected: categorySelected,
                    pulse: categorySelected && ambientPulse
                )
                .position(categoryPoint)

                let labelPoint = categoryLabelPoint(categoryPoint, category: category.id, selected: categorySelected)
                Text(category.shortName)
                    .font(categorySelected ? .caption.weight(.bold) : .caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(categorySelected ? 0.96 : 0.72))
                    .position(labelPoint)
            }

            let corePoint = project(.zero, in: size)
            node(
                color: UniverseSeed.category(.core).color.swiftUIColor,
                radius: selectedCategory == .core ? 30 : 23,
                selected: selectedCategory == .core,
                pulse: selectedCategory == .core && ambientPulse
            )
            .position(corePoint)

            Text("Founder OS")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.96))
                .position(x: corePoint.x, y: corePoint.y + 42)
        }
    }

    private func categoryHitTargets(in size: CGSize) -> some View {
        ZStack {
            ForEach(UniverseSeed.categories.filter { $0.id != .core }) { category in
                let point = project(UniverseLayout.categoryPosition(angleDegrees: category.angle), in: size)
                Button {
                    onProximityEvent(.enter(category.id))
                } label: {
                    Circle()
                        .fill(.white.opacity(0.001))
                        .frame(width: category.id == selectedCategory ? 90 : 66, height: category.id == selectedCategory ? 90 : 66)
                }
                .accessibilityLabel("Open \(category.name)")
                .buttonStyle(.plain)
                .position(point)
            }

            ForEach(UniverseSeed.categories.filter { $0.id != .core }) { category in
                let tools = UniverseSeed.tools(in: category.id)
                ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                    let isPocket = category.id == selectedCategory
                    let position = toolPosition(tool, category: category, index: index, count: tools.count, pocketed: isPocket)
                    let point = project(position, in: size)
                    Button {
                        onToolSelect(tool.id)
                    } label: {
                        Circle()
                            .fill(.white.opacity(0.001))
                            .frame(width: isPocket ? 52 : 38, height: isPocket ? 52 : 38)
                    }
                    .accessibilityLabel("Select \(tool.name)")
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.82, haptic: nil, pressedOpacity: 1))
                    .position(point)
                }
            }
        }
    }

    private func connectionLine(from start: CGPoint, to end: CGPoint, color: Color, opacity: Double) -> some View {
        Path { path in
            path.move(to: start)
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 16)
            path.addQuadCurve(to: end, control: mid)
        }
        .stroke(color.opacity(opacity), style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round))
    }

    private func node(color: Color, radius: CGFloat, selected: Bool, pulse: Bool) -> some View {
        ZStack {
            if selected {
                Circle()
                    .stroke(color.opacity(pulse ? 0.10 : 0.28), lineWidth: 1.2)
                    .frame(width: radius * (pulse ? 6.8 : 4.8), height: radius * (pulse ? 6.8 : 4.8))
                    .blur(radius: radius * 0.16)
            }
            Circle()
                .fill(color.opacity(selected ? 0.30 : 0.14))
                .frame(width: radius * (pulse ? 5.2 : 4.5), height: radius * (pulse ? 5.2 : 4.5))
                .blur(radius: radius * 0.7)
            Circle()
                .fill(color.opacity(selected ? 0.96 : 0.78))
                .frame(width: radius * 2, height: radius * 2)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(selected ? 0.78 : 0.32), lineWidth: selected ? 1.4 : 0.8)
                )
        }
        .compositingGroup()
        .brandAnimation(BrandMotion.breath, value: pulse)
    }

    private func toolPosition(_ tool: Tool, category: ToolCategory, index: Int, count: Int, pocketed: Bool) -> SIMD3<Float> {
        if pocketed {
            return UniverseLayout.pocketToolPosition(
                angleDegrees: tool.angle,
                orbit: tool.orbit,
                categoryAngleDegrees: category.angle,
                slotIndex: index,
                slotCount: max(count, 1)
            )
        }
        return UniverseLayout.toolPosition(
            angleDegrees: tool.angle,
            orbit: tool.orbit,
            categoryAngleDegrees: category.angle
        )
    }

    private func project(_ position: SIMD3<Float>, in size: CGSize) -> CGPoint {
        let adjusted = CameraController.orbitAdjusted(
            position,
            yaw: Float(orbitYaw),
            pitch: Float(orbitPitch)
        )
        let minSide = max(min(size.width, size.height), 1)
        let scale = minSide / 14.4 * zoom
        let depth = 1 / (1 + CGFloat(adjusted.z) * 0.035)
        let x = size.width / 2 + CGFloat(adjusted.x) * scale * depth
        let y = size.height * 0.42 + CGFloat(adjusted.z) * scale * 0.22 - CGFloat(adjusted.y) * scale * 0.74
        return CGPoint(x: x, y: y)
    }

    private func resetCameraPose() {
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.resolved(BrandMotion.flow, reduceMotion: reduceMotion)) {
            zoom = 1
            baseZoom = 1
            orbitYaw = 0
            baseOrbitYaw = 0
            orbitPitch = 0
            baseOrbitPitch = 0
        }
    }

    private func starPosition(_ index: Int, in size: CGSize) -> CGPoint {
        let seed = Double(index)
        let x = abs((sin(seed * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1))
        let y = abs((sin(seed * 78.233) * 24634.6345).truncatingRemainder(dividingBy: 1))
        return CGPoint(x: x * size.width, y: y * size.height)
    }

    private func categoryLabelPoint(_ point: CGPoint, category: ToolCategoryId, selected: Bool) -> CGPoint {
        let selectedBoost: CGFloat = selected ? 8 : 0
        let offset: CGSize = switch category {
        case .coding:
            CGSize(width: -54 - selectedBoost, height: -32)
        case .design:
            CGSize(width: 58 + selectedBoost, height: -30 - selectedBoost)
        case .research:
            CGSize(width: 40 + selectedBoost, height: 38 + selectedBoost)
        case .media:
            CGSize(width: 48 + selectedBoost, height: -8)
        case .distribution:
            CGSize(width: 62 + selectedBoost, height: 32 + selectedBoost)
        case .infrastructure:
            CGSize(width: -50 - selectedBoost, height: 48 + selectedBoost)
        case .knowledge:
            CGSize(width: -24 - selectedBoost, height: 18)
        case .core:
            CGSize(width: 0, height: 42)
        }
        return CGPoint(x: point.x + offset.width, y: point.y + offset.height)
    }
}

#Preview {
    UniverseView(
        selectedCategory: .design,
        selectedToolId: "figma",
        onToolSelect: { _ in },
        onProximityEvent: { _ in }
    )
}
