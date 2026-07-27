import SwiftUI

/// A terminal, app-level recovery surface. It is intentionally outside map
/// navigation and Settings sheets so corrupt local data cannot be mistaken for
/// a valid empty universe or dismissed behind an interactive map.
struct CatalogRecoverySheet: View {
    let recovery: CatalogRecovery
    let onRestoreBackup: () -> Void
    let onStartEmpty: () -> Void
    let onContinueWithLastSavedCatalog: () -> Void
    let onRecoveryCopyExport: () -> CatalogRecoveryCopyDocument?

    @State private var showStartEmptyConfirmation = false
    @State private var recoveryCopyExportDocument: CatalogRecoveryCopyDocument?
    @State private var showRecoveryCopyExporter = false
    @State private var recoveryCopyExportInProgress = false
    @State private var recoveryCopyExportFailure = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: BrandSpacing.xl.value) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(BrandColor.textSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: BrandSpacing.s.value) {
                    Text("Your universe needs recovery")
                        .font(BrandTypography.title)
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(BrandColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: BrandSpacing.s.value) {
                    if recovery.reason == .catalogCouldNotBeSaved {
                        Button(action: onContinueWithLastSavedCatalog) {
                            Label("Continue with last saved catalog", systemImage: "arrow.uturn.backward")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandColor.cyan)
                        .accessibilityIdentifier("catalogRecovery.continueSaved")
                    }

                    if recovery.backupAvailable {
                        Button(action: onRestoreBackup) {
                            Label("Restore verified backup", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(BrandColor.cyan)
                        .accessibilityIdentifier("catalogRecovery.restoreBackup")
                    }

                    if recovery.recoveryCopyAvailable {
                        Button(action: exportRecoveryCopy) {
                            Label("Export recovery copy", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("catalogRecovery.exportCopy")
                    }

                    Button(role: .destructive) {
                        showStartEmptyConfirmation = true
                    } label: {
                        Label("Start a new empty universe", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(recoveryCopyExportInProgress)
                    .accessibilityIdentifier("catalogRecovery.startEmpty")
                }

                Text("Starting empty replaces the active local catalog. A recovery copy is kept when one could be created.")
                    .font(.footnote)
                    .foregroundStyle(BrandColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(BrandSpacing.xxl.value)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(BrandColor.void.ignoresSafeArea())
            .navigationTitle("Catalog recovery")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .confirmationDialog(
            "Start a new empty universe?",
            isPresented: $showStartEmptyConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start empty universe", role: .destructive, action: onStartEmpty)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the active local catalog. Restore the verified backup instead if you want to keep its contents.")
        }
        .fileExporter(
            isPresented: $showRecoveryCopyExporter,
            document: recoveryCopyExportDocument,
            contentType: CatalogRecoveryCopyDocument.contentType,
            defaultFilename: "my-ai-map-recovery-copy"
        ) { result in
            recoveryCopyExportInProgress = false
            if case .failure = result {
                recoveryCopyExportFailure = true
            }
        }
        .alert("Recovery copy was not exported", isPresented: $recoveryCopyExportFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The active catalog was not changed. Export the recovery copy successfully before starting a new universe.")
        }
    }

    private var message: String {
        switch recovery.reason {
        case .unreadableOrInvalidDocument:
            return "This device has catalog data that cannot be safely loaded. It has not been silently replaced."
        case .migrationCouldNotBeSaved:
            return "Your previous catalog could not be migrated safely. Your original data is still preserved."
        case .migrationInterrupted:
            return "A previous catalog migration was interrupted. No local data has been silently cleared."
        case .legacyChangedAfterMigration:
            return "A different app version changed your previous catalog after migration. Both versions have been preserved for recovery."
        case .storageUnavailable:
            return "Secure local app storage is unavailable on this device right now."
        case .catalogCouldNotBeSaved:
            return "The latest catalog change could not be saved safely."
        }
    }

    private func exportRecoveryCopy() {
        guard let document = onRecoveryCopyExport() else { return }
        recoveryCopyExportDocument = document
        recoveryCopyExportInProgress = true
        showRecoveryCopyExporter = true
    }
}
