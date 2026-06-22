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
    static func canAdd(name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        let scored = ToolCategoryId.allCases
            .filter { $0 != .core }
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
                ? "Will use Analytics until a name or website gives a stronger signal."
                : "Using the active universe branch until a name or website gives a stronger signal."
        }

        let text = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let matchedKeywords = autoKeywords(for: suggestedCategory).contains { text.contains($0) }
        if matchedKeywords {
            return "Suggested automatically from name, website, and universe context."
        }
        return "No strong keyword match; using the active universe context."
    }

    static func autoKeywords(for category: ToolCategoryId) -> [String] {
        switch category {
        case .coding:
            return ["code", "coding", "developer", "dev", "repo", "github", "ide", "agent", "cursor", "codex", "replit", "lovable"]
        case .design:
            return ["design", "figma", "prototype", "ui", "ux", "mockup", "framer", "mobbin", "relume"]
        case .research:
            return ["research", "data", "scrape", "crawler", "search", "browser", "api", "source", "firecrawl", "perplexity"]
        case .analytics:
            return ["analytics", "metric", "event", "growth", "funnel", "experiment", "posthog", "tracking", "sentry", "amplitude", "mixpanel"]
        case .media:
            return ["video", "media", "image", "creative", "render", "motion", "audio", "gen", "runway", "heygen"]
        case .distribution:
            return ["social", "publish", "schedule", "distribution", "launch", "buffer", "channel", "newsletter"]
        case .infrastructure:
            return ["infra", "database", "backend", "deploy", "server", "cloud", "runtime", "supabase", "vercel", "neon", "railway", "firebase"]
        case .knowledge:
            return ["knowledge", "docs", "skill", "wiki", "notion", "memory", "linear", "obsidian"]
        case .core:
            return []
        }
    }
}

private enum AddToolFocusedField: Hashable {
    case name
    case website
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
    @State private var didApplyDraft = false
    @State private var discardConfirmationPresented = false
    @FocusState private var focusedField: AddToolFocusedField?

    init(draft: MissingToolSuggestion? = nil) {
        self.draft = draft
    }

    private var canAdd: Bool {
        AddToolLogic.canAdd(name: name)
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
                    Color.clear.frame(height: 28)
                }
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }
            .background(BrandColor.void.ignoresSafeArea())
            .navigationTitle("Add Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        requestDismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { add() }
                        .disabled(!canAdd)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(keyboardToolbarTitle) {
                        handleKeyboardToolbarAction()
                    }
                    .font(.headline.weight(.semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
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
            Text("The name, website, or branch choice has not been added yet.")
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
            Text("Add only the name if that is all you have. Website and branch can stay automatic; the app will keep claims guarded until a source is verified.")
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

                    HStack(spacing: 4) {
                        ForEach(AddToolBranchMode.allCases) { mode in
                            branchModeButton(mode)
                        }
                    }
                    .padding(3)
                    .background(.white.opacity(0.055), in: Capsule())
                }

                HStack(spacing: BrandSpacing.m.value) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(UniverseSeed.category(resolvedCategory).shortName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(branchMode == .auto ? autoBranchReason : "Selected manually. Auto suggestions will not override this branch.")
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
                    Picker("Branch", selection: $category) {
                        ForEach(UniverseSeed.categories.filter { $0.id != .core }) { category in
                            Text(category.shortName).tag(category.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(BrandSpacing.m.value)
                    .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
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

    private func branchModeButton(_ mode: AddToolBranchMode) -> some View {
        let isSelected = branchMode == mode
        return Button {
            guard branchMode != mode else { return }
            BrandHaptics.fire(.light)
            withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
                branchMode = mode
            }
        } label: {
            Label(mode.title, systemImage: mode.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? .black.opacity(0.84) : .white.opacity(0.72))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    isSelected ? resolvedCategoryModel.color.swiftUIColor : .clear,
                    in: Capsule()
                )
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.94, haptic: nil))
        .accessibilityLabel("Select \(mode.title) branch mode")
    }

    private var guardrails: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            Label("Relation logic", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(BrandColor.textMuted)
            Text("Auto branch uses the name, website, and active universe context. Relations stay local to the chosen branch, so broad brands are not connected to everything by default.")
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
        guard model.addCustomTool(name: name, urlString: website, category: resolvedCategory) else { return }
        dismiss()
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
            return canAdd ? "Add" : "Done"
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
        case nil:
            focusedField = nil
        }
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
