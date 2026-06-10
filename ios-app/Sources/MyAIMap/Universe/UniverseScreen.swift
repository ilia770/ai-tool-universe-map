import SwiftUI

struct UniverseScreen: View {
    @Environment(UniverseViewModel.self) private var model

    private var selectedCategoryModel: ToolCategory {
        model.selectedCategoryModel
    }

    private var visibleTools: [Tool] {
        model.visibleTools
    }

    private var selectedTool: Tool {
        model.selectedTool
    }

    var body: some View {
        ZStack {
            UniverseView(
                selectedCategory: model.selection.activeCategory,
                selectedToolId: selectedTool.id,
                onProximityEvent: { event in
                    // Web parity (Scene.tsx:420-421): onEnter selects the
                    // category, onExit returns to the overview ('all' ↔ .core).
                    switch event {
                    case .enter(let id):
                        model.selectCategory(id)
                    case .exit:
                        model.selectCategory(.core)
                    }
                }
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                categoryRail
                bottomSheet
            }
            .padding(.horizontal, BrandSpacing.l.value)
            .padding(.top, BrandSpacing.m.value)
            .padding(.bottom, BrandSpacing.s.value)
        }
        .background(BrandColor.void)
        .preferredColorScheme(.dark)
        .onAppear {
            BrandHaptics.prepare(.light)
        }
    }

    private var header: some View {
        HStack(spacing: BrandSpacing.m.value) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                .frame(width: 42, height: 42)
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous),
                    tint: selectedCategoryModel.color.swiftUIColor,
                    strokeStrength: 0.14
                )
                .brandAnimation(BrandMotion.flow, value: model.selection.activeCategory)

            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                Text("My AI Map")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BrandColor.textPrimary)
                Text("Research → Plan → Build → Review")
                    .font(.caption)
                    .foregroundStyle(BrandColor.textSecondary)
            }

            Spacer()

            Text("\(UniverseSeed.tools.count) tools")
                .font(.caption.weight(.semibold))
                .foregroundStyle(BrandColor.textSecondary)
                .padding(.horizontal, BrandSpacing.m.value)
                .padding(.vertical, BrandSpacing.s.value)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(BrandColor.stroke, lineWidth: 1)
                )
        }
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BrandSpacing.s.value) {
                ForEach(UniverseSeed.categories) { category in
                    categoryChip(category)
                }
            }
            .padding(.vertical, BrandSpacing.s.value)
        }
        .brandAnimation(BrandMotion.nudge, value: model.selection.activeCategory)
    }

    private func categoryChip(_ category: ToolCategory) -> some View {
        let isSelected = category.id == model.selection.activeCategory
        let accent = category.color.swiftUIColor

        return Button {
            model.selectCategory(category.id)
        } label: {
            HStack(spacing: BrandSpacing.s.value) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(category.shortName)
                    .font(BrandTypography.chip)
            }
            .foregroundStyle(isSelected ? BrandColor.textPrimary : BrandColor.textSecondary)
            .padding(.horizontal, BrandSpacing.m.value)
            .padding(.vertical, BrandSpacing.s.value)
            .background {
                ZStack {
                    Capsule().fill(.ultraThinMaterial)
                    if isSelected {
                        Capsule().fill(accent.opacity(0.14))
                    }
                }
            }
            .overlay(
                Capsule()
                    .stroke(isSelected ? accent.opacity(0.5) : BrandColor.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var bottomSheet: some View {
        let accent = selectedCategoryModel.color.swiftUIColor

        return VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
            Capsule()
                .fill(BrandColor.white.opacity(0.28))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: BrandSpacing.m.value) {
                VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                    Text(selectedCategoryModel.name)
                        .brandEyebrow()
                        .foregroundStyle(accent)
                    Text(selectedTool.name)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(BrandColor.textPrimary)
                    Text(selectedTool.summary)
                        .font(.subheadline)
                        .lineSpacing(3)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: BrandSpacing.s.value)

                Text(stageLabel(selectedTool.stage))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, BrandSpacing.m.value)
                    .padding(.vertical, BrandSpacing.xs.value)
                    .background(accent.opacity(0.16), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(accent.opacity(0.32), lineWidth: 1)
                    )
            }

            Divider()
                .overlay(BrandColor.stroke)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrandSpacing.s.value) {
                    ForEach(visibleTools) { tool in
                        toolCard(tool)
                    }
                }
            }
            .brandAnimation(BrandMotion.nudge, value: model.selection.selectedToolID)
        }
        .padding(BrandSpacing.l.value)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.sheet.value, style: .continuous),
            strokeStrength: 0.12
        )
        .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 18)
    }

    private func toolCard(_ tool: Tool) -> some View {
        let isSelected = tool.id == model.selection.selectedToolID
        let accent = selectedCategoryModel.color.swiftUIColor

        return Button {
            model.selectTool(tool.id)
        } label: {
            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                Text(tool.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BrandColor.textPrimary)
                    .lineLimit(1)
                Text(stageLabel(tool.stage))
                    .font(.caption2)
                    .foregroundStyle(BrandColor.textMuted)
            }
            .frame(width: 132, alignment: .leading)
            .padding(BrandSpacing.m.value)
            .background(
                isSelected ? accent.opacity(0.20) : BrandColor.card,
                in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous)
                    .stroke(isSelected ? accent.opacity(0.5) : BrandColor.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
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
}

#Preview {
    UniverseScreen()
        .environment(UniverseViewModel())
}
