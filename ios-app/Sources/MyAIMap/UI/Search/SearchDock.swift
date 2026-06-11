import SwiftUI

/// Compact glass search bar under the header. Collapsed it is a single
/// capsule field; once focused with a non-empty query it grows a glass
/// results card (max `SearchCore.maxResults` rows). Tapping a row or
/// pressing the search key focuses the tool via `UniverseViewModel`.
/// ⌘K focuses the field on iPad / hardware keyboards (PHASE_2_PLAN
/// step 6 parity with the web build).
struct SearchDock: View {
    @Environment(UniverseViewModel.self) private var model
    @FocusState private var fieldFocused: Bool

    private var results: [Tool] {
        model.searchResults
    }

    private var hasQuery: Bool {
        !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showsResults: Bool {
        fieldFocused && hasQuery
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
            searchField
            if showsResults {
                resultsCard
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .brandAnimation(BrandMotion.nudge, value: showsResults)
        .brandAnimation(BrandMotion.nudge, value: results.map(\.id))
        .background {
            // Hidden ⌘K target — keyboard-only affordance, no visual.
            Button("Focus search") { fieldFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var searchField: some View {
        @Bindable var model = model
        return HStack(spacing: BrandSpacing.s.value) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            TextField("Search tools", text: $model.searchQuery)
                .font(.subheadline)
                .foregroundStyle(.white)
                .tint(model.selectedCategoryModel.color.swiftUIColor)
                .focused($fieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit(submit)

            if hasQuery {
                Button {
                    clearQuery()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(BouncyIconButtonStyle())
            }
        }
        .padding(.horizontal, BrandSpacing.m.value)
        .padding(.vertical, BrandSpacing.s.value + BrandSpacing.hair.value)
        .liquidGlass(
            in: Capsule(),
            tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.5),
            strokeStrength: 0.08
        )
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: BrandSpacing.hair.value) {
            if results.isEmpty {
                Text("No matches")
                    .font(.subheadline)
                    .foregroundStyle(BrandColor.textMuted)
                    .padding(.horizontal, BrandSpacing.m.value)
                    .padding(.vertical, BrandSpacing.s.value)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(results) { tool in
                    resultRow(tool)
                }
            }
        }
        .padding(BrandSpacing.s.value)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
            tint: model.selectedCategoryModel.color.swiftUIColor,
            strokeStrength: 0.12
        )
        .shadow(color: .black.opacity(0.42), radius: 18, x: 0, y: 10)
    }

    private func resultRow(_ tool: Tool) -> some View {
        let category = UniverseSeed.category(tool.category)
        return Button {
            select(tool)
        } label: {
            HStack(spacing: BrandSpacing.s.value) {
                Circle()
                    .fill(category.color.swiftUIColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: category.color.swiftUIColor.opacity(0.6), radius: 3)
                Text(tool.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: BrandSpacing.s.value)
                Text(category.shortName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, BrandSpacing.s.value)
            .padding(.vertical, BrandSpacing.s.value)
            .contentShape(RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil, pressedOpacity: 0.9))
    }

    // MARK: - Actions

    private func select(_ tool: Tool) {
        BrandHaptics.fire(.light)
        withAnimation(BrandMotion.flow) {
            _ = model.focusTool(tool.id)
        }
        clearQuery()
    }

    /// Enter-to-focus parity with the web build: the view model picks
    /// the first ranked match and clears the query itself.
    private func submit() {
        withAnimation(BrandMotion.flow) {
            if model.focusFirstSearchMatch() {
                BrandHaptics.fire(.light)
            }
        }
        fieldFocused = false
    }

    private func clearQuery() {
        model.searchQuery = ""
        fieldFocused = false
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            SearchDock()
            Spacer()
        }
        .padding(16)
    }
    .environment(UniverseViewModel())
    .preferredColorScheme(.dark)
}
