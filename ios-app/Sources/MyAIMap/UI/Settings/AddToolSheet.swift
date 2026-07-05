import SwiftUI
import UIKit

enum AddToolBranchMode: String, CaseIterable, Identifiable, Equatable {
    case auto
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .manual: return "Manual"
        }
    }

    var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .manual: return "slider.horizontal.3"
        }
    }
}

enum AddToolLogic {
    /// Add is allowed once the tool has a non-empty name. When the user is
    /// creating a NEW branch (manual "+ New branch"), the branch must ALSO be
    /// named — otherwise the "New branch" the header promises has no name and
    /// the tool would silently fall back to the picker branch.
    static func canAdd(
        name: String,
        isCreatingBranch: Bool = false,
        branchName: String = ""
    ) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if isCreatingBranch {
            return !branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    static func resolvedCategory(
        mode: AddToolBranchMode,
        manualCategory: ToolCategoryId,
        suggestedCategory: ToolCategoryId
    ) -> ToolCategoryId {
        mode == .auto ? suggestedCategory : manualCategory
    }

    static func suggestedCategory(
        name: String,
        website: String,
        activeCategory: ToolCategoryId
    ) -> ToolCategoryId {
        let text = "\(name) \(website)".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let scored = ToolCategoryId.builtins
            .map { category -> (ToolCategoryId, Int) in
                let keywordHits = autoKeywords(for: category).reduce(0) { score, keyword in
                    text.contains(keyword) ? score + 1 : score
                }
                let contextBoost = activeCategory == category ? 1 : 0
                return (category, keywordHits * 10 + contextBoost)
            }

        if let winner = scored.max(by: { $0.1 < $1.1 }), winner.1 > 0 {
            return winner.0
        }
        return activeCategory == .core ? .analytics : activeCategory
    }

    static func autoReason(
        name: String,
        website: String,
        activeCategory: ToolCategoryId,
        suggestedCategory: ToolCategoryId
    ) -> String {
        let clean = "\(name) \(website)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return activeCategory == .core
                ? "Using Analytics until name or website gives a signal."
                : "Using the active branch until name or website gives a signal."
        }

        if let proposed = proposedBranchName(name: name, website: website, activeCategory: activeCategory) {
            return "No existing branch fits — I'll create a '\(proposed)' branch."
        }

        let text = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let matchedKeywords = autoKeywords(for: suggestedCategory).contains { text.contains($0) }
        if matchedKeywords {
            return "Suggested from name, website, and context."
        }
        return "No strong match; using the active context."
    }

    /// The Auto path proposes a NEW branch (blueprint §8) when no built-in
    /// branch keyword fits and the active context is the centre (no branch to
    /// fall back on). Returns the proposed branch name (the tool's own name), or
    /// `nil` when an existing branch is a good enough home. Kept pure/testable.
    static func proposedBranchName(
        name: String,
        website: String,
        activeCategory: ToolCategoryId
    ) -> String? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        // Only propose from the centre: when the user is already focused on a
        // branch, that branch is the natural home and we don't override it.
        guard activeCategory == .core else { return nil }
        let text = "\(name) \(website)".folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let anyKeywordHit = ToolCategoryId.builtins.contains { category in
            autoKeywords(for: category).contains { text.contains($0) }
        }
        // A weak signal (no keyword hit anywhere) from the centre → new branch.
        return anyKeywordHit ? nil : cleanName
    }

    static func autoKeywords(for category: ToolCategoryId) -> [String] {
        // Keyed by built-in id; custom (user/AI-created) branches have no
        // keyword profile and fall through to `[]` so they score zero in the
        // auto-suggest pass (they are only selected manually or via the
        // "no existing branch fits" proposal).
        autoKeywordsByCategory[category] ?? []
    }

    private static let autoKeywordsByCategory: [ToolCategoryId: [String]] = [
        .coding: ["code", "coding", "developer", "dev", "repo", "github", "ide", "agent", "cursor", "codex", "replit", "lovable"],
        .design: ["design", "figma", "prototype", "ui", "ux", "mockup", "framer", "mobbin", "relume"],
        .research: ["research", "data", "scrape", "crawler", "search", "browser", "api", "source", "firecrawl", "perplexity"],
        .analytics: ["analytics", "metric", "event", "growth", "funnel", "experiment", "posthog", "tracking", "sentry", "amplitude", "mixpanel"],
        .media: ["video", "media", "image", "creative", "render", "motion", "audio", "gen", "runway", "heygen"],
        .distribution: ["social", "publish", "schedule", "distribution", "launch", "buffer", "channel", "newsletter"],
        .infrastructure: ["infra", "database", "backend", "deploy", "server", "cloud", "runtime", "supabase", "vercel", "neon", "railway", "firebase"],
        .knowledge: ["knowledge", "docs", "skill", "wiki", "notion", "memory", "linear", "obsidian"],
    ]
}

private enum AddToolFocusedField: Hashable {
    case name
    case website
    case newBranch
}

struct AddToolSheet: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let draft: MissingToolSuggestion?
    @State private var name = ""
    @State private var website = ""
    @State private var category: ToolCategoryId = .analytics
    @State private var branchMode: AddToolBranchMode = .auto
    /// Manual "+ New branch": when on, the resolved branch is created from
    /// `newBranchName` on Add instead of using the picker selection.
    @State private var isCreatingBranch = false
    @State private var newBranchName = ""
    @State private var didApplyDraft = false
    @State private var discardConfirmationPresented = false
    @FocusState private var focusedField: AddToolFocusedField?
    @Namespace private var sheetChromeNamespace

    init(draft: MissingToolSuggestion? = nil) {
        self.draft = draft
    }

    private var canAdd: Bool {
        AddToolLogic.canAdd(
            name: name,
            isCreatingBranch: branchMode == .manual && isCreatingBranch,
            branchName: newBranchName
        )
    }

    private var resolvedCategory: ToolCategoryId {
        AddToolLogic.resolvedCategory(
            mode: branchMode,
            manualCategory: category,
            suggestedCategory: suggestedCategory
        )
    }

    private var resolvedCategoryModel: ToolCategory {
        UniverseSeed.category(resolvedCategory)
    }

    private var hasUnsavedChanges: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !website.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || branchMode == .manual
            || !newBranchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: BrandSpacing.xl.value) {
                        intro
                        fields
                        guardrails
                    }
                    .padding(BrandSpacing.l.value)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom) {
                    bottomActionBar
                }
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                        proxy.scrollTo(field, anchor: scrollAnchor(for: field))
                    }
                }
            }
            // Translucent dark glass tint over the frosted presentation backdrop
            // (set below) so the universe shows through with a light back-blur
            // instead of a flat opaque void fill.
            .background(BrandColor.glass.ignoresSafeArea())
            .navigationTitle("Add Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    sheetChromeButton("Cancel", systemImage: "xmark", enabled: true) {
                        requestDismiss()
                    }
                    .navigationGlassMorphID("AddToolSheet.cancel", in: sheetChromeNamespace)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    sheetChromeButton("Add", systemImage: "plus", enabled: canAdd, prominent: true) {
                        add()
                    }
                        .disabled(!canAdd)
                        .navigationGlassMorphID("AddToolSheet.add", in: sheetChromeNamespace)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(.ultraThinMaterial)
        .background {
            InteractiveDismissAttemptHandler(isDisabled: hasUnsavedChanges) {
                handleInteractiveDismissAttempt()
            }
            .frame(width: 0, height: 0)
        }
        .confirmationDialog(
            "Discard this tool?",
            isPresented: $discardConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                focusedField = nil
                dismiss()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("This tool hasn't been added yet.")
        }
        .onAppear {
            focusedField = .name
            if !didApplyDraft, let draft {
                name = draft.name
                category = draft.category
                branchMode = .manual
                didApplyDraft = true
            } else if model.selection.activeCategory != .core {
                category = model.selection.activeCategory
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            Text("Place a service")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Name is enough. Website and branch can stay automatic.")
                .font(.subheadline)
                .foregroundStyle(BrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BrandSpacing.l.value)
        // Sheet info card = content → solid surface, not glass (glass MAP).
        .background(
            BrandColor.card,
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
                .stroke(BrandColor.stroke, lineWidth: 0.5)
        }
    }

    private func sheetChromeButton(
        _ title: String,
        systemImage: String,
        enabled: Bool,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(.footnote, weight: .bold))
            }
            .foregroundStyle(.white.opacity(enabled ? 0.88 : 0.36))
            .padding(.horizontal, BrandSpacing.m.value)
            .padding(.vertical, BrandSpacing.s.value)
            .glassSurface(
                in: Capsule(),
                tint: .white.opacity(prominent && enabled ? 0.14 : 0.07),
                interactive: enabled
            )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil, pressedOpacity: 0.9))
        .hitArea()
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.l.value) {
            field(label: "Name", systemImage: "textformat") {
                TextField("PostHog, Supabase, Firecrawl...", text: $name)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onSubmit {
                        focusedField = .website
                    }
            }
            .id(AddToolFocusedField.name)
            .overlay(alignment: .bottomLeading) {
                nameRequirementHint
                    .offset(y: 22)
            }
            .padding(.bottom, 14)

            field(label: "Website optional", systemImage: "link") {
                TextField("https://example.com", text: $website)
                    .focused($focusedField, equals: .website)
                    .submitLabel(canAdd ? .done : .next)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        if canAdd {
                            add()
                        } else {
                            focusedField = nil
                        }
                    }
            }
            .id(AddToolFocusedField.website)

            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                HStack(spacing: BrandSpacing.s.value) {
                    Label("Branch", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(BrandColor.textMuted)

                    Spacer()

                    GlassMorphCluster(
                        options: AddToolBranchMode.allCases,
                        selection: branchModeBinding,
                        base: "addTool.branchMode",
                        tint: resolvedCategoryModel.color.swiftUIColor
                    ) { mode, _ in
                        Label(mode.title, systemImage: mode.icon)
                    }
                }

                HStack(spacing: BrandSpacing.m.value) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(branchHeaderTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(branchHeaderReason)
                            .font(.caption)
                            .foregroundStyle(BrandColor.textMuted)
                            .lineLimit(2)
                    }

                    Spacer()

                    if branchMode == .auto {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(resolvedCategoryModel.color.swiftUIColor)
                    }
                }
                .padding(BrandSpacing.m.value)
                .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))

                if branchMode == .manual {
                    if isCreatingBranch {
                        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                            TextField("New branch name", text: $newBranchName)
                                .focused($focusedField, equals: .newBranch)
                                .submitLabel(.done)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .padding(BrandSpacing.m.value)
                                .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
                                .id(AddToolFocusedField.newBranch)

                            Button {
                                withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                                    isCreatingBranch = false
                                    newBranchName = ""
                                }
                            } label: {
                                Label("Pick an existing branch instead", systemImage: "arrow.uturn.backward")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BrandColor.textMuted)
                            }
                            .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
                        }
                    } else {
                        Picker("Branch", selection: $category) {
                            ForEach(model.allCategories.filter { $0.id != .core }) { category in
                                Text(category.shortName).tag(category.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(BrandSpacing.m.value)
                        .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))

                        Button {
                            BrandHaptics.fire(.light)
                            withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                                isCreatingBranch = true
                            }
                            focusedField = .newBranch
                        } label: {
                            Label("New branch", systemImage: "plus.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(resolvedCategoryModel.color.swiftUIColor)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
                    }
                }
            }
        }
        .padding(BrandSpacing.l.value)
        // Sheet form card = content → solid surface, not glass (glass MAP).
        .background(
            BrandColor.card,
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
                .stroke(BrandColor.stroke, lineWidth: 0.5)
        }
    }

    /// Bridges the enum branch mode to the cluster's `Binding<Int>`, preserving
    /// the prior tap behaviour (guard, light haptic, nudge animation).
    private var branchModeBinding: Binding<Int> {
        Binding(
            get: { AddToolBranchMode.allCases.firstIndex(of: branchMode) ?? 0 },
            set: { index in
                guard index < AddToolBranchMode.allCases.count else { return }
                let target = AddToolBranchMode.allCases[index]
                guard branchMode != target else { return }
                BrandHaptics.fire(.light)
                withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                    branchMode = target
                }
            }
        )
    }

    private var guardrails: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            Label("Relation logic", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(BrandColor.textMuted)
            Text("Relations stay local to the chosen branch, so broad brands aren't linked to everything.")
                .font(.footnote)
                .foregroundStyle(BrandColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(BrandSpacing.l.value)
        // Guardrails info card = content → solid surface, not glass (glass MAP).
        .background(
            BrandColor.card,
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
                .stroke(BrandColor.stroke, lineWidth: 0.5)
        }
    }

    private func field<Content: View>(
        label: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            Label(label, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(BrandColor.textMuted)
            content()
                .font(.subheadline)
                .foregroundStyle(.white)
                .tint(resolvedCategoryModel.color.swiftUIColor)
                .padding(BrandSpacing.m.value)
                .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        }
    }

    private func add() {
        focusedField = nil
        let category = categoryForAdd()
        guard model.addCustomTool(name: name, urlString: website, category: category) else { return }
        dismiss()
    }

    /// Resolves the branch to add into, creating a NEW branch when the user
    /// asked for one (manual "+ New branch") or when Auto proposed one because
    /// no existing branch fit (blueprint §8).
    private func categoryForAdd() -> ToolCategoryId {
        if branchMode == .manual {
            let pending = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
            if isCreatingBranch, !pending.isEmpty {
                return model.createBranch(name: pending)
            }
            return category
        }
        if let proposed = AddToolLogic.proposedBranchName(
            name: name,
            website: website,
            activeCategory: model.selection.activeCategory
        ) {
            return model.createBranch(name: proposed)
        }
        return suggestedCategory
    }

    private func requestDismiss() {
        focusedField = nil
        if hasUnsavedChanges {
            discardConfirmationPresented = true
        } else {
            dismiss()
        }
    }

    private func handleInteractiveDismissAttempt() {
        focusedField = nil
        if hasUnsavedChanges {
            discardConfirmationPresented = true
        }
    }

    private var keyboardToolbarTitle: String {
        switch focusedField {
        case .name:
            return "Next"
        case .website:
            return canAdd ? "Add Tool" : "Done"
        case .newBranch:
            return "Done"
        case nil:
            return "Done"
        }
    }

    private func handleKeyboardToolbarAction() {
        switch focusedField {
        case .name:
            focusedField = .website
        case .website:
            if canAdd {
                add()
            } else {
                focusedField = nil
            }
        case .newBranch:
            focusedField = nil
        case nil:
            focusedField = nil
        }
    }

    /// Docked bottom action bar. The advance/submit action lives INSIDE the
    /// scroll view's bottom safe-area inset rather than a free-floating keyboard
    /// accessory (`ToolbarItemGroup(placement: .keyboard)`). Because the inset's
    /// reserved space IS the button's own footprint, form content can never
    /// scroll underneath the pill and get clipped (D4: the "Manual" branch pill
    /// and "Relation logic" card were covered by the floating accessory button).
    /// Keyboard avoidance lifts the bar above the keyboard, so it stays reachable.
    @ViewBuilder
    private var bottomActionBar: some View {
        if focusedField != nil {
            HStack {
                Spacer()
                Button(action: handleKeyboardToolbarAction) {
                    Text(keyboardToolbarTitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, BrandSpacing.l.value)
                        .padding(.vertical, BrandSpacing.s.value)
                        .glassSurface(
                            in: Capsule(),
                            tint: resolvedCategoryModel.color.swiftUIColor.opacity(0.18),
                            interactive: true
                        )
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.96, haptic: nil))
                .hitArea()
            }
            .padding(.horizontal, BrandSpacing.l.value)
            .padding(.vertical, BrandSpacing.s.value)
            .background(.ultraThinMaterial)
        } else {
            Color.clear.frame(height: 28)
        }
    }

    private func scrollAnchor(for field: AddToolFocusedField) -> UnitPoint {
        switch field {
        case .name:
            return .top
        case .website:
            return .center
        case .newBranch:
            return .center
        }
    }

    private var nameRequirementHint: some View {
        HStack(spacing: 5) {
            Image(systemName: canAdd ? "checkmark.circle.fill" : "info.circle")
                .font(.caption2.weight(.bold))
            Text(canAdd ? "Name is enough to add." : "Name required; website can stay empty.")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(canAdd ? .white.opacity(0.70) : BrandColor.textMuted)
        .accessibilityLabel(canAdd ? "Name is enough to add" : "Name is required; website can stay empty")
    }

    private var suggestedCategory: ToolCategoryId {
        AddToolLogic.suggestedCategory(
            name: name,
            website: website,
            activeCategory: model.selection.activeCategory
        )
    }

    private var autoBranchReason: String {
        AddToolLogic.autoReason(
            name: name,
            website: website,
            activeCategory: model.selection.activeCategory,
            suggestedCategory: suggestedCategory
        )
    }

    /// Title shown in the branch summary card: the pending new-branch name when
    /// one is being created, otherwise the resolved branch's short name.
    private var branchHeaderTitle: String {
        if branchMode == .manual, isCreatingBranch {
            let pending = newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
            return pending.isEmpty ? "New branch" : pending
        }
        if branchMode == .auto,
           let proposed = AddToolLogic.proposedBranchName(
               name: name,
               website: website,
               activeCategory: model.selection.activeCategory
           ) {
            return proposed
        }
        return UniverseSeed.category(resolvedCategory).shortName
    }

    private var branchHeaderReason: String {
        if branchMode == .manual {
            return isCreatingBranch
                ? "A new branch will be created for this tool."
                : "Selected manually. Auto won't override this."
        }
        return autoBranchReason
    }
}

#Preview {
    AddToolSheet()
        .environment(UniverseViewModel())
}

private struct InteractiveDismissAttemptHandler: UIViewControllerRepresentable {
    let isDisabled: Bool
    let onAttempt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isDisabled: isDisabled, onAttempt: onAttempt)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isDisabled = isDisabled
        context.coordinator.onAttempt = onAttempt
        DispatchQueue.main.async {
            let controller = uiViewController.parent?.presentationController
                ?? uiViewController.presentationController
            controller?.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isDisabled: Bool
        var onAttempt: () -> Void

        init(isDisabled: Bool, onAttempt: @escaping () -> Void) {
            self.isDisabled = isDisabled
            self.onAttempt = onAttempt
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !isDisabled
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            guard isDisabled else { return }
            DispatchQueue.main.async { [onAttempt] in
                onAttempt()
            }
        }
    }
}
