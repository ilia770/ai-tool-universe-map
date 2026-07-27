import Foundation
import Testing
@testable import MyAIMap

@Suite("CatalogDocument and LocalCatalogRepository")
@MainActor
struct CatalogRepositoryTests {

    @Test func newRepositoryLoadsAnEmptyValidDocument() {
        let repository = makeRepository()

        guard case .catalog(let document) = repository.load() else {
            Issue.record("A missing document must be a valid empty catalog, not recovery.")
            return
        }

        #expect(document.schemaVersion == CatalogDocument.currentSchemaVersion)
        #expect(document.tools.isEmpty)
        #expect(document.customCategories.isEmpty)
        #expect(document.hiddenToolIDs.isEmpty)
    }

    @Test func validationRejectsAHiddenToolThatIsNotInTheDocument() {
        let document = CatalogDocument(hiddenToolIDs: ["missing-tool"])

        #expect(throws: CatalogValidationError.hiddenToolIsMissing) {
            try document.validate()
        }
    }

    @Test func validationRejectsAnUnsupportedSchemaVersion() {
        let document = CatalogDocument(schemaVersion: 999)

        #expect(throws: CatalogValidationError.unsupportedSchemaVersion(999)) {
            try document.validate()
        }
    }

    @Test func validationRejectsAnEmptyToolIdentifier() {
        let document = CatalogDocument(tools: [tool(id: " ", category: .design)])

        #expect(throws: CatalogValidationError.emptyToolIdentifier) {
            try document.validate()
        }
    }

    @Test func validationRejectsDuplicateToolIdentifiers() {
        let document = CatalogDocument(
            tools: [
                tool(id: "duplicate", category: .design),
                tool(id: "duplicate", category: .analytics),
            ]
        )

        #expect(throws: CatalogValidationError.duplicateToolIdentifier) {
            try document.validate()
        }
    }

    @Test func validationRejectsBuiltinCustomCategoryCollision() {
        let document = CatalogDocument(customCategories: [category(id: .design)])

        #expect(throws: CatalogValidationError.customCategoryConflictsWithBuiltin) {
            try document.validate()
        }
    }

    @Test func validationRejectsAnEmptyCustomCategoryIdentifier() {
        let document = CatalogDocument(customCategories: [category(id: ToolCategoryId(" "))])

        #expect(throws: CatalogValidationError.emptyCategoryIdentifier) {
            try document.validate()
        }
    }

    @Test func validationRejectsDuplicateCustomCategoryIdentifiers() {
        let customID = ToolCategoryId("ops")
        let document = CatalogDocument(customCategories: [category(id: customID), category(id: customID)])

        #expect(throws: CatalogValidationError.duplicateCategoryIdentifier) {
            try document.validate()
        }
    }

    @Test func validationRejectsTheProtectedCoreToolBeingHidden() {
        let document = CatalogDocument(
            tools: [tool(id: UniverseIdentity.centralCoreToolID, category: .core)],
            hiddenToolIDs: [UniverseIdentity.centralCoreToolID]
        )

        #expect(throws: CatalogValidationError.hiddenCoreTool) {
            try document.validate()
        }
    }

    @Test func validationRejectsAToolWithAnUnknownCategory() {
        let document = CatalogDocument(tools: [tool(id: "orphan", category: ToolCategoryId("unknown"))])

        #expect(throws: CatalogValidationError.toolReferencesUnknownCategory) {
            try document.validate()
        }
    }

    @Test func validationRejectsRelationToAMissingTool() {
        let document = CatalogDocument(tools: [tool(id: "a", category: .design, relations: ["missing"])])

        #expect(throws: CatalogValidationError.relationReferencesMissingTool) {
            try document.validate()
        }
    }

    @Test func validationRejectsAURLThatIsNotHTTPS() {
        let document = CatalogDocument(tools: [tool(id: "http", category: .design, url: URL(string: "http://example.com"))])

        #expect(throws: CatalogValidationError.toolURLIsNotHTTPS) {
            try document.validate()
        }
    }

    @Test func validationRejectsCatalogsBeyondTheInteractiveToolBudget() {
        let tools = (0...CatalogDocument.maximumToolCount).map { index in
            tool(id: "tool-\(index)", category: .design)
        }
        let document = CatalogDocument(tools: tools)

        #expect(throws: CatalogValidationError.interactiveResourceLimitsExceeded) {
            try document.validate()
        }
    }

    @Test func aCustomCategoryCanOwnATool() throws {
        let customID = ToolCategoryId("ops")
        let document = CatalogDocument(
            tools: [tool(id: "ops-tool", category: customID)],
            customCategories: [category(id: customID)]
        )

        try document.validate()
    }

    @Test func encodingKeepsHiddenIDsInStableOrder() throws {
        let document = CatalogDocument(
            tools: [
                tool(id: "a", category: .design),
                tool(id: "z", category: .analytics),
            ],
            hiddenToolIDs: ["z", "a"]
        )

        let encoded = try JSONEncoder().encode(document)
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(json.contains("\"hiddenToolIDs\":[\"a\",\"z\"]"))
        #expect(try JSONDecoder().decode(CatalogDocument.self, from: encoded) == document)
    }

    @Test func decodingRejectsDuplicateHiddenToolIdentifiers() {
        let data = Data("""
        {"schemaVersion":2,"tools":[],"customCategories":[],"hiddenToolIDs":["duplicate","duplicate"]}
        """.utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(CatalogDocument.self, from: data)
        }
    }

    @Test func saveThenLoadRoundTripsAndCreatesBackupOnReplacement() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        let first = CatalogDocument(tools: [tool(id: "first", category: .design)])
        let second = CatalogDocument(tools: [tool(id: "second", category: .analytics)])

        try repository.save(first)
        try repository.save(second)

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A valid primary document must load normally.")
            return
        }
        #expect(loaded.tools.map(\.id) == ["second"])

        let backup = try #require(fileSystem.data(at: repository.backupURL))
        let backupDocument = try JSONDecoder().decode(CatalogDocument.self, from: backup)
        #expect(backupDocument.tools.map(\.id) == ["first"])
    }

    @Test func firstSaveCreatesAPrimaryWithoutManufacturingABackup() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        try repository.save(CatalogDocument(tools: [tool(id: "first", category: .design)]))

        #expect(fileSystem.data(at: repository.primaryURL) != nil)
        #expect(fileSystem.data(at: repository.backupURL) == nil)
    }

    @Test func candidateStagingFailureLeavesNoLiveCatalog() {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        fileSystem.failNextWrite()

        #expect(throws: CatalogPersistenceError.fileOperation(.writePrimaryStaging)) {
            try repository.save(CatalogDocument(tools: [tool(id: "candidate", category: .design)]))
        }

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A failed first staging write must not enter recovery.")
            return
        }
        #expect(loaded.tools.isEmpty)
        #expect(fileSystem.data(at: repository.backupURL) == nil)
    }

    @Test func candidateStagingFailureLeavesAnExistingPrimaryUntouched() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        try repository.save(CatalogDocument(tools: [tool(id: "first", category: .design)]))
        fileSystem.failNextWrite()

        #expect(throws: CatalogPersistenceError.fileOperation(.writePrimaryStaging)) {
            try repository.save(CatalogDocument(tools: [tool(id: "second", category: .analytics)]))
        }

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A failed candidate staging write must preserve the existing primary.")
            return
        }
        #expect(loaded.tools.map(\.id) == ["first"])
        #expect(fileSystem.data(at: repository.backupURL) == nil)
    }

    @Test func directoryCreationFailureCreatesNoLiveCatalog() {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        fileSystem.failNextDirectoryCreation()

        #expect(throws: CatalogPersistenceError.fileOperation(.createDirectory)) {
            try repository.save(CatalogDocument(tools: [tool(id: "candidate", category: .design)]))
        }

        #expect(fileSystem.data(at: repository.primaryURL) == nil)
        #expect(fileSystem.data(at: repository.backupURL) == nil)
    }

    @Test func primaryReadFailureLeavesThePriorPrimaryUntouched() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        try repository.save(CatalogDocument(tools: [tool(id: "first", category: .design)]))
        fileSystem.failNextRead(from: repository.primaryURL)

        #expect(throws: CatalogPersistenceError.fileOperation(.readPrimary)) {
            try repository.save(CatalogDocument(tools: [tool(id: "second", category: .analytics)]))
        }

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A failed primary read must leave the old primary readable.")
            return
        }
        #expect(loaded.tools.map(\.id) == ["first"])
    }

    @Test func invalidExistingPrimaryIsNeverOverwrittenBySave() {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        fileSystem.seed(Data("not JSON".utf8), at: repository.primaryURL)

        #expect(throws: CatalogPersistenceError.fileOperation(.validatePrimary)) {
            try repository.save(CatalogDocument(tools: [tool(id: "candidate", category: .design)]))
        }

        #expect(fileSystem.data(at: repository.primaryURL) == Data("not JSON".utf8))
    }

    @Test func primaryWriteFailurePreservesThePriorPrimaryAndBackup() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        let first = CatalogDocument(tools: [tool(id: "first", category: .design)])
        let replacement = CatalogDocument(tools: [tool(id: "second", category: .analytics)])
        try repository.save(first)

        fileSystem.failNextPublish(to: repository.primaryURL)
        #expect(throws: CatalogPersistenceError.fileOperation(.publishPrimary)) {
            try repository.save(replacement)
        }

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A failed replacement must leave the original primary readable.")
            return
        }
        #expect(loaded.tools.map(\.id) == ["first"])

        let backup = try #require(fileSystem.data(at: repository.backupURL))
        let backupDocument = try JSONDecoder().decode(CatalogDocument.self, from: backup)
        #expect(backupDocument.tools.map(\.id) == ["first"])
    }

    @Test func laterPrimaryPublishFailureKeepsTheLastConfirmedPrimaryAsBackup() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        let first = CatalogDocument(tools: [tool(id: "first", category: .design)])
        let second = CatalogDocument(tools: [tool(id: "second", category: .analytics)])
        let third = CatalogDocument(tools: [tool(id: "third", category: .knowledge)])
        try repository.save(first)
        try repository.save(second)

        fileSystem.failNextPublish(to: repository.primaryURL)
        #expect(throws: CatalogPersistenceError.fileOperation(.publishPrimary)) {
            try repository.save(third)
        }

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A failed later replacement must retain the last confirmed primary.")
            return
        }
        #expect(loaded.tools.map(\.id) == ["second"])

        let backup = try #require(fileSystem.data(at: repository.backupURL))
        let backupDocument = try JSONDecoder().decode(CatalogDocument.self, from: backup)
        #expect(backupDocument.tools.map(\.id) == ["second"])
    }

    @Test func backupPublishFailureLeavesThePrimaryUntouched() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        let first = CatalogDocument(tools: [tool(id: "first", category: .design)])
        let replacement = CatalogDocument(tools: [tool(id: "second", category: .analytics)])
        try repository.save(first)

        fileSystem.failNextPublish(to: repository.backupURL)
        #expect(throws: CatalogPersistenceError.fileOperation(.publishBackup)) {
            try repository.save(replacement)
        }

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A failed backup publish must leave the primary readable.")
            return
        }
        #expect(loaded.tools.map(\.id) == ["first"])
        #expect(fileSystem.data(at: repository.backupURL) == nil)
    }

    @Test func backupStagingFailureLeavesThePrimaryUntouched() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        let first = CatalogDocument(tools: [tool(id: "first", category: .design)])
        let replacement = CatalogDocument(tools: [tool(id: "second", category: .analytics)])
        try repository.save(first)

        fileSystem.failWrite(afterSuccessfulWrites: 1)
        #expect(throws: CatalogPersistenceError.fileOperation(.writeBackupStaging)) {
            try repository.save(replacement)
        }

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A failed backup staging write must leave the primary readable.")
            return
        }
        #expect(loaded.tools.map(\.id) == ["first"])
        #expect(fileSystem.data(at: repository.backupURL) == nil)
    }

    @Test func invalidPrimaryProducesRecoveryInsteadOfAnEmptyCatalog() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        fileSystem.seed(Data("not JSON".utf8), at: repository.primaryURL)
        fileSystem.seed(try JSONEncoder().encode(CatalogDocument()), at: repository.backupURL)

        guard case .recovery(let recovery) = repository.load() else {
            Issue.record("A corrupt primary must never become an empty catalog.")
            return
        }
        #expect(recovery.source == .primaryDocument)
        #expect(recovery.reason == .unreadableOrInvalidDocument)
        #expect(recovery.backupAvailable)
        #expect(recovery.recoveryCopyAvailable)
        #expect(fileSystem.data(at: repository.primaryURL) == Data("not JSON".utf8))
    }

    @Test func corruptBackupIsNotAdvertisedAsRecoverable() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        fileSystem.seed(Data("not JSON".utf8), at: repository.primaryURL)
        fileSystem.seed(Data("also not JSON".utf8), at: repository.backupURL)

        guard case .recovery(let recovery) = repository.load() else {
            Issue.record("A corrupt primary must enter recovery.")
            return
        }
        #expect(!recovery.backupAvailable)
    }

    @Test func failedRecoveryCopyWritePreservesTheCorruptPrimary() {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        fileSystem.seed(Data("not JSON".utf8), at: repository.primaryURL)
        fileSystem.failNextWrite()

        guard case .recovery(let recovery) = repository.load() else {
            Issue.record("A corrupt primary must enter recovery even if recovery copy write fails.")
            return
        }
        #expect(!recovery.recoveryCopyAvailable)
        #expect(fileSystem.data(at: repository.primaryURL) == Data("not JSON".utf8))
    }

    @Test func laterCorruptionExportsTheCurrentBytesAndRetainsThePriorSnapshot() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        let staleCopy = Data("older corrupt primary".utf8)
        let currentPrimary = Data("newer corrupt primary".utf8)
        fileSystem.seed(staleCopy, at: repository.primaryURL)

        guard case .recovery(let firstRecovery) = repository.load() else {
            Issue.record("The first corrupt primary must enter recovery.")
            return
        }
        #expect(firstRecovery.recoveryCopyAvailable)

        fileSystem.seed(currentPrimary, at: repository.primaryURL)

        guard case .recovery(let recovery) = repository.load() else {
            Issue.record("A corrupt primary must enter recovery.")
            return
        }
        #expect(recovery.recoveryCopyAvailable)
        #expect(fileSystem.data(at: repository.primaryURL) == currentPrimary)
        #expect(try repository.recoveryCopyData() == currentPrimary)
        #expect(fileSystem.data(at: repository.previousRecoveryCopyURL) == staleCopy)
    }

    @Test func explicitRecoveryReplacementMakesAnEmptyCatalogLiveOnlyAfterConfirmation() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        fileSystem.seed(Data("not JSON".utf8), at: repository.primaryURL)

        guard case .recovery = repository.load() else {
            Issue.record("A corrupt primary must be in recovery before replacement is allowed.")
            return
        }
        try repository.replaceRecoveredCatalog(with: CatalogDocument())

        guard case .catalog(let document) = repository.load() else {
            Issue.record("An explicit recovery replacement must publish a valid primary.")
            return
        }
        #expect(document == CatalogDocument())
    }

    @Test func recoveryReplacementRotatesBackupWhenThePrimaryIsStillValid() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        let original = CatalogDocument(tools: [tool(id: "original", category: .design)])
        try repository.save(original)

        try repository.replaceRecoveredCatalog(with: CatalogDocument())

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("An explicit replacement must publish its requested catalog.")
            return
        }
        #expect(loaded == CatalogDocument())
        let backup = try #require(fileSystem.data(at: repository.backupURL))
        #expect(try JSONDecoder().decode(CatalogDocument.self, from: backup) == original)
    }

    @Test func verifiedBackupCanBeRestoredWithoutTreatingCorruptPrimaryAsBackup() throws {
        let fileSystem = MemoryCatalogFileSystem()
        let repository = makeRepository(fileSystem: fileSystem)
        let first = CatalogDocument(tools: [tool(id: "first", category: .design)])
        let second = CatalogDocument(tools: [tool(id: "second", category: .analytics)])
        try repository.save(first)
        try repository.save(second)
        fileSystem.seed(Data("not JSON".utf8), at: repository.primaryURL)

        guard case .recovery(let recovery) = repository.load(), recovery.backupAvailable else {
            Issue.record("A valid previous primary must be available as recovery backup.")
            return
        }
        let restored = try repository.restoreVerifiedBackup()

        #expect(restored == first)
        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("Restoring a verified backup must replace the corrupt primary.")
            return
        }
        #expect(loaded == first)
    }

    @Test func foundationFileSystemRoundTripsInAnOwnedTemporaryDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-repository-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LocalCatalogRepository(directory: directory)
        let first = CatalogDocument(tools: [tool(id: "first", category: .design)])
        let second = CatalogDocument(tools: [tool(id: "second", category: .analytics)])

        try repository.save(first)
        try repository.save(second)

        guard case .catalog(let loaded) = repository.load() else {
            Issue.record("A valid Foundation-backed primary must load normally.")
            return
        }
        #expect(loaded.tools.map(\.id) == ["second"])
        #expect(FileManager.default.fileExists(atPath: repository.backupURL.path))
    }

    private func makeRepository(fileSystem: MemoryCatalogFileSystem? = nil) -> LocalCatalogRepository {
        let resolvedFileSystem = fileSystem ?? MemoryCatalogFileSystem()
        return LocalCatalogRepository(
            directory: URL(fileURLWithPath: "/catalog-test/\(UUID().uuidString)", isDirectory: true),
            fileSystem: resolvedFileSystem
        )
    }

    private func tool(id: String, category: ToolCategoryId, relations: [String] = [], url: URL? = nil) -> Tool {
        Tool(
            id: id,
            name: id,
            category: category,
            summary: "Test tool",
            stage: .planning,
            orbit: .inner,
            angle: 0,
            url: url,
            logoDomain: nil,
            relationIds: relations,
            classification: nil
        )
    }

    private func category(id: ToolCategoryId) -> ToolCategory {
        ToolCategory(
            id: id,
            name: "Category",
            shortName: "Category",
            description: "Test category",
            color: "#112233",
            glow: "#445566",
            angle: 0
        )
    }
}

@MainActor
final class MemoryCatalogFileSystem: CatalogFileSystem {
    enum Failure: Error, Equatable {
        case injectedWrite
    }

    private var files: [URL: Data] = [:]
    private var directories: Set<URL> = []
    private var nextFailingWriteURL: URL?
    private var failAnyWrite = false
    private var successfulWritesUntilFailure: Int?
    private var nextFailingPublishURL: URL?
    private var nextFailingReadURL: URL?
    private var failDirectoryCreation = false

    func itemExists(at url: URL) -> Bool {
        files[url] != nil
    }

    func createDirectory(at url: URL) throws {
        if failDirectoryCreation {
            failDirectoryCreation = false
            throw Failure.injectedWrite
        }
        directories.insert(url)
    }

    func readData(at url: URL) throws -> Data {
        if nextFailingReadURL == url {
            nextFailingReadURL = nil
            throw Failure.injectedWrite
        }
        guard let data = files[url] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return data
    }

    func writeAtomically(_ data: Data, to url: URL) throws {
        if failAnyWrite || nextFailingWriteURL == url {
            failAnyWrite = false
            nextFailingWriteURL = nil
            throw Failure.injectedWrite
        }
        if let remaining = successfulWritesUntilFailure {
            if remaining == 0 {
                successfulWritesUntilFailure = nil
                throw Failure.injectedWrite
            }
            successfulWritesUntilFailure = remaining - 1
        }
        files[url] = data
    }

    func publishStagedItem(at sourceURL: URL, to destinationURL: URL) throws {
        if nextFailingPublishURL == destinationURL {
            nextFailingPublishURL = nil
            throw Failure.injectedWrite
        }
        guard let data = files.removeValue(forKey: sourceURL) else {
            throw CocoaError(.fileNoSuchFile)
        }
        files[destinationURL] = data
    }

    func seed(_ data: Data, at url: URL) {
        files[url] = data
    }

    func data(at url: URL) -> Data? {
        files[url]
    }

    func failNextWrite(to url: URL) {
        nextFailingWriteURL = url
    }

    func failNextWrite() {
        failAnyWrite = true
    }

    func failWrite(afterSuccessfulWrites count: Int) {
        successfulWritesUntilFailure = count
    }

    func failNextPublish(to url: URL) {
        nextFailingPublishURL = url
    }

    func failNextRead(from url: URL) {
        nextFailingReadURL = url
    }

    func failNextDirectoryCreation() {
        failDirectoryCreation = true
    }

}
