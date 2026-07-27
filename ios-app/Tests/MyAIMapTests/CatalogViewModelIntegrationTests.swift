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

    @Test func exportedCatalogIsValidatedAndImportReplacementPreservesThePriorPrimary() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let model = UniverseViewModel(dependencies: makeDependencies(context))
        #expect(model.addCustomTool(name: "Figma", urlString: "https://figma.com", category: .design))
        let exported = try #require(model.catalogExportDocument())
        let exportedCatalog = try CatalogDocument.document(fromTransferData: exported.data)
        #expect(exportedCatalog.tools.map(\.name) == ["Figma"])

        let imported = CatalogDocument(tools: [tool(id: "linear", name: "Linear", category: .design)])
        let prepared = try #require(model.preparedCatalogImport(from: try imported.transferData()))
        #expect(model.replaceCatalogWithImportedDocument(prepared))
        #expect(model.customTools.map(\.name) == ["Linear"])

        let backup = try #require(context.fileSystem.data(at: context.repository.backupURL))
        let backupCatalog = try JSONDecoder().decode(CatalogDocument.self, from: backup)
        #expect(backupCatalog.tools.map(\.name) == ["Figma"])
    }

    @Test func invalidImportDoesNotChangeTheLiveCatalog() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let model = UniverseViewModel(dependencies: makeDependencies(context))
        #expect(model.addCustomTool(name: "Figma", urlString: "https://figma.com", category: .design))

        #expect(model.preparedCatalogImport(from: Data("not JSON".utf8)) == nil)
        #expect(model.customTools.map(\.name) == ["Figma"])
    }

    @Test func oversizedImportIsRejectedBeforeCatalogDecoding() {
        let oversizedPayload = Data(repeating: 0, count: CatalogImportPreparation.maximumBytes + 1)

        guard case .failure(.invalidOrOversizedFile) = CatalogImportPreparation.validatedDocument(from: oversizedPayload) else {
            Issue.record("An oversized import must be rejected before it reaches the catalog decoder.")
            return
        }
    }

    @Test func importRejectsAnOverBudgetUnknownJSONArrayBeforeDecoding() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let model = UniverseViewModel(dependencies: makeDependencies(context))
        let entries = Array(repeating: "\"x\"", count: CatalogDocument.maximumToolCount + 1)
            .joined(separator: ",")
        let payload = Data(
            """
            {"schemaVersion":2,"tools":[],"customCategories":[],"hiddenToolIDs":[],"extensionPayload":[\(entries)]}
            """.utf8
        )

        #expect(model.preparedCatalogImport(from: payload) == nil)
    }

    @Test func importAcceptsAnUnknownJSONArrayAtTheDecodeBudget() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let model = UniverseViewModel(dependencies: makeDependencies(context))
        let entries = Array(repeating: "\"x\"", count: CatalogDocument.maximumToolCount)
            .joined(separator: ",")
        let payload = Data(
            """
            {"schemaVersion":2,"tools":[],"customCategories":[],"hiddenToolIDs":[],"extensionPayload":[\(entries)]}
            """.utf8
        )

        let document = try #require(model.preparedCatalogImport(from: payload))
        #expect(document == CatalogDocument())
    }

    @Test func importRejectsNestedUnknownArraysThatExceedTheTotalDecodeBudget() {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let model = UniverseViewModel(dependencies: makeDependencies(context))
        let entries = Array(repeating: "\"x\"", count: CatalogDocument.maximumToolCount)
            .joined(separator: ",")
        let childArrayCount = CatalogJSONPreflight.maximumTotalArrayElementCount
            / CatalogDocument.maximumToolCount + 1
        let childArrays = Array(repeating: "[\(entries)]", count: childArrayCount)
            .joined(separator: ",")
        let payload = Data(
            """
            {"schemaVersion":2,"tools":[],"customCategories":[],"hiddenToolIDs":[],"extensionPayload":[\(childArrays)]}
            """.utf8
        )

        #expect(model.preparedCatalogImport(from: payload) == nil)
    }

    @Test func boundedImportReaderRejectsAFileBeyondTheByteBudget() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-import-limit-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try Data(repeating: 0, count: CatalogImportPreparation.maximumBytes + 1)
            .write(to: fileURL, options: .atomic)

        #expect(throws: CatalogImportPreparationError.invalidOrOversizedFile) {
            _ = try CatalogImportPreparation.boundedData(from: fileURL)
        }
    }

    @Test func failedConfirmedImportLeavesModelPrimaryAndBackupUntouched() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let model = UniverseViewModel(dependencies: makeDependencies(context))
        #expect(model.addCustomTool(name: "Figma", urlString: "https://figma.com", category: .design))
        let originalPrimary = try #require(context.fileSystem.data(at: context.repository.primaryURL))

        let imported = CatalogDocument(tools: [tool(id: "linear", name: "Linear", category: .design)])
        let candidate = try #require(model.preparedCatalogImport(from: try imported.transferData()))
        context.fileSystem.failNextWrite()

        #expect(!model.replaceCatalogWithImportedDocument(candidate))
        #expect(model.customTools.map(\.name) == ["Figma"])
        #expect(context.fileSystem.data(at: context.repository.primaryURL) == originalPrimary)
        #expect(context.fileSystem.data(at: context.repository.backupURL) == nil)
    }

    @Test func recoveryCopyExportReadsOnlyTheQuarantinedBytes() throws {
        let context = makeContext()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        let corrupt = Data("not JSON".utf8)
        context.fileSystem.seed(corrupt, at: context.repository.primaryURL)
        let model = UniverseViewModel(dependencies: makeDependencies(context))

        let recoveryCopy = try #require(model.recoveryCopyExportDocument())
        #expect(recoveryCopy.data == corrupt)
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

    private func tool(id: String, name: String, category: ToolCategoryId) -> Tool {
        Tool(
            id: id,
            name: name,
            category: category,
            summary: "Import fixture tool",
            stage: .planning,
            orbit: .inner,
            angle: 0,
            url: nil,
            logoDomain: nil,
            relationIds: [],
            classification: nil
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
