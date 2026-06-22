import SwiftUI

struct AccountSettingsSheet: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var section: AccountSection = .settings
    @State private var showResetConfirm = false
    @State private var deepSeekKeyInput = ""
    @State private var deepSeekKeySet = KeychainStore.hasValue(account: KeychainStore.deepSeekAPIKeyAccount)

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
            UserAvatarImage(size: 58, tint: model.selectedCategoryModel.color.swiftUIColor)

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
                    ForEach(UniverseRenderMode.allCases) { renderMode in
                        Button {
                            withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) {
                                model.renderMode = renderMode
                            }
                        } label: {
                            renderModeRow(renderMode)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))
                    }
                }
            }

            settingsGroup(title: "Language", systemImage: "globe") {
                VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                    Picker("Language", selection: $model.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(true)
                    .opacity(0.58)

                    Text("System follows your device language. Manual language selection is coming soon.")
                        .font(.footnote)
                        .foregroundStyle(BrandColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            settingsGroup(title: "Behavior", systemImage: "hand.tap.fill") {
                Toggle("Haptics", isOn: $model.hapticsEnabled)
                    .tint(model.selectedCategoryModel.color.swiftUIColor)
                Text("The assistant asks for a website when a service is missing instead of inventing facts.")
                    .font(.footnote)
                    .foregroundStyle(BrandColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            settingsGroup(title: "AI assistant", systemImage: "sparkles") {
                VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                    HStack(spacing: BrandSpacing.s.value) {
                        Image(systemName: deepSeekKeySet ? "checkmark.seal.fill" : "key.slash")
                            .foregroundStyle(deepSeekKeySet ? model.selectedCategoryModel.color.swiftUIColor : BrandColor.textMuted)
                        Text(deepSeekKeySet ? "DeepSeek key set" : "DeepSeek key not set")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }

                    SecureField("DeepSeek API key", text: $deepSeekKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.done)
                        .padding(BrandSpacing.m.value)
                        .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
                        .foregroundStyle(.white)

                    HStack(spacing: BrandSpacing.s.value) {
                        Button {
                            saveDeepSeekKey()
                        } label: {
                            universeActionRow("Save key", systemImage: "tray.and.arrow.down", destructive: false)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))
                        .disabled(deepSeekKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(role: .destructive) {
                            clearDeepSeekKey()
                        } label: {
                            universeActionRow("Clear", systemImage: "trash", destructive: true)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))
                        .disabled(!deepSeekKeySet)
                    }

                    Text("Optional, cheaper AI. Paste a DeepSeek API key to answer with DeepSeek instead of the on-device assistant. The key is stored on device (Keychain); without it, the local assistant is used.")
                        .font(.footnote)
                        .foregroundStyle(BrandColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            settingsGroup(title: "Universe", systemImage: "globe.americas.fill") {
                VStack(spacing: BrandSpacing.s.value) {
                    Button {
                        withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) { _ = model.loadSampleUniverse() }
                    } label: {
                        universeActionRow("Load sample universe", systemImage: "sparkles", destructive: false)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))

                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        universeActionRow("Reset universe", systemImage: "trash", destructive: true)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))
                    .disabled(!model.hasStoredData)
                }
            }
            .confirmationDialog("Reset universe?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    withBrandAnimation(BrandMotion.flow, reduceMotion: reduceMotion) { model.resetUniverse() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Removes every tool you've added. This can't be undone.")
            }

            if !model.removedTools.isEmpty {
                settingsGroup(title: "Hidden tools", systemImage: "eye.slash.fill") {
                    VStack(spacing: BrandSpacing.s.value) {
                        ForEach(model.removedTools) { tool in
                            Button {
                                withBrandAnimation(BrandMotion.nudge, reduceMotion: reduceMotion) {
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

    private func universeActionRow(_ title: String, systemImage: String, destructive: Bool) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(destructive ? Color.red : .white)
        .padding(BrandSpacing.m.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandColor.muted, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
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
        // Settings group = content panel → solid surface, not glass (glass MAP).
        .background(
            BrandColor.card,
            in: RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: BrandRadius.card.value, style: .continuous)
                .stroke(BrandColor.stroke, lineWidth: 0.5)
        }
    }

    private func renderModeRow(_ renderMode: UniverseRenderMode) -> some View {
        let isSelected = renderMode == model.renderMode
        return HStack(spacing: BrandSpacing.m.value) {
            Text(renderMode.shortLabel)
                .font(.headline.weight(.bold))
                .foregroundStyle(isSelected ? .black.opacity(0.82) : .white)
                .frame(width: 42, height: 34)
                .background(isSelected ? model.selectedCategoryModel.color.swiftUIColor : BrandColor.muted, in: Circle())

            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                HStack(spacing: 6) {
                    Text(renderMode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if renderMode.isExperimental {
                        Text("Experimental")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(model.selectedCategoryModel.color.swiftUIColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(model.selectedCategoryModel.color.swiftUIColor.opacity(0.12), in: Capsule())
                    }
                }
                Text(renderMode.detail)
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

    private func saveDeepSeekKey() {
        let trimmed = deepSeekKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.save(trimmed, account: KeychainStore.deepSeekAPIKeyAccount)
        deepSeekKeySet = KeychainStore.hasValue(account: KeychainStore.deepSeekAPIKeyAccount)
        deepSeekKeyInput = ""
    }

    private func clearDeepSeekKey() {
        KeychainStore.delete(account: KeychainStore.deepSeekAPIKeyAccount)
        deepSeekKeySet = false
        deepSeekKeyInput = ""
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
