import SwiftUI

struct AddToolSheet: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var website = ""
    @State private var category: ToolCategoryId = .analytics
    @State private var usesAutoBranch = true
    @FocusState private var nameFocused: Bool

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resolvedCategory: ToolCategoryId {
        usesAutoBranch ? suggestedCategory : category
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrandSpacing.xl.value) {
                    intro
                    fields
                    guardrails
                }
                .padding(BrandSpacing.l.value)
            }
            .scrollIndicators(.hidden)
            .background(BrandColor.void.ignoresSafeArea())
            .navigationTitle("Add Tool")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { add() }
                        .disabled(!canAdd)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            nameFocused = true
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
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
            tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.35),
            strokeStrength: 0.08
        )
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.l.value) {
            field(label: "Name", systemImage: "textformat") {
                TextField("PostHog, Supabase, Firecrawl...", text: $name)
                    .focused($nameFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }

            field(label: "Website optional", systemImage: "link") {
                TextField("https://example.com", text: $website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                HStack(spacing: BrandSpacing.s.value) {
                    Label("Branch", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(BrandColor.textMuted)

                    Spacer()

                    Button {
                        BrandHaptics.fire(.light)
                        withAnimation(BrandMotion.nudge) {
                            usesAutoBranch.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: usesAutoBranch ? "sparkles" : "slider.horizontal.3")
                            Text(usesAutoBranch ? "Auto" : "Manual")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(usesAutoBranch ? .black.opacity(0.84) : .white.opacity(0.82))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            usesAutoBranch ? model.selectedCategoryModel.color.swiftUIColor : .white.opacity(0.08),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.94, haptic: nil))
                    .accessibilityLabel(usesAutoBranch ? "Automatic branch enabled" : "Manual branch enabled")
                }

                HStack(spacing: BrandSpacing.m.value) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(UniverseSeed.category(resolvedCategory).shortName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(usesAutoBranch ? autoBranchReason : "Selected manually")
                            .font(.caption)
                            .foregroundStyle(BrandColor.textMuted)
                            .lineLimit(2)
                    }

                    Spacer()

                    if usesAutoBranch {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(model.selectedCategoryModel.color.swiftUIColor)
                    }
                }
                .padding(BrandSpacing.m.value)
                .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))

                if !usesAutoBranch {
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
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
            tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.25),
            strokeStrength: 0.08
        )
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
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
            tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.2),
            strokeStrength: 0.06
        )
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
                .tint(model.selectedCategoryModel.color.swiftUIColor)
                .padding(BrandSpacing.m.value)
                .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        }
    }

    private func add() {
        guard model.addCustomTool(name: name, urlString: website, category: resolvedCategory) else { return }
        dismiss()
    }

    private var suggestedCategory: ToolCategoryId {
        let text = "\(name) \(website)".lowercased()
        let scores = ToolCategoryId.allCases
            .filter { $0 != .core }
            .map { category in
                (category, autoKeywords(for: category).reduce(0) { score, keyword in
                    text.contains(keyword) ? score + 1 : score
                })
            }
        let winner = scores.max { $0.1 < $1.1 }
        if let winner, winner.1 > 0 {
            return winner.0
        }
        return model.selection.activeCategory == .core ? .analytics : model.selection.activeCategory
    }

    private var autoBranchReason: String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanName.isEmpty {
            return "Will use the active universe context until a name is entered."
        }
        return "Suggested from name, website, and current universe context."
    }

    private func autoKeywords(for category: ToolCategoryId) -> [String] {
        switch category {
        case .coding:
            return ["code", "coding", "developer", "dev", "repo", "github", "ide", "agent", "cursor", "codex"]
        case .design:
            return ["design", "figma", "prototype", "ui", "ux", "mockup", "framer"]
        case .research:
            return ["research", "data", "scrape", "crawler", "search", "browser", "api", "source"]
        case .analytics:
            return ["analytics", "metric", "event", "growth", "funnel", "experiment", "posthog", "tracking"]
        case .media:
            return ["video", "media", "image", "creative", "render", "motion", "audio", "gen"]
        case .distribution:
            return ["social", "publish", "schedule", "distribution", "launch", "buffer", "channel"]
        case .infrastructure:
            return ["infra", "database", "backend", "deploy", "server", "cloud", "runtime", "supabase", "vercel"]
        case .knowledge:
            return ["knowledge", "docs", "skill", "wiki", "notion", "memory"]
        case .core:
            return []
        }
    }
}

#Preview {
    AddToolSheet()
        .environment(UniverseViewModel())
}
