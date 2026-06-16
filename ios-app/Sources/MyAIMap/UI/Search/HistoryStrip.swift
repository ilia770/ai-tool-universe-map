import SwiftUI

/// Pure presentation model for one history chip. Resolves the tool name from
/// the seed (falling back to the raw id) and exposes the accessibility label /
/// deleted flag the view renders. Kept out of the View so it is unit-testable.
struct HistoryChipModel: Identifiable {
    let event: ToolHistory.Event

    var id: String { event.id.uuidString }
    var isDeleted: Bool { event.kind == .deleted }

    var title: String {
        UniverseSeed.tools.first { $0.id == event.toolID }?.name ?? event.toolID
    }

    var accessibilityLabel: String {
        isDeleted ? "Removed \(title), tap to reopen" : "Recently added \(title), tap to open"
    }
}

/// Horizontal row of liquid-glass history chips, shown above the SearchDock.
/// Web parity: FindBar.tsx renders the "Recently added" chips only when
/// `history.length > 0` and routes a tap to `openTool(id)`; here that is
/// `model.focusTool`. Tap = open, long-press = context menu (Open + Restore/
/// Remove). The whole strip collapses when history is empty.
struct HistoryStrip: View {
    @Environment(UniverseViewModel.self) private var model

    private var chips: [HistoryChipModel] {
        model.recentHistory.map(HistoryChipModel.init)
    }

    var body: some View {
        if !chips.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recently added")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips) { chip in
                            chipButton(chip)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .brandAnimation(BrandMotion.flow, value: chips.map(\.id))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func chipButton(_ chip: HistoryChipModel) -> some View {
        Button {
            openTool(chip.event.toolID)
        } label: {
            HStack(spacing: 6) {
                if chip.isDeleted {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(chip.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(chip.isDeleted ? 0.62 : 0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlass(in: Capsule(), strokeStrength: 0.1)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(chip.accessibilityLabel)
        .contextMenu {
            Button {
                openTool(chip.event.toolID)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            if chip.isDeleted {
                Button {
                    model.recordAdded(chip.event.toolID)
                    openTool(chip.event.toolID)
                } label: {
                    Label("Restore", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(role: .destructive) {
                    model.recordDeleted(chip.event.toolID)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    /// Mirrors UniverseScreen.focusToolFromMap: medium haptic on a real jump,
    /// light tick when the tool is already selected; animates with BrandMotion.
    private func openTool(_ id: String) {
        guard model.selection.selectedToolID != id else {
            BrandHaptics.fire(.light)
            return
        }
        BrandHaptics.fire(.medium)
        withAnimation(BrandMotion.flow) {
            _ = model.focusTool(id)
        }
    }
}
