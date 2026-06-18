import SwiftUI

/// Selected-tool detail card: category eyebrow, tool name, summary,
/// stage capsule badge, and the horizontal rail of visible tools.
/// Extracted verbatim from `UniverseScreen`'s inline bottom sheet
/// (Phase 2 step 7); the container chrome (glass card, grabber, entry
/// animation) now belongs to the presenting sheet.
struct ToolDetailSection: View {
    @Environment(UniverseViewModel.self) private var model
    @State private var isShowingRemoveConfirmation = false

    private var selectedCategoryModel: ToolCategory {
        model.selectedCategoryModel
    }

    private var visibleTools: [Tool] {
        model.visibleTools
    }

    private var selectedTool: Tool {
        model.selectedTool
    }

    private var knowledge: ToolKnowledge {
        ToolKnowledgeBook.knowledge(for: selectedTool)
    }

    private var relatedTools: [Tool] {
        selectedTool.relationIds.compactMap { relationID in
            model.visibleAllTools.first { $0.id == relationID }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.xl.value) {
            headerBlock
            primaryInsightGrid
            featureStack
            metadataSection
            branchRail

            if !relatedTools.isEmpty {
                connectedSourcesSection
            }

            actionRow
        }
        .brandAnimation(BrandMotion.flow, value: model.selection.activeCategory)
        .brandAnimation(BrandMotion.nudge, value: model.selection.selectedToolID)
        .confirmationDialog(
            "Remove \(selectedTool.name)?",
            isPresented: $isShowingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Tool", role: .destructive) {
                removeSelectedTool()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the tool from your map. The action cannot be undone from this sheet.")
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.l.value) {
            HStack(alignment: .top, spacing: BrandSpacing.m.value) {
                ToolLogoView(
                    tool: selectedTool,
                    accent: selectedCategoryModel.color.swiftUIColor
                )

                VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                    Text(selectedCategoryModel.name.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                    Text(selectedTool.name)
                        .font(BrandTypography.display)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                stageBadge(selectedTool.stage)
            }
            .id(selectedTool.id)
            .transition(.move(edge: .bottom).combined(with: .opacity))

            Text(selectedTool.summary)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            HStack(spacing: BrandSpacing.s.value) {
                heroMetric(icon: "circle.grid.3x3", title: "Orbit", value: orbitLabel(selectedTool.orbit))
                heroMetric(icon: "point.3.connected.trianglepath.dotted", title: "Links", value: "\(relatedTools.count)")
            }
        }
    }

    private var primaryInsightGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: BrandSpacing.s.value),
                GridItem(.flexible(), spacing: BrandSpacing.s.value),
            ],
            alignment: .leading,
            spacing: BrandSpacing.s.value
        ) {
            insightCard(title: "Best for", icon: "target", text: knowledge.useCase, tint: selectedCategoryModel.color.swiftUIColor)
            insightCard(title: "Pricing", icon: "creditcard", text: knowledge.pricing, tint: BrandColor.lime)
        }
    }

    private var featureStack: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            chipSection(title: "Killer features", icon: "sparkles", items: knowledge.killerFeatures, tint: selectedCategoryModel.color.swiftUIColor)
            chipSection(title: "Strengths", icon: "checkmark.seal", items: knowledge.strengths, tint: BrandColor.teal)
            textPanel(title: "Tradeoffs", icon: "exclamationmark.triangle", rows: knowledge.tradeoffs, tint: BrandColor.amber)
            textPanel(title: "Common users", icon: "person.2", rows: [knowledge.typicalUsers], tint: BrandColor.pink)
        }
    }

    private var metadataSection: some View {
        infoBlock(title: "Metadata", icon: "info.circle", tint: BrandColor.cyan) {
            VStack(spacing: 0) {
                metadataRow("Category", selectedCategoryModel.name, icon: "folder")
                metadataDivider
                metadataRow("Workflow stage", stageLabel(selectedTool.stage), icon: "arrow.triangle.branch")
                metadataDivider
                metadataRow("Map position", "\(orbitLabel(selectedTool.orbit)) orbit - \(Int(selectedTool.angle)) degrees", icon: "location.north.circle")
                if let domain = selectedTool.logoDomain {
                    metadataDivider
                    metadataRow("Source domain", domain, icon: "globe")
                }
                if let reason = selectedTool.classification?.reason {
                    metadataDivider
                    metadataRow("Why it belongs", reason, icon: "text.bubble")
                }
            }
        }
    }

    private var branchRail: some View {
        infoBlock(title: "Explore this branch", icon: "rectangle.3.group", tint: selectedCategoryModel.color.swiftUIColor) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: BrandSpacing.s.value) {
                    ForEach(visibleTools) { tool in
                        Button {
                            selectTool(tool.id)
                        } label: {
                            let isSelected = tool.id == model.selection.selectedToolID
                            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                                Text(tool.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(stageLabel(tool.stage))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(isSelected ? selectedCategoryModel.color.swiftUIColor : BrandColor.textMuted)
                            }
                            .frame(width: 136, alignment: .leading)
                            .padding(BrandSpacing.m.value)
                            .liquidGlass(
                                in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous),
                                tint: isSelected ? selectedCategoryModel.color.swiftUIColor : nil,
                                strokeStrength: isSelected ? 0.16 : 0.06
                            )
                            .scaleEffect(isSelected ? 1.02 : 1)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                        .id(tool.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollBounceBehavior(.basedOnSize)
            .scrollClipDisabled()
            .contentMargins(.horizontal, 2, for: .scrollContent)
        }
    }

    private var connectedSourcesSection: some View {
        infoBlock(title: "Connected sources", icon: "link", tint: BrandColor.violet) {
            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                Text("Related tools and sources connected to this selection.")
                    .font(.caption)
                    .foregroundStyle(BrandColor.textMuted)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: BrandSpacing.s.value) {
                        ForEach(relatedTools) { tool in
                            connectedSourceButton(tool)
                                .id(tool.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollBounceBehavior(.basedOnSize)
                .scrollClipDisabled()
                .contentMargins(.horizontal, 2, for: .scrollContent)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: BrandSpacing.s.value) {
            if let url = selectedTool.url {
                Link(destination: url) {
                    actionLabel("Open", systemImage: "safari", foreground: .black.opacity(0.84))
                        .liquidGlass(
                            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
                            tint: selectedCategoryModel.color.swiftUIColor,
                            strokeStrength: 0.18
                        )
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: .light, pressedOpacity: 0.92))
            }

            if selectedTool.category != .core {
                Button(role: .destructive) {
                    BrandHaptics.fire(.medium)
                    isShowingRemoveConfirmation = true
                } label: {
                    actionLabel("Remove", systemImage: "trash", foreground: .red.opacity(0.94))
                        .liquidGlass(
                            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
                            tint: .red,
                            strokeStrength: 0.12
                        )
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: selectedTool.url == nil ? .trailing : .leading)
    }

    private func connectedSourceButton(_ tool: Tool) -> some View {
        Button {
            focus(tool.id)
        } label: {
            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                Label(tool.name, systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(stageLabel(tool.stage))
                    .font(.caption2)
                    .foregroundStyle(BrandColor.textMuted)
                    .lineLimit(1)
            }
            .frame(width: 164, alignment: .leading)
            .padding(.horizontal, BrandSpacing.m.value)
            .padding(.vertical, BrandSpacing.s.value)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous),
                tint: selectedCategoryModel.color.swiftUIColor,
                strokeStrength: 0.08
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil))
    }

    private func infoBlock<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
            Label(title.uppercased(), systemImage: icon)
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(tint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrandSpacing.m.value)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
            tint: tint,
            strokeStrength: 0.08
        )
    }

    private func insightCard(title: String, icon: String, text: String, tint: Color) -> some View {
        infoBlock(title: title, icon: icon, tint: tint) {
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .lineSpacing(3)
                .foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chipSection(title: String, icon: String, items: [String], tint: Color) -> some View {
        infoBlock(title: title, icon: icon, tint: tint) {
            chipGrid(items, tint: tint, symbol: icon == "sparkles" ? "sparkle" : "checkmark")
        }
    }

    private func textPanel(title: String, icon: String, rows: [String], tint: Color) -> some View {
        infoBlock(title: title, icon: icon, tint: tint) {
            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                ForEach(rows, id: \.self) { row in
                    Label(row, systemImage: icon == "exclamationmark.triangle" ? "minus.circle" : "person.crop.circle")
                        .font(.caption)
                        .lineSpacing(3)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func chipGrid(_ items: [String], tint: Color, symbol: String) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 126), spacing: BrandSpacing.s.value)],
            alignment: .leading,
            spacing: BrandSpacing.s.value
        ) {
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, BrandSpacing.s.value)
                    .padding(.vertical, BrandSpacing.s.value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: BrandRadius.node.value, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: BrandRadius.node.value, style: .continuous)
                            .stroke(tint.opacity(0.18), lineWidth: 1)
                    }
            }
        }
    }

    private var metadataDivider: some View {
        Divider()
            .overlay(.white.opacity(0.08))
    }

    private func metadataRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: BrandSpacing.s.value) {
            metadataLabel(title, icon: icon)
                .frame(width: 116, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
                .lineSpacing(3)
                .foregroundStyle(BrandColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, BrandSpacing.s.value)
    }

    private func metadataLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.bold))
            .foregroundStyle(BrandColor.textMuted)
    }

    private func stageBadge(_ stage: WorkflowStageId) -> some View {
        Text(stageLabel(stage))
            .font(.caption.weight(.bold))
            .foregroundStyle(.black.opacity(0.82))
            .padding(.horizontal, BrandSpacing.m.value)
            .padding(.vertical, BrandSpacing.s.value)
            .background(selectedCategoryModel.color.swiftUIColor, in: Capsule())
    }

    private func heroMetric(icon: String, title: String, value: String) -> some View {
        HStack(spacing: BrandSpacing.s.value) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                .frame(width: 22, height: 22)
                .background(selectedCategoryModel.color.swiftUIColor.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: BrandSpacing.hair.value) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BrandColor.textMuted)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, BrandSpacing.m.value)
        .padding(.vertical, BrandSpacing.s.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous),
            tint: selectedCategoryModel.color.swiftUIColor,
            strokeStrength: 0.06
        )
    }

    private func actionLabel(_ title: String, systemImage: String, foreground: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .contentShape(RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous))
    }

    private func orbitLabel(_ orbit: OrbitRing) -> String {
        switch orbit {
        case .core:
            return "Core"
        case .inner:
            return "Inner"
        case .middle:
            return "Middle"
        case .outer:
            return "Outer"
        }
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

    private func focus(_ id: String) {
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.flow) {
            _ = model.focusTool(id)
        }
    }

    private func removeSelectedTool() {
        withAnimation(BrandMotion.flow) {
            _ = model.deleteTool(selectedTool.id)
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
