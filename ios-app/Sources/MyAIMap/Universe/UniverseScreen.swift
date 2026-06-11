import SwiftUI

struct UniverseScreen: View {
    @Environment(UniverseViewModel.self) private var model
    @State private var sheetPresented = false

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
                onToolSelect: { toolId in
                    focusToolFromMap(toolId)
                },
                onProximityEvent: { event in
                    // Web parity (Scene.tsx:420-421): onEnter selects the
                    // category, onExit returns to the overview ('all' ↔ .core).
                    switch event {
                    case .enter(let id):
                        selectCategory(id)
                    case .exit:
                        selectCategory(.core)
                    }
                }
            )
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                SearchDock()
                    .padding(.top, 10)
                Spacer(minLength: 0)
                categoryRail
                bottomSheet
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
        .onAppear {
            sheetPresented = true
            BrandHaptics.prepare(.light, .medium, .heavy, .success)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                .frame(width: 42, height: 42)
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous),
                    tint: selectedCategoryModel.color.swiftUIColor,
                    strokeStrength: 0.16
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("My AI Map")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Research -> Plan -> Build -> Review")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Text("\(UniverseSeed.tools.count) tools")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .liquidGlass(in: Capsule(), tint: selectedCategoryModel.color.swiftUIColor.opacity(0.5), strokeStrength: 0.08)
        }
        .brandAnimation(BrandMotion.flow, value: model.selection.activeCategory)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(UniverseSeed.categories) { category in
                    Button {
                        selectCategory(category.id)
                    } label: {
                        let isSelected = category.id == model.selection.activeCategory
                        HStack(spacing: 7) {
                            Circle()
                                .fill(category.color.swiftUIColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: category.color.swiftUIColor.opacity(isSelected ? 0.9 : 0.25), radius: isSelected ? 7 : 2)
                            Text(category.shortName)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.66))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .scaleEffect(isSelected ? 1.035 : 1)
                        .liquidGlass(in: Capsule(), tint: isSelected ? category.color.swiftUIColor : nil, strokeStrength: isSelected ? 0.16 : 0.06)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? category.color.swiftUIColor.opacity(0.64) : .white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.93, haptic: nil, pressedOpacity: 0.92))
                    .brandAnimation(BrandMotion.nudge, value: model.selection.activeCategory)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var bottomSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(.white.opacity(0.28))
                .frame(width: 44, height: 4)
                .frame(maxWidth: .infinity)

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
                    .scaleEffect(sheetPresented ? 1 : 0.9)
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
        }
        .padding(16)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 26, style: .continuous),
            tint: selectedCategoryModel.color.swiftUIColor,
            strokeStrength: 0.12
        )
        .shadow(color: .black.opacity(0.42), radius: 28, x: 0, y: 18)
        .offset(y: sheetPresented ? 0 : 28)
        .opacity(sheetPresented ? 1 : 0)
        .brandAnimation(BrandMotion.entry, value: sheetPresented)
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

    private func selectCategory(_ id: ToolCategoryId) {
        let previous = model.selection.activeCategory
        if previous == id {
            BrandHaptics.fire(.light)
            return
        }

        if id == .core {
            BrandHaptics.fireRich(.pocketClose)
        } else if previous == .core {
            BrandHaptics.fireRich(.pocketOpen)
        } else {
            BrandHaptics.fire(.medium)
        }

        withAnimation(BrandMotion.flow) {
            model.selectCategory(id)
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

    private func focusToolFromMap(_ id: String) {
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

#Preview {
    UniverseScreen()
        .environment(UniverseViewModel())
}
