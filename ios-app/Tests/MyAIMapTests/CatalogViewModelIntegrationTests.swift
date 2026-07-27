import Foundation
import Testing
@testable import MyAIMap

@Suite("UniverseViewModel catalog composition")
@MainActor
struct CatalogViewModelIntegrationTests {

    @Test func productionStyleDependenciesPersistCatalogBeforeUpdatingTheModel() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let first = UniverseViewModel(dependencies: makeDependencies(context))

        #expect(first.addCustomTool(name: "Figma", urlString: "https://figma.com", category: .design))
        #expect(first.customTools.map(\.name) == ["Figma"])

        let reloaded = UniverseViewModel(dependencies: makeDependencies(context))
        #expect(reloaded.catalogRecovery == nil)
        #expect(reloaded.customTools.map(\.name) == ["Figma"])
    }

    @Test func failedCatalogSaveDoesNotMutateTheVisibleUniverse() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let model = UniverseViewModel(dependencies: makeDependencies(context))
        context.fileSystem.failNextWrite()

        #expect(!model.addCustomTool(name: "Figma", urlString: "https://figma.com", category: .design))
        #expect(model.customTools.isEmpty)
        #expect(model.catalogRecovery?.reason == .catalogCouldNotBeSaved)
        #expect(!context.repository.hasPrimaryDocument())
    }

    @Test func writeFailureCanContinueWithTheLastVerifiedPrimary() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let model = UniverseViewModel(dependencies: makeDependencies(context))
        #expect(model.addCustomTool(name: "Figma", urlString: "https://figma.com", category: .design))
        context.fileSystem.failNextWrite()

        #expect(!model.addCustomTool(name: "Linear", urlString: "https://linear.app", category: .design))
        #expect(model.catalogRecovery?.reason == .catalogCouldNotBeSaved)
        #expect(model.continueWithLastSavedCatalogAfterWriteFailure())
        #expect(model.catalogRecovery == nil)
        #expect(model.customTools.map(\.name) == ["Figma"])
    }

    @Test func recoveryBlocksCatalogIntentsUntilThePersonExplicitlyStartsEmpty() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        context.fileSystem.seed(Data("not JSON".utf8), at: context.repository.primaryURL)
        let model = UniverseViewModel(dependencies: makeDependencies(context))

        #expect(model.catalogRecovery?.reason == .unreadableOrInvalidDocument)
        #expect(!model.loadSampleUniverse())
        #expect(model.customTools.isEmpty)
        #expect(context.fileSystem.data(at: context.repository.primaryURL) == Data("not JSON".utf8))

        #expect(model.startNewUniverseAfterCatalogRecovery())
        #expect(model.catalogRecovery == nil)
        guard case .catalog(let document) = context.repository.load() else {
            Issue.record("Explicit recovery reset must create a valid empty primary.")
            return
        }
        #expect(document == CatalogDocument())
    }

    @Test func explicitRecoveryResetClearsOnlyThePendingMarkerBeforeTheNextColdLaunch() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        context.defaults.set(
            Data(repeating: 0, count: 32),
            forKey: UserDefaultsCatalogMigrationMarkerStore.pendingV1CleanupKey
        )
        let first = UniverseViewModel(dependencies: makeDependencies(context))

        #expect(first.catalogRecovery?.reason == .migrationInterrupted)
        #expect(first.startNewUniverseAfterCatalogRecovery())
        #expect(!UserDefaultsCatalogMigrationMarkerStore(defaults: context.defaults).hasPendingV1Cleanup())

        let second = UniverseViewModel(dependencies: makeDependencies(context))
        #expect(second.catalogRecovery == nil)
        #expect(second.customTools.isEmpty)
    }

    private func makeContext() -> IntegrationContext {
        let suiteName = "catalog-view-model-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let fileSystem = MemoryCatalogFileSystem()
        let directory = URL(fileURLWithPath: "/catalog-view-model-test/\(UUID().uuidString)", isDirectory: true)
        return IntegrationContext(
            suiteName: suiteName,
            defaults: defaults,
            fileSystem: fileSystem,
            directory: directory,
            repository: LocalCatalogRepository(directory: directory, fileSystem: fileSystem)
        )
    }

    private func makeDependencies(_ context: IntegrationContext) -> CatalogRuntimeDependencies {
        let repository = LocalCatalogRepository(directory: context.directory, fileSystem: context.fileSystem)
        let markerStore = UserDefaultsCatalogMigrationMarkerStore(defaults: context.defaults)
        return CatalogRuntimeDependencies(
            repository: repository,
            preferences: UserDefaultsPreferences(defaults: context.defaults),
            migrationCoordinator: CatalogMigrationCoordinator(
                repository: repository,
                legacy: LegacyCatalogV1(defaults: context.defaults),
                markerStore: markerStore
            )
        )
    }
}

@MainActor
private struct IntegrationContext {
    let suiteName: String
    let defaults: UserDefaults
    let fileSystem: MemoryCatalogFileSystem
    let directory: URL
    let repository: LocalCatalogRepository
}
