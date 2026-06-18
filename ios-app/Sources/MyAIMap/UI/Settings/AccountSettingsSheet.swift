import SwiftUI

struct AccountSettingsSheet: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var section: AccountSection = .settings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrandSpacing.xl.value) {
                    accountHeader

                    Picker("Account section", selection: $section) {
                        ForEach(AccountSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch section {
                    case .settings:
                        settingsContent
                    case .history:
                        historyContent
                    }
                }
                .padding(BrandSpacing.l.value)
            }
            .scrollIndicators(.hidden)
            .background(BrandColor.void.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(BouncyIconButtonStyle())
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var accountHeader: some View {
        HStack(spacing: BrandSpacing.m.value) {
            Circle()
                .fill(model.selectedCategoryModel.color.swiftUIColor.opacity(0.24))
                .frame(width: 58, height: 58)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white, model.selectedCategoryModel.color.swiftUIColor)
                }
                .liquidGlass(in: Circle(), tint: model.selectedCategoryModel.color.swiftUIColor, strokeStrength: 0.12)

            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                Text("AI Universe")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(model.visibleAllTools.count) active tools")
                    .font(.subheadline)
                    .foregroundStyle(BrandColor.textSecondary)
            }
            Spacer()
        }
    }

    private var settingsContent: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: BrandSpacing.l.value) {
            settingsGroup(title: "Visualization", systemImage: "circle.hexagongrid.fill") {
                VStack(spacing: BrandSpacing.s.value) {
                    ForEach(VisualizationStyle.allCases) { style in
                        Button {
                            withAnimation(BrandMotion.flow) {
                                model.visualizationStyle = style
                            }
                        } label: {
                            visualizationRow(style)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))
                    }
                }
            }

            settingsGroup(title: "Language", systemImage: "globe") {
                Picker("Language", selection: $model.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            settingsGroup(title: "Behavior", systemImage: "hand.tap.fill") {
                Toggle("Haptics", isOn: $model.hapticsEnabled)
                    .tint(model.selectedCategoryModel.color.swiftUIColor)
                Text("The assistant asks for a website when a service is missing instead of inventing facts.")
                    .font(.footnote)
                    .foregroundStyle(BrandColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.removedTools.isEmpty {
                settingsGroup(title: "Hidden tools", systemImage: "eye.slash.fill") {
                    VStack(spacing: BrandSpacing.s.value) {
                        ForEach(model.removedTools) { tool in
                            Button {
                                withAnimation(BrandMotion.nudge) {
                                    _ = model.restoreTool(tool.id)
                                }
                            } label: {
                                HStack {
                                    Text(tool.name)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Image(systemName: "arrow.uturn.backward")
                                }
                                .foregroundStyle(.white)
                                .padding(BrandSpacing.m.value)
                                .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
                            }
                            .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))
                        }
                    }
                }
            }
        }
    }

    private var historyContent: some View {
        settingsGroup(title: "Recent activity", systemImage: "clock.arrow.circlepath") {
            if model.activityHistory.isEmpty {
                VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                    Text("No activity yet")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Added, removed, restored, opened, and assistant actions will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(BrandColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: BrandSpacing.s.value) {
                    ForEach(model.activityHistory) { activity in
                        Button {
                            open(activity)
                        } label: {
                            activityRow(activity)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.98, haptic: nil))
                        .disabled(activity.toolID == nil)
                    }
                }
            }
        }
    }

    private func settingsGroup<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BrandSpacing.m.value) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(BrandColor.textMuted)

            content()
        }
        .padding(BrandSpacing.l.value)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous),
            tint: model.selectedCategoryModel.color.swiftUIColor.opacity(0.35),
            strokeStrength: 0.08
        )
    }

    private func visualizationRow(_ style: VisualizationStyle) -> some View {
        let isSelected = style == model.visualizationStyle
        return HStack(spacing: BrandSpacing.m.value) {
            Text(style.shortLabel)
                .font(.headline.weight(.bold))
                .foregroundStyle(isSelected ? .black.opacity(0.82) : .white)
                .frame(width: 34, height: 34)
                .background(isSelected ? model.selectedCategoryModel.color.swiftUIColor : BrandColor.muted, in: Circle())

            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                Text(style.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(style.detail)
                    .font(.caption)
                    .foregroundStyle(BrandColor.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(model.selectedCategoryModel.color.swiftUIColor)
            }
        }
        .padding(BrandSpacing.m.value)
        .background(isSelected ? model.selectedCategoryModel.color.swiftUIColor.opacity(0.12) : BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous)
                .stroke(isSelected ? model.selectedCategoryModel.color.swiftUIColor.opacity(0.55) : BrandColor.stroke, lineWidth: 1)
        }
    }

    private func activityRow(_ activity: UniverseActivity) -> some View {
        HStack(spacing: BrandSpacing.m.value) {
            Image(systemName: icon(for: activity.kind))
                .font(.subheadline.weight(.semibold))
                .frame(width: 28, height: 28)
                .foregroundStyle(model.selectedCategoryModel.color.swiftUIColor)
                .background(BrandColor.muted, in: Circle())

            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                Text(activity.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(activity.detail)
                    .font(.caption)
                    .foregroundStyle(BrandColor.textMuted)
                    .lineLimit(2)
            }

            Spacer()

            Text(activity.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BrandColor.textMuted)
        }
        .padding(BrandSpacing.m.value)
        .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
    }

    private func icon(for kind: UniverseActivityKind) -> String {
        switch kind {
        case .added: return "plus"
        case .removed: return "trash"
        case .restored: return "arrow.uturn.backward"
        case .focused: return "scope"
        case .asked: return "sparkles"
        }
    }

    private func open(_ activity: UniverseActivity) {
        guard let id = activity.toolID, model.focusTool(id) else { return }
        dismiss()
    }
}

private enum AccountSection: String, CaseIterable, Identifiable {
    case settings
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings: return "Settings"
        case .history: return "History"
        }
    }
}

#Preview {
    AccountSettingsSheet()
        .environment(UniverseViewModel())
}
