import Foundation

@MainActor
protocol CatalogMigrationMarkerStore: AnyObject {
    func hasPendingV1Cleanup() -> Bool
    func pendingV1CleanupFingerprint() -> Data?
    func markPendingV1Cleanup(fingerprint: Data)
    func removeLegacyCatalogValues()
    func clearPendingV1Cleanup()
}

/// A tiny migration-only preference. It is intentionally separate from the
/// catalog payload and from normal user preferences, so it can never be
/// imported, exported, or reset along with user content.
@MainActor
final class UserDefaultsCatalogMigrationMarkerStore: CatalogMigrationMarkerStore {
    static let pendingV1CleanupKey = "catalog.pendingV1Cleanup.v2"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasPendingV1Cleanup() -> Bool {
        defaults.object(forKey: Self.pendingV1CleanupKey) != nil
    }

    func pendingV1CleanupFingerprint() -> Data? {
        defaults.data(forKey: Self.pendingV1CleanupKey)
    }

    func markPendingV1Cleanup(fingerprint: Data) {
        defaults.set(fingerprint, forKey: Self.pendingV1CleanupKey)
    }

    /// This is the sole deletion operation in the migration state machine.
    /// It intentionally removes only catalog payload keys, never preferences.
    func removeLegacyCatalogValues() {
        LegacyCatalogV1.catalogKeys.forEach(defaults.removeObject(forKey:))
    }

    func clearPendingV1Cleanup() {
        defaults.removeObject(forKey: Self.pendingV1CleanupKey)
    }
}

/// Coordinates v1-to-v2 migration without becoming a second catalog writer.
///
/// A marker sampled at initialization distinguishes the first successful
/// migration from the next cold app composition. The legacy keys are removed
/// only in that later composition after the v2 primary validates again.
@MainActor
final class CatalogMigrationCoordinator {
    private let repository: any CatalogRepository
    private let legacy: LegacyCatalogV1
    private let markerStore: any CatalogMigrationMarkerStore
    private let cleanupWasPendingAtInitialization: Bool

    init(
        repository: any CatalogRepository,
        legacy: LegacyCatalogV1,
        markerStore: any CatalogMigrationMarkerStore
    ) {
        self.repository = repository
        self.legacy = legacy
        self.markerStore = markerStore
        self.cleanupWasPendingAtInitialization = markerStore.hasPendingV1Cleanup()
    }

    /// Returns the only catalog state a future app composition may consume.
    /// This method never overwrites an existing primary, never retries through
    /// recovery, and leaves v1 keys intact on any invalid or failed path.
    func prepareCatalog() -> CatalogLoadResult {
        if repository.hasPrimaryDocument() {
            let result = repository.load()
            if cleanupWasPendingAtInitialization, case .catalog = result {
                guard let expectedFingerprint = markerStore.pendingV1CleanupFingerprint(),
                      legacy.currentFingerprint == expectedFingerprint else {
                    return .recovery(
                        CatalogRecovery(
                            source: .legacyDefaults,
                            reason: .legacyChangedAfterMigration,
                            backupAvailable: false,
                            recoveryCopyAvailable: false
                        )
                    )
                }
                markerStore.removeLegacyCatalogValues()
                markerStore.clearPendingV1Cleanup()
            }
            return result
        }

        switch legacy.loadDocument() {
        case .absent:
            guard !markerStore.hasPendingV1Cleanup() else {
                return .recovery(
                    CatalogRecovery(
                        source: .legacyDefaults,
                        reason: .migrationInterrupted,
                        backupAvailable: false,
                        recoveryCopyAvailable: false
                    )
                )
            }
            return .catalog(CatalogDocument())
        case .invalid:
            return .recovery(
                CatalogRecovery(
                    source: .legacyDefaults,
                    reason: .unreadableOrInvalidDocument,
                    backupAvailable: false,
                    recoveryCopyAvailable: false
                )
            )
        case .document(let document, let fingerprint):
            do {
                try repository.save(document)
                markerStore.markPendingV1Cleanup(fingerprint: fingerprint)
                return .catalog(document)
            } catch {
                return .recovery(
                    CatalogRecovery(
                        source: .legacyDefaults,
                        reason: .migrationCouldNotBeSaved,
                        backupAvailable: false,
                        recoveryCopyAvailable: false
                    )
                )
            }
        }
    }
}
