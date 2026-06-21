import SwiftUI

struct ToolPricingRow: Identifiable, Equatable, Sendable {
    let id: String
    let plan: String
    let value: String
    let note: String
    let icon: String

    init(plan: String, value: String, note: String, icon: String) {
        self.id = "\(plan)-\(value)-\(note)"
        self.plan = plan
        self.value = value
        self.note = note
        self.icon = icon
    }
}

enum ToolPricingPresenter {
    static func rows(for pricing: String) -> [ToolPricingRow] {
        let clean = pricing.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard !clean.isEmpty, !lower.contains("unknown") else {
            return [unknownRow(note: "No verified pricing is stored for this tool.")]
        }

        if lower.contains("internal") {
            return [
                ToolPricingRow(plan: "Internal", value: "Variable", note: clean, icon: "building.2"),
                unknownRow(note: "Cost depends on connected model, agent, and storage usage."),
            ]
        }

        if lower.contains("open-source") || lower.contains("open source") {
            var rows = [
                ToolPricingRow(plan: "Free", value: "$0 core", note: "Open-source core is noted locally.", icon: "checkmark.circle"),
            ]
            if lower.contains("paid") || lower.contains("cloud") {
                rows.append(ToolPricingRow(plan: "Paid/cloud", value: "Hosted options", note: "Verify current limits and render/runtime costs.", icon: "creditcard"))
            }
            rows.append(unknownRow(note: "Exact hosted pricing is not verified locally."))
            return rows
        }

        if lower.contains("freemium") {
            var rows = [
                ToolPricingRow(plan: "Free", value: "$0 tier", note: "Free tier or trial is noted locally; verify current limits.", icon: "checkmark.circle"),
                ToolPricingRow(plan: "Paid tier", value: "Verify website", note: "Exact paid plan name and price are not stored locally.", icon: "creditcard"),
            ]
            if lower.contains("team") {
                rows.append(ToolPricingRow(plan: "Team", value: "Team subscription", note: "Team pricing exists in the local note; verify website.", icon: "person.3"))
            }
            if lower.contains("enterprise") {
                rows.append(ToolPricingRow(plan: "Enterprise", value: "Paid/custom", note: "Enterprise availability is noted locally; verify terms.", icon: "building.2"))
            }
            return rows
        }

        if lower.contains("subscription") || lower.contains("usage") || lower.contains("api") {
            var rows = [
                ToolPricingRow(plan: "Subscription / usage", value: "Verify website", note: clean, icon: "creditcard"),
            ]
            if lower.contains("team") {
                rows.append(ToolPricingRow(plan: "Team", value: "Team plan", note: "Team plan is referenced locally; verify current price.", icon: "person.3"))
            }
            rows.append(unknownRow(note: "Exact price is not stored locally."))
            return rows
        }

        if lower.contains("depends") || lower.contains("variable") {
            return [
                ToolPricingRow(plan: "Variable", value: "Depends on setup", note: clean, icon: "slider.horizontal.3"),
                unknownRow(note: "Verify website or implementation before budgeting."),
            ]
        }

        return [
            ToolPricingRow(plan: "Pricing note", value: "Verify website", note: clean, icon: "info.circle"),
            unknownRow(note: "Exact plan prices are not stored locally."),
        ]
    }

    private static func unknownRow(note: String) -> ToolPricingRow {
        ToolPricingRow(plan: "Unknown", value: "Verify website", note: note, icon: "questionmark.circle")
    }
}

/// Selected-tool detail card. Reads the selected tool from the single
/// navigation machine and presents it as a premium product profile, not an
/// admin dashboard.
struct ToolDetailSection: View {
    @Environment(UniverseViewModel.self) private var model
    let onOpenRelatedTool: ((String) -> Void)?
    @State private var isShowingRemoveConfirmation = false
    @State private var browserSheet: BrowserSheetItem?
    @State private var isMetadataExpanded = false

    init(onOpenRelatedTool: ((String) -> Void)? = nil) {
        self.onOpenRelatedTool = onOpenRelatedTool
    }

    private var selectedCategoryModel: ToolCategory {
        model.selectedCategoryModel
    }

    private var selectedTool: Tool {
        model.selectedTool ?? UniverseSeed.tools[0]
    }

    private var knowledge: ToolKnowledge {
        ToolKnowledgeBook.knowledge(for: selectedTool)
    }

    private var explicitRelatedTools: [Tool] {
        selectedTool.relationIds.compactMap { relationID in
            model.visibleAllTools.first { $0.id == relationID }
        }
    }

    private var relatedDisplayTools: [Tool] {
        if !explicitRelatedTools.isEmpty {
            return explicitRelatedTools
        }
        return Array(
            model.visibleTools
                .filter { $0.id != selectedTool.id }
                .prefix(4)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.l.value) {
            headerBlock
            pricingSection
            bestForSection
            bulletSection(title: "Key features", icon: "sparkles", items: knowledge.killerFeatures, symbol: "sparkle")
            bulletSection(title: "Strengths", icon: "checkmark.seal", items: knowledge.strengths, symbol: "checkmark.circle")
            bulletSection(title: "Tradeoffs", icon: "exclamationmark.triangle", items: knowledge.tradeoffs, symbol: "minus.circle")
            commonUsersSection
            relatedToolsSection
            metadataSection
            secondaryActions
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
        .sheet(item: $browserSheet) { item in
            InAppBrowserSheet(url: item.url)
                .ignoresSafeArea()
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
            HStack(alignment: .top, spacing: BrandSpacing.m.value) {
                ToolLogoView(
                    tool: selectedTool,
                    accent: selectedCategoryModel.color.swiftUIColor,
                    size: 64
                )

                VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                    HStack(spacing: BrandSpacing.s.value) {
                        Label(selectedCategoryModel.shortName, systemImage: categoryIcon(selectedTool.category))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(selectedCategoryModel.color.swiftUIColor.opacity(0.12), in: Capsule())

                        stageBadge(selectedTool.stage)
                    }

                    Text(selectedTool.name)
                        .font(BrandTypography.display)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .contentTransition(.opacity)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(selectedTool.id)
            .transition(.move(edge: .bottom).combined(with: .opacity))

            Text(selectedTool.summary)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .lineSpacing(4)
                .foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            primaryAction
        }
        .padding(BrandSpacing.m.value)
        .background(neutralCardBackground)
    }

    @ViewBuilder
    private var primaryAction: some View {
        if let url = selectedTool.url, let item = BrowserSheetItem(url: url) {
            Button {
                browserSheet = item
            } label: {
                actionLabel("Open website", systemImage: "safari", foreground: .black.opacity(0.84))
                    .background(selectedCategoryModel.color.swiftUIColor, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: .light, pressedOpacity: 0.92))
        } else {
            Label("Website not added", systemImage: "lock.doc")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BrandColor.textMuted)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        }
    }

    private var pricingSection: some View {
        sectionBlock(title: "Pricing", icon: "creditcard") {
            VStack(spacing: BrandSpacing.s.value) {
                ForEach(ToolPricingPresenter.rows(for: knowledge.pricing)) { row in
                    pricingRow(row)
                }
            }
        }
    }

    private func pricingRow(_ row: ToolPricingRow) -> some View {
        HStack(alignment: .top, spacing: BrandSpacing.m.value) {
            Image(systemName: row.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                .frame(width: 28, height: 28)
                .background(selectedCategoryModel.color.swiftUIColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.plan)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: BrandSpacing.s.value)
                    Text(row.value)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selectedCategoryModel.color.swiftUIColor)
                        .multilineTextAlignment(.trailing)
                }

                Text(row.note)
                    .font(.caption)
                    .lineSpacing(3)
                    .foregroundStyle(BrandColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(BrandSpacing.s.value)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
    }

    private var bestForSection: some View {
        sectionBlock(title: "Best for", icon: "target") {
            Text(knowledge.useCase)
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletSection(title: String, icon: String, items: [String], symbol: String) -> some View {
        sectionBlock(title: title, icon: icon) {
            bulletList(items, symbol: symbol)
        }
    }

    private var commonUsersSection: some View {
        sectionBlock(title: "Common users", icon: "person.2") {
            bulletList([knowledge.typicalUsers], symbol: "person.crop.circle")
        }
    }

    private func bulletList(_ items: [String], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            ForEach(items, id: \.self) { item in
                Label(item, systemImage: symbol)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(BrandColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var relatedToolsSection: some View {
        sectionBlock(title: "Related tools", icon: "link") {
            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                if explicitRelatedTools.isEmpty {
                    Text("No explicit relations are verified yet. Showing nearby tools from the same branch.")
                        .font(.caption)
                        .foregroundStyle(BrandColor.textMuted)
                }

                if relatedDisplayTools.isEmpty {
                    Text("No related tools available in this universe yet.")
                        .font(.subheadline)
                        .foregroundStyle(BrandColor.textSecondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: BrandSpacing.s.value) {
                            ForEach(relatedDisplayTools) { tool in
                                relatedToolButton(tool)
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
    }

    private func relatedToolButton(_ tool: Tool) -> some View {
        let category = UniverseSeed.category(tool.category)
        return Button {
            openToolInDetail(tool.id)
        } label: {
            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                HStack(spacing: BrandSpacing.xs.value) {
                    Circle()
                        .fill(category.color.swiftUIColor)
                        .frame(width: 7, height: 7)
                    Text(tool.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(category.shortName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(BrandColor.textMuted)
                    .lineLimit(1)
            }
            .frame(width: 156, alignment: .leading)
            .padding(.horizontal, BrandSpacing.m.value)
            .padding(.vertical, BrandSpacing.s.value)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil))
    }

    private var metadataSection: some View {
        DisclosureGroup(isExpanded: $isMetadataExpanded) {
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
            .padding(.top, BrandSpacing.s.value)
        } label: {
            sectionHeader(title: "Metadata / technical details", icon: "info.circle")
        }
        .tint(selectedCategoryModel.color.swiftUIColor)
        .padding(BrandSpacing.m.value)
        .background(neutralCardBackground)
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if selectedTool.category != .core {
            Button(role: .destructive) {
                BrandHaptics.fire(.medium)
                isShowingRemoveConfirmation = true
            } label: {
                Label("Remove from map", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
        }
    }

    private func sectionBlock<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
            sectionHeader(title: title, icon: icon)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrandSpacing.m.value)
        .background(neutralCardBackground)
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white.opacity(0.92), selectedCategoryModel.color.swiftUIColor)
            .labelStyle(.titleAndIcon)
            .symbolRenderingMode(.hierarchical)
    }

    private var neutralCardBackground: some View {
        RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
            .fill(.white.opacity(0.045))
    }

    private var metadataDivider: some View {
        Divider()
            .overlay(.white.opacity(0.08))
    }

    private func metadataRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: BrandSpacing.s.value) {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.bold))
                .foregroundStyle(BrandColor.textMuted)
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

    private func stageBadge(_ stage: WorkflowStageId) -> some View {
        Text(stageLabel(stage))
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.08), in: Capsule())
    }

    private func actionLabel(_ title: String, systemImage: String, foreground: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .contentShape(RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
    }

    private func categoryIcon(_ category: ToolCategoryId) -> String {
        switch category {
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintpalette"
        case .research: return "doc.text.magnifyingglass"
        case .analytics: return "chart.xyaxis.line"
        case .media: return "sparkles.tv"
        case .distribution: return "paperplane"
        case .infrastructure: return "server.rack"
        case .knowledge: return "books.vertical"
        case .core: return "sparkles"
        }
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

    private func openToolInDetail(_ id: String) {
        guard let tool = model.visibleAllTools.first(where: { $0.id == id }) else { return }
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.nudge) {
            if let onOpenRelatedTool {
                onOpenRelatedTool(tool.id)
            } else {
                model.universeMode = .detail(tool.category, tool.id)
            }
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
