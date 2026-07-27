import SwiftUI
import UniformTypeIdentifiers

struct AccountSettingsSheet: View {
    @Environment(UniverseViewModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var section: AccountSection = .settings
    @State private var showResetConfirm = false
    @State private var showUpgradePlaceholder = false
    @State private var catalogExportDocument: CatalogFileDocument?
    @State private var showCatalogExporter = false
    @State private var showCatalogImporter = false
    @State private var pendingCatalogImport: CatalogDocument?
    @State private var showCatalogImportConfirmation = false
    @State private var catalogTransferMessage: String?
    #if DEBUG
    @State private var deepSeekKeyInput = ""
    @State private var deepSeekKeySet = KeychainStore.hasValue(account: KeychainStore.deepSeekAPIKeyAccount)
    #endif
    @Namespace private var sheetChromeNamespace

    /// Bridges the `AccountSection` enum to the cluster's `Binding<Int>`.
    private var sectionBinding: Binding<Int> {
        Binding(
            get: { AccountSection.allCases.firstIndex(of: section) ?? 0 },
            set: {
                guard $0 < AccountSection.allCases.count else { return }
                section = AccountSection.allCases[$0]
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BrandSpacing.section.value) {
                    accountHeader

                    GlassMorphCluster(
                        options: AccountSection.allCases,
                        selection: sectionBinding,
                        base: "account.section",
                        tint: model.selectedCategoryModel.color.swiftUIColor
                    ) { section, _ in
                        Text(section.title)
                    }

                    // Keyed container with the section swap animation suppressed, so
                    // Settings↔History replaces in ONE frame with no crossfade. A
                    // `.transition(removal: .identity)` does NOT remove instantly — it
                    // holds the outgoing panel at full opacity for the whole animation
                    // duration while the new one fades in, which reproduces the
                    // text-on-text overlap (B1). `.animation(.none, value: section)`
                    // guarantees no overlap.
                    Group {
                        switch section {
                        case .settings:
                            settingsContent
                        case .history:
                            historyContent
                        }
                    }
                    .id(section)
                    .animation(.none, value: section)
                }
                .padding(BrandSpacing.xxl.value)
            }
            .scrollIndicators(.hidden)
            // Translucent dark glass tint over the frosted presentation backdrop
            // (set below) so the universe shows through with a light back-blur
            // instead of a flat opaque void fill.
            .background(BrandColor.glass.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(BrandTypography.controlLabel)
                            .foregroundStyle(.white.opacity(0.86))
                            .frame(width: 34, height: 34)
                            .glassSurface(in: Circle(), tint: .white.opacity(0.08), interactive: true)
                            .navigationGlassMorphID("AccountSheet.close", in: sheetChromeNamespace)
                    }
                    .buttonStyle(BouncyIconButtonStyle())
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationBackground(.ultraThinMaterial)
        .fileExporter(
            isPresented: $showCatalogExporter,
            document: catalogExportDocument,
            contentType: CatalogFileDocument.catalogContentType,
            defaultFilename: "my-ai-map-catalog-v2"
        ) { result in
            if case .failure = result {
                catalogTransferMessage = "The catalog could not be exported. Your local universe was not changed."
            }
        }
        .fileImporter(
            isPresented: $showCatalogImporter,
            allowedContentTypes: [CatalogFileDocument.catalogContentType]
        ) { result in
            handleCatalogImport(result)
        }
        .confirmationDialog(
            "Replace current universe?",
            isPresented: $showCatalogImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace universe", role: .destructive, action: replaceWithPendingCatalogImport)
            Button("Cancel", role: .cancel) { pendingCatalogImport = nil }
        } message: {
            Text("The imported catalog will replace the active local universe. A verified backup of the current catalog is kept first.")
        }
        .alert(
            "Catalog transfer",
            isPresented: Binding(
                get: { catalogTransferMessage != nil },
                set: { if !$0 { catalogTransferMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(catalogTransferMessage ?? "")
        }
    }

    private var accountHeader: some View {
        HStack(spacing: BrandSpacing.m.value) {
            UserAvatarImage(size: 58, tint: model.selectedCategoryModel.color.swiftUIColor)

            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                Text("AI Universe")
                    .font(BrandTypography.title)
                    .foregroundStyle(.white)
                Text(Pluralize.count(model.visibleAllTools.count, "active tool"))
                    .font(.subheadline)
                    .foregroundStyle(BrandColor.textSecondary)
            }
            Spacer()
        }
    }

    private var settingsContent: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: BrandSpacing.l.value) {
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

                    Text("Follows your device language. Manual selection coming soon.")
                        .font(.footnote)
                        .foregroundStyle(BrandColor.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            planGroup

            settingsGroup(title: "Behavior", systemImage: "hand.tap.fill") {
                Toggle("Haptics", isOn: $model.hapticsEnabled)
                    .tint(model.selectedCategoryModel.color.swiftUIColor)
                Text("Subtle taps for selections and feedback. Turn off to silence them.")
                    .font(.footnote)
                    .foregroundStyle(BrandColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            dataPrivacyGroup

            #if DEBUG
            // Developer-only: the DeepSeek API-key entry. Gated behind DEBUG and
            // the hidden `developer.modeEnabled` flag so it never appears in a
            // release build or for a normal user (SETTINGS_PROFILE_SPEC §1).
            if DeveloperMode.isEnabled {
                deepSeekDeveloperGroup
            }
            #endif

            settingsGroup(title: "Universe", systemImage: "globe.americas.fill") {
                VStack(spacing: BrandSpacing.s.value) {
                    Button(action: beginCatalogExport) {
                        universeActionRow("Export universe", systemImage: "square.and.arrow.up", destructive: false)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))

                    Button {
                        showCatalogImporter = true
                    } label: {
                        universeActionRow("Import universe", systemImage: "square.and.arrow.down", destructive: false)
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))

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
                Text("Removes every tool and branch from the active universe. A verified backup is kept for recovery.")
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
                                        .font(BrandTypography.controlLabel)
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

    // PLACEHOLDER plan / usage group — no real billing, no StoreKit, no network
    // (SETTINGS_PROFILE_SPEC §2). Shows plan, usage cap, remaining requests, and
    // a non-functional Upgrade CTA.
    private var planGroup: some View {
        settingsGroup(title: "Plan", systemImage: "creditcard.fill") {
            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                planRow(label: "Plan", value: model.subscription.plan.displayName)
                planRow(label: "Usage limit", value: "\(model.subscription.aiRequestsLimit) AI requests / month")
                planRow(label: "Remaining AI requests", value: "\(model.subscription.aiRequestsRemaining)")

                Button {
                    showUpgradePlaceholder = true
                } label: {
                    HStack {
                        Label("Upgrade", systemImage: "sparkles")
                            .font(BrandTypography.controlLabel)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(BrandSpacing.m.value)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BrandColor.card, in: RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: BrandRadius.nested.value, style: .continuous)
                            .stroke(BrandColor.stroke, lineWidth: 1)
                    }
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))
                .accessibilityIdentifier("settings.plan.upgrade")
            }
        }
        .confirmationDialog("Upgrade", isPresented: $showUpgradePlaceholder, titleVisibility: .visible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Paid plans are coming soon. There's nothing to buy yet.")
        }
    }

    /// Plain-language local-data disclosure. This is deliberately an in-app
    /// explanation rather than a substitute for the public Privacy Policy URL
    /// required in App Store Connect before submission.
    private var dataPrivacyGroup: some View {
        settingsGroup(title: "Data & Privacy", systemImage: "hand.raised.fill") {
            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                Text("Your universe stays on this device.")
                    .font(BrandTypography.controlLabel)
                    .foregroundStyle(.white)

                Text("This release has no account, analytics, tracking, or cloud sync. The assistant runs locally; no catalog or prompt is sent to an AI provider.")
                    .font(.footnote)
                    .foregroundStyle(BrandColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Use Export universe to keep a copy. Reset universe keeps one verified local backup for recovery. Deleting My AI Map removes its current data from this device. If you use iCloud or computer backups, remove My AI Map data there too; delete exported copies from the location where you saved them.")
                    .font(.footnote)
                    .foregroundStyle(BrandColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.dataPrivacy")
        }
    }

    private func planRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(BrandColor.textSecondary)
            Spacer()
            Text(value)
                .font(BrandTypography.controlLabel)
                .foregroundStyle(.white)
        }
    }

    private func beginCatalogExport() {
        guard let document = model.catalogExportDocument() else {
            catalogTransferMessage = "The catalog could not be exported safely. Your local universe was not changed."
            return
        }
        catalogExportDocument = document
        showCatalogExporter = true
    }

    private func handleCatalogImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            catalogTransferMessage = "The selected file could not be opened. Your local universe was not changed."
            return
        }

        Task { @MainActor in
            let preparation = await Task.detached(priority: .userInitiated) {
                CatalogImportPreparation.prepare(from: url)
            }.value
            guard case .success(let document) = preparation,
                  model.catalogRecovery == nil else {
                catalogTransferMessage = "This file is not a valid My AI Map catalog, or it is too large. Your local universe was not changed."
                return
            }
            pendingCatalogImport = document
            showCatalogImportConfirmation = true
        }
    }

    private func replaceWithPendingCatalogImport() {
        guard let document = pendingCatalogImport else { return }
        pendingCatalogImport = nil
        guard model.replaceCatalogWithImportedDocument(document) else {
            catalogTransferMessage = "The imported catalog could not replace your universe. Your current catalog was not changed."
            return
        }
    }

    #if DEBUG
    private var deepSeekDeveloperGroup: some View {
        @Bindable var model = model
        return settingsGroup(title: "AI assistant (developer)", systemImage: "wrench.and.screwdriver.fill") {
            VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                HStack(spacing: BrandSpacing.s.value) {
                    Image(systemName: deepSeekKeySet ? "checkmark.seal.fill" : "key.slash")
                        .foregroundStyle(deepSeekKeySet ? model.selectedCategoryModel.color.swiftUIColor : BrandColor.textMuted)
                    Text(deepSeekKeySet ? "DeepSeek key set" : "DeepSeek key not set")
                        .font(BrandTypography.controlLabel)
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

                Text("Developer-only. The DeepSeek key routes the assistant through DeepSeek; on any error it falls back to the on-device assistant. Hidden from normal users.")
                    .font(.footnote)
                    .foregroundStyle(BrandColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    #endif

    private var historyContent: some View {
        settingsGroup(title: "Recent activity", systemImage: "clock.arrow.circlepath") {
            if model.activityHistory.isEmpty {
                VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                    Text("No activity yet")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Your tool and assistant actions will appear here.")
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
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.97, haptic: nil))
                        .disabled(activity.toolID == nil)
                    }
                }
            }
        }
    }

    private func universeActionRow(_ title: String, systemImage: String, destructive: Bool) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(BrandTypography.controlLabel)
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
                .brandEyebrow()
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

    private func activityRow(_ activity: UniverseActivity) -> some View {
        HStack(spacing: BrandSpacing.m.value) {
            Image(systemName: icon(for: activity.kind))
                .font(BrandTypography.controlLabel)
                .frame(width: 28, height: 28)
                .foregroundStyle(model.selectedCategoryModel.color.swiftUIColor)
                .background(BrandColor.muted, in: Circle())

            VStack(alignment: .leading, spacing: BrandSpacing.xs.value) {
                Text(activity.title)
                    .font(BrandTypography.controlLabel)
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

    #if DEBUG
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
    #endif

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
