import SwiftUI

/// Selected-tool detail card: category eyebrow, tool name, summary,
/// stage capsule badge, and the horizontal rail of visible tools.
/// Extracted verbatim from `UniverseScreen`'s inline bottom sheet
/// (Phase 2 step 7); the container chrome (glass card, grabber, entry
/// animation) now belongs to the presenting sheet.
struct ToolDetailSection: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.openURL) private var openURL

    private var selectedCategoryModel: ToolCategory {
        model.selectedCategoryModel
    }

    private var visibleTools: [Tool] {
        model.visibleTools
    }

    private var selectedTool: Tool {
        model.selectedTool
    }

    /// Resolves `selectedTool.relationIds` to existing seed tools, skipping
    /// any id that doesn't resolve (defensive — the seed is clean, but stale
    /// references must never crash or render an empty chip).
    private var relatedTools: [Tool] {
        selectedTool.relationIds.compactMap { id in
            UniverseSeed.tools.first { $0.id == id }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedCategoryModel.name.uppercased())
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                        Text(selectedTool.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.opacity)
                        Text(selectedTool.summary)
                            .font(.subheadline)
                            .lineSpacing(3)
                            .foregroundStyle(.white.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                    }
                    .id(selectedTool.id)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 8)

                Text(stageLabel(selectedTool.stage))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(selectedCategoryModel.color.swiftUIColor, in: Capsule())
            }

            Divider()
                .overlay(.white.opacity(0.14))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(visibleTools) { tool in
                        Button {
                            selectTool(tool.id)
                        } label: {
                            let isSelected = tool.id == model.selection.selectedToolID
                            VStack(alignment: .leading, spacing: 5) {
                                Text(tool.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(stageLabel(tool.stage))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            .frame(width: 132, alignment: .leading)
                            .padding(10)
                            .background(
                                isSelected
                                    ? selectedCategoryModel.color.swiftUIColor.opacity(0.20)
                                    : Color.white.opacity(0.055),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? selectedCategoryModel.color.swiftUIColor.opacity(0.52) : .white.opacity(0.08), lineWidth: 1)
                            )
                            .scaleEffect(isSelected ? 1.02 : 1)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                    }
                }
            }

            if !relatedTools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONNECTED TO")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(BrandColor.textMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(relatedTools) { related in
                                Button {
                                    focusRelated(related.id)
                                } label: {
                                    HStack(spacing: 7) {
                                        Circle()
                                            .fill(UniverseSeed.category(related.category).color.swiftUIColor)
                                            .frame(width: 7, height: 7)
                                        Text(related.name)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .liquidGlass(in: Capsule())
                                }
                                .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                            }
                        }
                    }
                }
            }

            if let url = selectedTool.url {
                Button {
                    BrandHaptics.fire(.light)
                    openURL(url)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption.weight(.semibold))
                        Text("Open")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .liquidGlass(in: Capsule(), tint: selectedCategoryModel.color.swiftUIColor)
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
            }
        }
        .brandAnimation(BrandMotion.flow, value: model.selection.activeCategory)
        .brandAnimation(BrandMotion.nudge, value: model.selection.selectedToolID)
    }

    private func stageLabel(_ stage: WorkflowStageId) -> String {
        switch stage {
        case .research:
            return "Research"
        case .planning:
            return "Plan"
        case .execution:
            return "Build"
        case .approval:
            return "Approve"
        case .review:
            return "Review"
        }
    }

    private func selectTool(_ id: String) {
        guard model.selection.selectedToolID != id else {
            BrandHaptics.fire(.light)
            return
        }
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.nudge) {
            model.selectTool(id)
        }
    }

    /// Re-selects a related tool: jumps to its category, selects it, and
    /// snaps clarity to focus via `focusTool`.
    private func focusRelated(_ id: String) {
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.flow) {
            _ = model.focusTool(id)
        }
    }
}

#Preview {
    ToolDetailSection()
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.black)
        .environment(UniverseViewModel())
        .preferredColorScheme(.dark)
}
