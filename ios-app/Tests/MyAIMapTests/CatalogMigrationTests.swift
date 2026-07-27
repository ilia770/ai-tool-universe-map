import Foundation
import Testing
@testable import MyAIMap

@Suite("Catalog v1 migration and preferences")
@MainActor
struct CatalogMigrationTests {

    @Test func validV1MigratesThenCleansOnlyCatalogKeysOnTheNextInitialization() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let document = legacyDocument()
        let originalBytes = try seedLegacy(document, in: context.defaults)
        let preferences = UserDefaultsPreferences(defaults: context.defaults)
        let preferenceSnapshot = UserDefaultsPreferences.Snapshot(
            hapticsEnabled: false,
            hasSeenOnboarding: true,
            subscription: SubscriptionState(plan: .pro, aiRequestsUsed: 3, aiRequestsLimit: 40)
        )
        preferences.save(preferenceSnapshot)

        let first = CatalogMigrationCoordinator(
            repository: context.repository,
            legacy: LegacyCatalogV1(defaults: context.defaults),
            markerStore: context.markerStore
        )
        guard case .catalog(let firstDocument) = first.prepareCatalog() else {
            Issue.record("A valid v1 catalog must migrate into v2.")
            return
        }
        #expect(firstDocument == document)
        #expect(context.repository.hasPrimaryDocument())
        #expect(context.markerStore.hasPendingV1Cleanup())
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.data(forKey: key) == originalBytes[key])
        }

        let reloadedRepository = LocalCatalogRepository(
            directory: context.directory,
            fileSystem: context.fileSystem
        )
        let second = CatalogMigrationCoordinator(
            repository: reloadedRepository,
            legacy: LegacyCatalogV1(defaults: context.defaults),
            markerStore: context.markerStore
        )
        guard case .catalog(let secondDocument) = second.prepareCatalog() else {
            Issue.record("A valid v2 primary must reload on the next initialization.")
            return
        }
        #expect(secondDocument == document)
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.object(forKey: key) == nil)
        }
        #expect(!context.markerStore.hasPendingV1Cleanup())
        #expect(preferences.load() == preferenceSnapshot)
    }

    @Test func freshInstallWithNoV1DoesNotCreateAV2FileOrMigrationMarker() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let coordinator = CatalogMigrationCoordinator(
            repository: context.repository,
            legacy: LegacyCatalogV1(defaults: context.defaults),
            markerStore: context.markerStore
        )

        guard case .catalog(let document) = coordinator.prepareCatalog() else {
            Issue.record("A true fresh install must start with an in-memory empty catalog.")
            return
        }
        #expect(document == CatalogDocument())
        #expect(!context.repository.hasPrimaryDocument())
        #expect(!context.markerStore.hasPendingV1Cleanup())
    }

    @Test func partialV1ReturnsRecoveryAndPreservesItsOnlyWrittenKey() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let data = try JSONEncoder().encode([tool(id: "partial", category: .design)])
        context.defaults.set(data, forKey: LegacyCatalogV1.Key.tools)

        let result = makeCoordinator(context).prepareCatalog()

        expectLegacyRecovery(result, reason: .unreadableOrInvalidDocument)
        #expect(!context.repository.hasPrimaryDocument())
        #expect(!context.markerStore.hasPendingV1Cleanup())
        #expect(context.defaults.data(forKey: LegacyCatalogV1.Key.tools) == data)
        #expect(context.defaults.object(forKey: LegacyCatalogV1.Key.categories) == nil)
        #expect(context.defaults.object(forKey: LegacyCatalogV1.Key.hiddenToolIDs) == nil)
    }

    @Test func duplicateLegacyHiddenIDsReturnRecoveryInsteadOfBeingSilentlyRepaired() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let document = legacyDocument()
        _ = try seedLegacy(document, in: context.defaults)
        let duplicateHidden = try JSONEncoder().encode(["hidden", "hidden"])
        context.defaults.set(duplicateHidden, forKey: LegacyCatalogV1.Key.hiddenToolIDs)

        let result = makeCoordinator(context).prepareCatalog()

        expectLegacyRecovery(result, reason: .unreadableOrInvalidDocument)
        #expect(!context.repository.hasPrimaryDocument())
        #expect(context.defaults.data(forKey: LegacyCatalogV1.Key.hiddenToolIDs) == duplicateHidden)
    }

    @Test func failedMigrationSaveKeepsV1AndDoesNotSetTheCleanupMarker() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let originalBytes = try seedLegacy(legacyDocument(), in: context.defaults)
        context.fileSystem.failNextWrite()

        let result = makeCoordinator(context).prepareCatalog()

        expectLegacyRecovery(result, reason: .migrationCouldNotBeSaved)
        #expect(!context.repository.hasPrimaryDocument())
        #expect(!context.markerStore.hasPendingV1Cleanup())
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.data(forKey: key) == originalBytes[key])
        }
    }

    @Test func invalidExistingV2PreventsLegacyFallbackAndCleanup() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let originalBytes = try seedLegacy(legacyDocument(), in: context.defaults)
        context.fileSystem.seed(Data("not JSON".utf8), at: context.repository.primaryURL)
        context.defaults.set(
            Data(repeating: 0, count: 32),
            forKey: UserDefaultsCatalogMigrationMarkerStore.pendingV1CleanupKey
        )

        let result = makeCoordinator(context).prepareCatalog()

        guard case .recovery(let recovery) = result else {
            Issue.record("An invalid v2 primary must be recovered directly, not replaced from v1.")
            return
        }
        #expect(recovery.source == .primaryDocument)
        #expect(recovery.reason == .unreadableOrInvalidDocument)
        #expect(context.markerStore.hasPendingV1Cleanup())
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.data(forKey: key) == originalBytes[key])
        }
    }

    @Test func existingValidEmptyV2RemainsCanonicalWithoutDeletingV1() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        try context.repository.save(CatalogDocument())
        let originalBytes = try seedLegacy(legacyDocument(), in: context.defaults)

        let result = makeCoordinator(context).prepareCatalog()

        guard case .catalog(let document) = result else {
            Issue.record("An existing valid v2 document must remain canonical.")
            return
        }
        #expect(document == CatalogDocument())
        #expect(!context.markerStore.hasPendingV1Cleanup())
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.data(forKey: key) == originalBytes[key])
        }
    }

    @Test func validV2WithoutPendingMarkerKeepsLegacyKeysAfterAnInterruptedMarkerWrite() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let document = legacyDocument()
        try context.repository.save(document)
        let originalBytes = try seedLegacy(document, in: context.defaults)

        let result = makeCoordinator(context).prepareCatalog()

        guard case .catalog(let loaded) = result else {
            Issue.record("The already-written v2 document must be usable after marker interruption.")
            return
        }
        #expect(loaded == document)
        #expect(!context.markerStore.hasPendingV1Cleanup())
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.data(forKey: key) == originalBytes[key])
        }
    }

    @Test func pendingMarkerWithoutV2OrV1ReturnsRecoveryRatherThanFreshEmpty() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        context.defaults.set(
            Data(repeating: 0, count: 32),
            forKey: UserDefaultsCatalogMigrationMarkerStore.pendingV1CleanupKey
        )

        let result = makeCoordinator(context).prepareCatalog()

        expectLegacyRecovery(result, reason: .migrationInterrupted)
        #expect(!context.repository.hasPrimaryDocument())
        #expect(context.markerStore.hasPendingV1Cleanup())
    }

    @Test func semanticallyInvalidV1ReturnsRecoveryWithoutCleaningItsKeys() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let invalidDocument = CatalogDocument(
            tools: [tool(id: UniverseIdentity.centralCoreToolID, category: .core)],
            hiddenToolIDs: [UniverseIdentity.centralCoreToolID]
        )
        let originalBytes = try seedLegacy(invalidDocument, in: context.defaults)

        let result = makeCoordinator(context).prepareCatalog()

        expectLegacyRecovery(result, reason: .unreadableOrInvalidDocument)
        #expect(!context.repository.hasPrimaryDocument())
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.data(forKey: key) == originalBytes[key])
        }
    }

    @Test func legacyDataChangedByAnOlderBuildAfterMigrationIsNeverCleaned() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let migratedDocument = legacyDocument()
        _ = try seedLegacy(migratedDocument, in: context.defaults)
        let first = makeCoordinator(context)

        guard case .catalog(let firstDocument) = first.prepareCatalog() else {
            Issue.record("The original v1 snapshot must migrate before version-skew is tested.")
            return
        }
        #expect(firstDocument == migratedDocument)
        let rewrittenV1 = CatalogDocument(tools: [tool(id: "written-by-old-build", category: .analytics)])
        let rewrittenBytes = try seedLegacy(rewrittenV1, in: context.defaults)
        let reloadedRepository = LocalCatalogRepository(
            directory: context.directory,
            fileSystem: context.fileSystem
        )
        let second = CatalogMigrationCoordinator(
            repository: reloadedRepository,
            legacy: LegacyCatalogV1(defaults: context.defaults),
            markerStore: context.markerStore
        )

        let result = second.prepareCatalog()

        expectLegacyRecovery(result, reason: .legacyChangedAfterMigration)
        #expect(context.markerStore.hasPendingV1Cleanup())
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.data(forKey: key) == rewrittenBytes[key])
        }
        guard case .catalog(let storedV2) = reloadedRepository.load() else {
            Issue.record("Version-skew recovery must not damage the already valid v2 primary.")
            return
        }
        #expect(storedV2 == migratedDocument)
    }

    @Test func preferencesKeepTheirEstablishedDefaultsAndRoundTripIndependently() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let preferences = UserDefaultsPreferences(defaults: context.defaults)
        #expect(preferences.load() == UserDefaultsPreferences.Snapshot(
            hapticsEnabled: true,
            hasSeenOnboarding: false,
            subscription: .free
        ))

        let expected = UserDefaultsPreferences.Snapshot(
            hapticsEnabled: false,
            hasSeenOnboarding: true,
            subscription: SubscriptionState(plan: .pro, aiRequestsUsed: 4, aiRequestsLimit: 12)
        )
        preferences.save(expected)

        #expect(preferences.load() == expected)
        for key in LegacyCatalogV1.catalogKeys {
            #expect(context.defaults.object(forKey: key) == nil)
        }
    }

    private func makeContext() -> MigrationContext {
        let suiteName = "catalog-migration-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let fileSystem = MemoryCatalogFileSystem()
        let directory = URL(fileURLWithPath: "/catalog-migration-test/\(UUID().uuidString)", isDirectory: true)
        let repository = LocalCatalogRepository(
            directory: directory,
            fileSystem: fileSystem
        )
        return MigrationContext(
            suiteName: suiteName,
            defaults: defaults,
            fileSystem: fileSystem,
            directory: directory,
            repository: repository,
            markerStore: UserDefaultsCatalogMigrationMarkerStore(defaults: defaults)
        )
    }

    private func makeCoordinator(_ context: MigrationContext) -> CatalogMigrationCoordinator {
        CatalogMigrationCoordinator(
            repository: context.repository,
            legacy: LegacyCatalogV1(defaults: context.defaults),
            markerStore: context.markerStore
        )
    }

    private func seedLegacy(_ document: CatalogDocument, in defaults: UserDefaults) throws -> [String: Data] {
        let encoder = JSONEncoder()
        let values = [
            LegacyCatalogV1.Key.tools: try encoder.encode(document.tools),
            LegacyCatalogV1.Key.categories: try encoder.encode(document.customCategories),
            LegacyCatalogV1.Key.hiddenToolIDs: try encoder.encode(document.hiddenToolIDs.sorted()),
        ]
        for (key, value) in values {
            defaults.set(value, forKey: key)
        }
        return values
    }

    private func expectLegacyRecovery(_ result: CatalogLoadResult, reason: CatalogRecoveryReason) {
        guard case .recovery(let recovery) = result else {
            Issue.record("The unsafe legacy state must be surfaced as recovery.")
            return
        }
        #expect(recovery.source == .legacyDefaults)
        #expect(recovery.reason == reason)
        #expect(!recovery.backupAvailable)
        #expect(!recovery.recoveryCopyAvailable)
    }

    private func legacyDocument() -> CatalogDocument {
        let customCategoryID = ToolCategoryId("ops")
        return CatalogDocument(
            tools: [
                tool(id: "ops-tool", category: customCategoryID),
                tool(id: "hidden", category: .design),
            ],
            customCategories: [category(id: customCategoryID)],
            hiddenToolIDs: ["hidden"]
        )
    }

    private func tool(id: String, category: ToolCategoryId) -> Tool {
        Tool(
            id: id,
            name: id,
            category: category,
            summary: "Migration fixture tool",
            stage: .planning,
            orbit: .inner,
            angle: 0,
            url: nil,
            logoDomain: nil,
            relationIds: [],
            classification: nil
        )
    }

    private func category(id: ToolCategoryId) -> ToolCategory {
        ToolCategory(
            id: id,
            name: "Operations",
            shortName: "Ops",
            description: "Migration fixture category",
            color: "#112233",
            glow: "#445566",
            angle: 0
        )
    }
}

@MainActor
private struct MigrationContext {
    let suiteName: String
    let defaults: UserDefaults
    let fileSystem: MemoryCatalogFileSystem
    let directory: URL
    let repository: LocalCatalogRepository
    let markerStore: UserDefaultsCatalogMigrationMarkerStore
}
