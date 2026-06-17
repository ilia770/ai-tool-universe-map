import SwiftUI

/// Liquid-glass Settings sheet opened from the account button. Sections:
/// account header, visualization picker, RU/EN language toggle, History entry,
/// Anthropic API key (NavigationLink), data reset/export, About/version.
/// Mirrors the `RootSheet` presentation recipe so its glass matches the
/// tool-detail sheet.
///
/// The sheet's `.presentationDetents([.medium, .large])` are applied at the
/// `UniverseScreen` call site — `NavigationStack` inside the sheet content
/// is correct and must not break the detents.
struct SettingsSheet: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showResetConfirm = false

    private var language: AppLanguage { settings.language }
    private var tint: Color { model.selectedCategoryModel.color.swiftUIColor }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    accountHeader
                    visualizationSection(settings: settings)
                    languageSection(settings: settings)
                    historySection
                    manageToolsRow
                    apiKeyRow
                    dataSection
                    aboutSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                tint.opacity(0.07)
            }
        }
        .confirmationDialog(
            L10n.resetData(language),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.resetData(language), role: .destructive) {
                BrandHaptics.fire(.success)
                settings.reset()
            }
        }
    }

    // MARK: - Sheet header (title + Done)

    private var header: some View {
        HStack {
            Text(L10n.settingsTitle(language))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Button {
                BrandHaptics.fire(.light)
                dismiss()
            } label: {
                Text(L10n.done(language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .buttonStyle(PressableButtonStyle(haptic: nil))
        }
    }

    // MARK: - Account header

    var accountHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.account(language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("My AI Map")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.46))
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), tint: tint, strokeStrength: 0.1)
    }

    // MARK: - Sections

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.46))
    }

    private func visualizationSection(settings: AppSettings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(L10n.visualizationStyle(language))
            VStack(spacing: 0) {
                ForEach(VisualizationStyle.allCases) { style in
                    Button {
                        guard style.available, settings.visualizationStyle != style else {
                            BrandHaptics.fire(.light)
                            return
                        }
                        BrandHaptics.fire(.medium)
                        withAnimation(BrandMotion.resolved(BrandMotion.nudge, reduceMotion: reduceMotion)) {
                            settings.visualizationStyle = style
                        }
                    } label: {
                        HStack {
                            Text(style.title(language))
                                .foregroundStyle(style.available ? .white : .white.opacity(0.32))
                            Spacer()
                            if settings.visualizationStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(tint)
                            } else if !style.available {
                                Text(language == .ru ? "скоро" : "soon")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.vertical, 11)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle(haptic: nil, pressedOpacity: 0.9))
                    .disabled(!style.available)
                }
            }
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), tint: tint, strokeStrength: 0.1)
        }
    }

    private func languageSection(settings: AppSettings) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(L10n.language(language))
            HStack(spacing: 4) {
                ForEach(AppLanguage.allCases) { lang in
                    let isSelected = settings.language == lang
                    Button {
                        BrandHaptics.fire(.light)
                        guard settings.language != lang else { return }
                        withAnimation(BrandMotion.resolved(BrandMotion.nudge, reduceMotion: reduceMotion)) {
                            settings.language = lang
                        }
                    } label: {
                        Text(lang.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                if isSelected { Capsule().fill(tint.opacity(0.22)) }
                            }
                            .overlay(
                                Capsule().stroke(isSelected ? tint.opacity(0.64) : .clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.95, haptic: nil, pressedOpacity: 0.92))
                }
            }
            .padding(4)
            .liquidGlass(in: Capsule(), strokeStrength: 0.08)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(L10n.history(language))
            // History destination ships in a later product-v2 part; this
            // row is the entry point. Tapping fires feedback only for now.
            Button {
                BrandHaptics.fire(.light)
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(L10n.history(language))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(haptic: nil, pressedOpacity: 0.9))
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeStrength: 0.1)
        }
    }

    // MARK: - Manage tools row (NavigationLink)

    private var manageToolsRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                ManageToolsScreen()
                    .environment(model)
                    .environment(settings)
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text(L10n.manageTools(language))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(haptic: nil, pressedOpacity: 0.9))
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeStrength: 0.1)
        }
    }

    // MARK: - API key row (NavigationLink)

    var apiKeyRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(L10n.apiKey(language))
            NavigationLink {
                APIKeyScreen()
                    .environment(settings)
            } label: {
                HStack {
                    Image(systemName: "key")
                    Text(L10n.apiKey(language))
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.3))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableButtonStyle(haptic: nil, pressedOpacity: 0.9))
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeStrength: 0.1)
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(L10n.dataManagement(language))
            VStack(spacing: 0) {
                if let data = try? settings.exportJSON() {
                    ShareLink(
                        item: data,
                        preview: SharePreview("myaimap-settings.json")
                    ) {
                        rowLabel(systemImage: "square.and.arrow.up", title: L10n.exportData(language), tintRow: false)
                    }
                    .buttonStyle(PressableButtonStyle(haptic: .light, pressedOpacity: 0.9))
                }
                Button(role: .destructive) {
                    BrandHaptics.fire(.warning)
                    showResetConfirm = true
                } label: {
                    rowLabel(systemImage: "trash", title: L10n.resetData(language), tintRow: true)
                }
                .buttonStyle(PressableButtonStyle(haptic: nil, pressedOpacity: 0.9))
            }
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeStrength: 0.1)
        }
    }

    private func rowLabel(systemImage: String, title: String, tintRow: Bool) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
            Spacer()
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(tintRow ? Color.red.opacity(0.9) : .white)
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(L10n.about(language))
            HStack {
                Text(L10n.version(language))
                    .foregroundStyle(.white.opacity(0.74))
                Spacer()
                Text(Self.appVersion)
                    .foregroundStyle(.white.opacity(0.46))
            }
            .font(.subheadline)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeStrength: 0.1)
        }
    }

    private static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    Color.black.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            SettingsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .environment(UniverseViewModel())
                .environment(AppSettings())
        }
        .preferredColorScheme(.dark)
}
