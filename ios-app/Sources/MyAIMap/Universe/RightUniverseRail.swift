import SwiftUI

/// Edge-only branch navigator for the universe.
///
/// Inactive state is only tiny dots at the screen edge. Holding the invisible
/// edge zone reveals a floating native-style picker.
struct UniverseRailView: View {
    let categories: [ToolCategory]
    let activeCategory: ToolCategoryId
    let tint: Color
    let onActiveChange: (Bool) -> Void
    let onSelect: (ToolCategoryId) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gestureState = UniverseRailGestureState()

    private let hitWidth: CGFloat = 32
    private let inactiveVisibleWidth: CGFloat = 8
    private let inactiveHeight: CGFloat = 204
    private let inactiveDotsHeight: CGFloat = 188
    private let activeListWidth: CGFloat = 184
    private let activeHeight: CGFloat = 322
    private let rowSpacing: CGFloat = 31

    private var currentCategory: ToolCategoryId {
        gestureState.hoveredCategory ?? activeCategory
    }

    private var activeIndex: Int {
        categories.firstIndex { $0.id == currentCategory } ?? 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                if gestureState.isActive {
                    activeList
                        .frame(width: activeListWidth, height: activeHeight, alignment: .leading)
                        .padding(.trailing, 2)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                } else {
                    inactiveDots
                        .frame(width: inactiveVisibleWidth, height: inactiveDotsHeight)
                        .padding(.trailing, 1)
                        .transition(.opacity)
                }

                railHitZone(height: proxy.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .frame(
            width: gestureState.isActive ? activeListWidth : hitWidth,
            height: gestureState.isActive ? activeHeight : inactiveHeight
        )
        .brandAnimation(
            BrandMotion.resolved(.spring(response: 0.34, dampingFraction: 0.84), reduceMotion: reduceMotion),
            value: gestureState.isActive
        )
        // Hidden from VoiceOver: the hold-then-drag gesture can't be performed
        // assistively. CategoryRail provides the accessible category control.
        .accessibilityHidden(true)
    }

    private func railHitZone(height: CGFloat) -> some View {
        Color.clear
            .frame(width: hitWidth, height: height)
            .contentShape(Rectangle())
            .gesture(railGesture(height: height))
    }

    private var inactiveDots: some View {
        VStack(spacing: 9) {
            ForEach(categories) { category in
                Circle()
                    .fill(category.id == activeCategory ? tint : .white.opacity(0.24))
                    .frame(
                        width: category.id == activeCategory ? 4.6 : 3.2,
                        height: category.id == activeCategory ? 4.6 : 3.2
                    )
                    .shadow(
                        color: category.id == activeCategory ? tint.opacity(0.52) : .clear,
                        radius: category.id == activeCategory ? 4 : 0
                    )
            }
        }
    }

    private var activeList: some View {
        GeometryReader { proxy in
            let listHeight = proxy.size.height
            ZStack(alignment: .leading) {
                ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                    let distance = abs(index - activeIndex)
                    UniverseRailItemView(
                        title: title(for: category.id),
                        color: category.color.swiftUIColor,
                        isSelected: category.id == currentCategory,
                        distance: distance
                    )
                    .frame(width: activeListWidth, alignment: .leading)
                    .position(
                        x: activeListWidth * 0.5,
                        y: listHeight * 0.5 + CGFloat(index - activeIndex) * rowSpacing
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
    }

    private func railGesture(height: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.26, maximumDistance: 18)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    beginHold()
                case .second(true, let dragValue):
                    beginHold()
                    if let dragValue {
                        updateHover(at: dragValue.location.y, height: height)
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                guard gestureState.isActive else {
                    collapseRail()
                    return
                }

                if case .second(true, let dragValue) = value, let dragValue {
                    updateHover(at: dragValue.location.y, height: height)
                }

                let selected = currentCategory
                collapseRail()
                onSelect(selected)
            }
    }

    private func beginHold() {
        guard !gestureState.isActive else { return }
        gestureState.begin(activeCategory: activeCategory, activeIndex: activeIndex)
        BrandHaptics.fire(.light)
        onActiveChange(true)
        withAnimation(BrandMotion.nudge) {
            gestureState.phase = .active
        }
    }

    private func collapseRail() {
        let wasActive = gestureState.isActive
        withAnimation(BrandMotion.nudge) {
            gestureState.reset()
        }
        if wasActive {
            onActiveChange(false)
        }
    }

    private func updateHover(at yPosition: CGFloat, height: CGFloat) {
        guard !categories.isEmpty else { return }
        let top = max(0, height * 0.5 - activeHeight * 0.5)
        let relativeY = min(max(yPosition - top, 0), activeHeight)
        let centeredY = relativeY - activeHeight * 0.5
        let nextIndex = min(
            max(Int((centeredY / rowSpacing).rounded()) + gestureState.holdStartIndex, 0),
            categories.count - 1
        )
        let nextCategory = categories[nextIndex].id
        if gestureState.updateHover(nextCategory) {
            BrandHaptics.fire(.light)
        }
    }

    private func title(for id: ToolCategoryId) -> String {
        guard let category = categories.first(where: { $0.id == id }) else {
            return id.rawValue.capitalized
        }
        switch category.id {
        case .core:
            return "Founder"
        case .infrastructure:
            return "Runtime"
        default:
            return category.shortName
        }
    }
}

typealias RightUniverseRail = UniverseRailView

struct UniverseRailGestureState {
    enum Phase {
        case inactive
        case active
    }

    var phase: Phase = .inactive
    var hoveredCategory: ToolCategoryId?
    var holdStartIndex = 0

    var isActive: Bool {
        phase == .active
    }

    mutating func begin(activeCategory: ToolCategoryId, activeIndex: Int) {
        hoveredCategory = activeCategory
        holdStartIndex = activeIndex
    }

    mutating func updateHover(_ category: ToolCategoryId) -> Bool {
        guard category != hoveredCategory else { return false }
        hoveredCategory = category
        return true
    }

    mutating func reset() {
        phase = .inactive
        hoveredCategory = nil
        holdStartIndex = 0
    }
}

private struct UniverseRailItemView: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let distance: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isSelected ? color : .clear)
                .frame(width: isSelected ? 7 : 4, height: isSelected ? 7 : 4)
                .shadow(color: isSelected ? color.opacity(0.74) : .clear, radius: 6)

            Text(title)
                .font(.system(size: fontSize, weight: isSelected ? .black : .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(opacity))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .textCase(isSelected ? .uppercase : nil)

            Spacer(minLength: 0)
        }
        .frame(height: rowHeight, alignment: .leading)
        .scaleEffect(isSelected ? 1.04 : 1, anchor: .leading)
    }

    private var rowHeight: CGFloat {
        switch distance {
        case 0: return 36
        case 1: return 30
        default: return 25
        }
    }

    private var fontSize: CGFloat {
        switch distance {
        case 0: return 20
        case 1: return 14.5
        default: return 10.8
        }
    }

    private var opacity: Double {
        switch distance {
        case 0: return 0.98
        case 1: return 0.74
        case 2: return 0.48
        default: return 0.28
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack {
            Spacer()
            UniverseRailView(
                categories: UniverseSeed.categories.filter { $0.id == .core }
                    + UniverseSeed.categories.filter { $0.id != .core },
                activeCategory: .media,
                tint: UniverseSeed.category(.media).color.swiftUIColor,
                onActiveChange: { _ in },
                onSelect: { _ in }
            )
        }
    }
}
