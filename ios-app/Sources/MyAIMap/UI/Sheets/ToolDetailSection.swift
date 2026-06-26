import SwiftUI
import UIKit

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
            return [unknownRow(note: "No pricing stored.")]
        }

        if lower.contains("internal") {
            return [
                ToolPricingRow(plan: "Internal", value: "Variable", note: clean, icon: "building.2"),
                unknownRow(note: "Depends on model, agent, and storage usage."),
            ]
        }

        if lower.contains("open-source") || lower.contains("open source") {
            var rows = [
                ToolPricingRow(plan: "Free", value: "$0 core", note: "Open-source core.", icon: "checkmark.circle"),
            ]
            if lower.contains("paid") || lower.contains("cloud") {
                rows.append(ToolPricingRow(plan: "Paid/cloud", value: "Hosted options", note: "Verify limits and runtime cost.", icon: "creditcard"))
            }
            rows.append(unknownRow(note: "Hosted pricing not stored."))
            return rows
        }

        if lower.contains("freemium") {
            var rows = [
                ToolPricingRow(plan: "Free", value: "$0 tier", note: "Free tier or trial; verify limits.", icon: "checkmark.circle"),
                ToolPricingRow(plan: "Paid tier", value: "Verify website", note: "Plan and price not stored.", icon: "creditcard"),
            ]
            if lower.contains("team") {
                rows.append(ToolPricingRow(plan: "Team", value: "Team subscription", note: "Team plan available.", icon: "person.3"))
            }
            if lower.contains("enterprise") {
                rows.append(ToolPricingRow(plan: "Enterprise", value: "Paid/custom", note: "Enterprise available; verify terms.", icon: "building.2"))
            }
            return rows
        }

        if lower.contains("subscription") || lower.contains("usage") || lower.contains("api") {
            var rows = [
                ToolPricingRow(plan: "Subscription / usage", value: "Verify website", note: clean, icon: "creditcard"),
            ]
            if lower.contains("team") {
                rows.append(ToolPricingRow(plan: "Team", value: "Team plan", note: "Team plan available.", icon: "person.3"))
            }
            rows.append(unknownRow(note: "Price not stored."))
            return rows
        }

        if lower.contains("depends") || lower.contains("variable") {
            return [
                ToolPricingRow(plan: "Variable", value: "Depends on setup", note: clean, icon: "slider.horizontal.3"),
                unknownRow(note: "Verify before budgeting."),
            ]
        }

        return [
            ToolPricingRow(plan: "Pricing note", value: "Verify website", note: clean, icon: "info.circle"),
            unknownRow(note: "Plan prices not stored."),
        ]
    }

    private static func unknownRow(note: String) -> ToolPricingRow {
        ToolPricingRow(plan: "Unknown", value: "Verify website", note: note, icon: "questionmark.circle")
    }
}

enum ToolWebsiteSearchURL {
    static func url(for toolName: String) -> URL? {
        let trimmed = toolName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "duckduckgo.com"
        components.path = "/"

        let queryValueAllowed = CharacterSet.urlQueryAllowed
            .subtracting(CharacterSet(charactersIn: "&=+?"))
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: queryValueAllowed) else {
            return nil
        }
        components.percentEncodedQuery = "q=\(encoded)"
        return components.url
    }
}

enum ToolDetailClipboardFormatting {
    static func pricingStatus(for pricing: String) -> String {
        let rows = ToolPricingPresenter.rows(for: pricing)
        if rows.count == 1, rows.first?.plan == "Unknown" {
            return "Unknown - verify website"
        }
        return pricing
    }
}

/// Selected-tool detail card. Reads the selected tool from the single
/// navigation machine and presents it as a premium product profile, not an
/// admin dashboard.
struct ToolDetailSection: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onOpenRelatedTool: ((String) -> Void)?
    @State private var isShowingRemoveConfirmation = false
    @State private var browserSheet: BrowserSheetItem?
    @State private var isMetadataExpanded = false
    @State private var isStrengthsExpanded = false
    @State private var isMoreExpanded = false
    /// Drives the copy-confirmation toast when the user copies tool info.
    @State private var copyToastKind: CopyToastKind?
    /// Pricing-row icon glyph + its circular container, scaled with Dynamic Type.
    @ScaledMetric(relativeTo: .body) private var pricingIconGlyph: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var pricingIconContainer: CGFloat = 28

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
            bestForSection
            bulletSection(title: "Key features", icon: "sparkles", items: knowledge.killerFeatures, symbol: "sparkle")
            pricingSection
            strengthsTradeoffsSection
            moreSection
            metadataSection
            secondaryActions
        }
        // Text scales with Dynamic Type; clamp the largest accessibility sizes
        // so the dense pricing/metadata rows stay readable without clipping.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .brandAnimation(BrandMotion.flow, value: model.selection.activeCategory)
        .brandAnimation(BrandMotion.nudge, value: model.selection.selectedToolID)
        .accessibilityIdentifier("ToolDetailSection.Root")
        .copyToast($copyToastKind)
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
            Text("Removes this tool from your map.")
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
                            .foregroundStyle(.white.opacity(0.88), selectedCategoryModel.color.swiftUIColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.075), in: Capsule())

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
                .font(BrandTypography.bodySecondary)
                .lineSpacing(4)
                .foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            HStack(spacing: BrandSpacing.s.value) {
                primaryAction
                copyInfoAction
            }
        }
        .padding(BrandSpacing.m.value)
        .background(neutralCardBackground)
    }

    private var copyInfoAction: some View {
        Button {
            UIPasteboard.general.string = ToolInfoClipboard.text(
                name: selectedTool.name,
                category: selectedCategoryModel.shortName,
                summary: selectedTool.summary,
                pricingStatus: clipboardPricingStatus,
                keyFeatures: knowledge.killerFeatures,
                url: selectedTool.url?.absoluteString
            )
            BrandHaptics.fire(.success)
            copyToastKind = .toolInfo
        } label: {
            Label("Copy tool info", systemImage: "doc.on.doc")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
        .accessibilityIdentifier("ToolDetailSection.CopyInfo")
    }

    @ViewBuilder
    private var primaryAction: some View {
        if let url = selectedTool.url, let item = BrowserSheetItem(url: url) {
            Button {
                browserSheet = item
            } label: {
                actionLabel("Open website", systemImage: "safari", foreground: .white.opacity(0.92))
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: .light, pressedOpacity: 0.92))
        } else {
            // No stored URL yet — offer a working "Search website" CTA (web search
            // for the tool) instead of a dead label. A permanent URL is set via the
            // Add Tool flow.
            Button {
                if let url = ToolWebsiteSearchURL.url(for: selectedTool.name),
                   let item = BrowserSheetItem(url: url) {
                    browserSheet = item
                }
            } label: {
                actionLabel("Search website", systemImage: "magnifyingglass", foreground: .white.opacity(0.92))
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: .light, pressedOpacity: 0.92))
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
                .font(.system(size: pricingIconGlyph, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: pricingIconContainer, height: pricingIconContainer)
                .background(.white.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.plan)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: BrandSpacing.s.value)
                    Text(row.value)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
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

    /// Merged Strengths + Tradeoffs, collapsed behind a disclosure so the first
    /// screen stays focused on the value (best for, key features, pricing).
    private var strengthsTradeoffsSection: some View {
        disclosureBlock(title: "Strengths & tradeoffs", icon: "scalemass", isExpanded: $isStrengthsExpanded) {
            VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
                bulletList(knowledge.strengths, symbol: "checkmark.circle")
                bulletList(knowledge.tradeoffs, symbol: "minus.circle")
            }
        }
    }

    /// Secondary context — common users and related tools — tucked behind one
    /// disclosure to keep the stack short.
    private var moreSection: some View {
        disclosureBlock(title: "More", icon: "ellipsis.circle", isExpanded: $isMoreExpanded) {
            VStack(alignment: .leading, spacing: BrandSpacing.l.value) {
                commonUsersContent
                relatedToolsContent
            }
        }
    }

    private var commonUsersContent: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
            sectionHeader(title: "Common users", icon: "person.2")
            bulletList([knowledge.typicalUsers], symbol: "person.crop.circle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var relatedToolsContent: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
            sectionHeader(title: "Related tools", icon: "link")
            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                if explicitRelatedTools.isEmpty {
                    Text("Nearby tools from the same branch.")
                        .font(.caption)
                        .foregroundStyle(BrandColor.textMuted)
                }

                if relatedDisplayTools.isEmpty {
                    Text("No related tools yet.")
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
            sectionHeader(title: "Details", icon: "info.circle")
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

    /// Collapsible card matching `metadataSection` — used for secondary info so
    /// the first screen isn't a tall stack of always-expanded sections.
    private func disclosureBlock<Content: View>(
        title: String,
        icon: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, BrandSpacing.s.value)
        } label: {
            sectionHeader(title: title, icon: icon)
        }
        .tint(selectedCategoryModel.color.swiftUIColor)
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
        ZStack {
            RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
                .fill(.white.opacity(0.035))
            RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
                .stroke(.white.opacity(0.075), lineWidth: 0.8)
        }
    }

    private var clipboardPricingStatus: String {
        ToolDetailClipboardFormatting.pricingStatus(for: knowledge.pricing)
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
        CategorySymbol.name(for: category)
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
        withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
            if let onOpenRelatedTool {
                onOpenRelatedTool(tool.id)
            } else {
                model.universeMode = .detail(tool.category, tool.id)
            }
        }
    }

    private func removeSelectedTool() {
        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
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
