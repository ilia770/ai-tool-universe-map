import SwiftUI

/// Selected-tool detail card: category eyebrow, tool name, summary,
/// stage capsule badge, and the horizontal rail of visible tools.
/// Extracted verbatim from `UniverseScreen`'s inline bottom sheet
/// (Phase 2 step 7); the container chrome (glass card, grabber, entry
/// animation) now belongs to the presenting sheet.
struct ToolDetailSection: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var browserSheet: BrowserSheetItem?
    /// Tool id armed for deletion; drives the confirmation dialog.
    @State private var pendingDeleteID: String?
    /// Tool ids whose "Connected because …" caption is currently revealed.
    @State private var revealedReasons: Set<String> = []
    /// One-shot flag driving the killer-features stagger; reset on tool change.
    @State private var appeared = false

    /// Rich web-researched knowledge for the selected tool, or `nil` when the
    /// tool is un-enriched (only "What it does" shows in that case).
    private var knowledge: Knowledge? {
        KnowledgeStore.knowledge(for: selectedTool.id)
    }

    /// Which knowledge sections render (P5 gating, parity with ToolDetail.tsx).
    private var gating: ToolDetailModel.Gating {
        ToolDetailModel.gating(for: knowledge)
    }

    private var selectedCategoryModel: ToolCategory {
        model.selectedCategoryModel
    }

    private var visibleTools: [Tool] {
        model.visibleTools
    }

    private var selectedTool: Tool {
        model.selectedTool
    }

    /// Inferred relationship edges for the selected tool, keyed by target id
    /// (P9). Memoised in the view model, so this is a cache read, not a
    /// per-render recompute.
    private var inferredEdgeByToId: [String: InferredEdge] {
        Dictionary(model.inferredEdges(for: selectedTool.id).map { ($0.toId, $0) },
                   uniquingKeysWith: { first, _ in first })
    }

    /// Resolves the selected tool's connections — curated `relationIds` plus
    /// any inferred-edge targets — to existing seed tools, skipping ids that
    /// don't resolve (defensive — stale references must never crash or render
    /// an empty chip).
    private var relatedTools: [Tool] {
        var seen = Set<String>()
        let ids = selectedTool.relationIds + inferredEdgeByToId.keys.sorted()
        return ids.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return UniverseSeed.tools.first { $0.id == id }
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

            // ── Knowledge sections (parity with web ToolDetail.tsx) ──
            DetailSection(title: "What it does") {
                ClampText(text: (knowledge?.whatFor).flatMap { $0.isEmpty ? nil : $0 } ?? selectedTool.summary)
            }

            if gating.showsKillerFeatures, let features = knowledge?.killerFeatures {
                DetailSection(title: "Killer features") {
                    KillerFeaturesList(
                        features: features,
                        accent: selectedCategoryModel.color.swiftUIColor,
                        appeared: appeared
                    )
                }
            }

            if gating.showsStrengthsWatchouts, let k = knowledge {
                StrengthsWatchouts(advantages: k.advantages, weaknesses: k.weaknesses)
            }

            if gating.showsWhoUses, let whoUses = knowledge?.whoUses {
                DetailSection(title: "Who uses it") {
                    Text(whoUses)
                        .font(BrandTypography.body)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if gating.showsPricing, let pricing = knowledge?.pricing {
                DetailSection(title: "Pricing") { PricingCard(pricing: pricing) }
            }

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
                        .contextMenu {
                            if Self.canDelete(toolID: tool.id) {
                                Button(role: .destructive) {
                                    requestDelete(tool.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            if !relatedTools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONNECTED TO · \(relatedTools.count)")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(BrandColor.textMuted)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(relatedTools) { related in
                                let edge = inferredEdgeByToId[related.id]
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
                                        // Inferred edges get a "why" affordance.
                                        if edge != nil {
                                            Image(systemName: revealedReasons.contains(related.id) ? "xmark.circle.fill" : "questionmark.circle")
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .liquidGlass(in: Capsule())
                                }
                                .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                                // Long-press reveals "Connected because …" without
                                // stealing the tap (which still focuses the tool).
                                .simultaneousGesture(
                                    edge == nil ? nil :
                                    LongPressGesture(minimumDuration: InteractionTokens.longPressSeconds).onEnded { _ in
                                        toggleReason(related.id)
                                    }
                                )
                            }
                        }
                    }

                    // "Connected because …" captions for any revealed inferred
                    // edge. Rendered under the rail so the horizontal scroll
                    // geometry never reflows when a caption opens.
                    ForEach(relatedTools) { related in
                        if let edge = inferredEdgeByToId[related.id], revealedReasons.contains(related.id) {
                            Text("Connected because — \(RelationshipReason.connectedBecause(edge))")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                if let openURL = ToolDetailModel.derivedURL(for: selectedTool) {
                    Button {
                        BrandHaptics.fire(.light)
                        browserSheet = BrowserSheetItem(url: openURL)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption.weight(.semibold))
                            Text("Open \(selectedTool.name)")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlass(in: Capsule(), tint: selectedCategoryModel.color.swiftUIColor)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                }

                if Self.canDelete(toolID: selectedTool.id) {
                    Button {
                        requestDelete(selectedTool.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.caption.weight(.semibold))
                            Text("Delete")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlass(in: Capsule(), tint: .red, strokeStrength: 0.12)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.9))
                    .accessibilityLabel("Delete \(selectedTool.name)")
                }
            }
        }
        .sheet(item: $browserSheet) { item in
            InAppBrowserSheet(url: item.url)
                .ignoresSafeArea()
        }
        .confirmationDialog(
            "Delete \(toolName(pendingDeleteID ?? ""))?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = pendingDeleteID { performDelete(id) }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("This removes it from your universe. You can add it back later.")
        }
        .brandAnimation(BrandMotion.flow, value: model.selection.activeCategory)
        .brandAnimation(BrandMotion.nudge, value: model.selection.selectedToolID)
        .onAppear {
            BrandHaptics.prepare(.light)
            withAnimation(reduceMotion ? nil : BrandMotion.entry) { appeared = true }
        }
        .onChange(of: model.selection.selectedToolID) { _, _ in
            appeared = false
            withAnimation(reduceMotion ? nil : BrandMotion.entry) { appeared = true }
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

    /// Toggles the "Connected because …" caption for an inferred-edge chip.
    /// BrandHaptics on toggle; the reveal honours Reduce Motion.
    private func toggleReason(_ id: String) {
        BrandHaptics.fire(.light)
        if reduceMotion {
            if !revealedReasons.insert(id).inserted { revealedReasons.remove(id) }
        } else {
            withAnimation(BrandMotion.nudge) {
                if !revealedReasons.insert(id).inserted { revealedReasons.remove(id) }
            }
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

    /// The founder core is the universe's hero and is never deletable; every
    /// other tool is. Pure so the flow test can assert it directly.
    static func canDelete(toolID: String) -> Bool { toolID != "founder-os" }

    /// Arms the confirmation dialog for `id` with a `.warning` haptic.
    private func requestDelete(_ id: String) {
        guard Self.canDelete(toolID: id) else { return }
        BrandHaptics.fire(.warning)
        pendingDeleteID = id
    }

    /// Confirmed delete: `.heavy` haptic, then remove the tool through the VM
    /// inside `flow` (Reduce Motion collapses the curve via BrandMotion).
    private func performDelete(_ id: String) {
        BrandHaptics.fire(.heavy)
        withAnimation(reduceMotion ? nil : BrandMotion.flow) {
            model.deleteTool(id)
        }
    }

    private func toolName(_ id: String) -> String {
        UniverseSeed.tools.first { $0.id == id }?.name ?? "this tool"
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
