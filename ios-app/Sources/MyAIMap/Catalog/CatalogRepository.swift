import Foundation

enum CatalogRecoverySource: String, Equatable, Sendable {
    case primaryDocument
    case importPayload
    case legacyDefaults
}

enum CatalogRecoveryReason: Equatable, Sendable {
    case unreadableOrInvalidDocument
}

/// Minimal, non-sensitive context the UI needs to offer recovery without ever
/// rendering the corrupt payload, raw filesystem error, or private path.
struct CatalogRecovery: Equatable, Sendable {
    let source: CatalogRecoverySource
    let reason: CatalogRecoveryReason
    let backupAvailable: Bool
    let recoveryCopyAvailable: Bool
}

enum CatalogLoadResult: Sendable {
    case catalog(CatalogDocument)
    case recovery(CatalogRecovery)
}

enum CatalogFileOperation: Equatable, Sendable {
    case createDirectory
    case encodeCandidate
    case writePrimaryStaging
    case readPrimary
    case validatePrimary
    case writeBackupStaging
    case publishBackup
    case publishPrimary
}

/// Public persistence failures deliberately carry no raw path or underlying
/// error. The UI may present a safe operation-level message without leaking
/// catalog contents or local filesystem metadata.
enum CatalogPersistenceError: Error, Equatable, Sendable {
    case validation(CatalogValidationError)
    case fileOperation(CatalogFileOperation)
}

/// The only production owner of user catalog content after migration.
///
/// This intentionally excludes preferences, secrets, assistant session state,
/// and the provider/relation cache. Methods are main-actor isolated because
/// their sole initial consumer is the main-actor `UniverseViewModel` and file
/// replacement must not race UI mutations.
@MainActor
protocol CatalogRepository: AnyObject {
    func load() -> CatalogLoadResult
    func save(_ document: CatalogDocument) throws
}

/// Small file seam for deterministic failure tests. A candidate and backup are
/// written as unique siblings before a staged item is published to its durable
/// name; failed staging files are retained rather than deleting evidence.
@MainActor
protocol CatalogFileSystem: AnyObject {
    func itemExists(at url: URL) -> Bool
    func createDirectory(at url: URL) throws
    func readData(at url: URL) throws -> Data
    func writeAtomically(_ data: Data, to url: URL) throws
    func copyItem(at sourceURL: URL, to destinationURL: URL) throws
    func publishStagedItem(at sourceURL: URL, to destinationURL: URL) throws
}

@MainActor
final class FoundationCatalogFileSystem: CatalogFileSystem {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func itemExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func createDirectory(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func readData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    func writeAtomically(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    func publishStagedItem(at sourceURL: URL, to destinationURL: URL) throws {
        if itemExists(at: destinationURL) {
            _ = try fileManager.replaceItemAt(
                destinationURL,
                withItemAt: sourceURL,
                backupItemName: nil,
                options: []
            )
        } else {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }
    }
}

@MainActor
final class LocalCatalogRepository: CatalogRepository {
    private let directory: URL
    private let fileSystem: any CatalogFileSystem
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL) {
        self.directory = directory
        self.fileSystem = FoundationCatalogFileSystem()
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    init(
        directory: URL,
        fileSystem: any CatalogFileSystem,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.directory = directory
        self.fileSystem = fileSystem
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.sortedKeys]
    }

    /// Production composition may call this during app construction. Tests pass
    /// a temporary directory explicitly, so no test ever reaches app storage.
    static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent("com.ilyatur.myaimap", isDirectory: true)
            .appendingPathComponent("catalog", isDirectory: true)
    }

    func load() -> CatalogLoadResult {
        guard fileSystem.itemExists(at: primaryURL) else {
            return .catalog(CatalogDocument())
        }

        do {
            return .catalog(try decodeValidatedDocument(at: primaryURL))
        } catch {
            return .recovery(
                CatalogRecovery(
                    source: .primaryDocument,
                    reason: .unreadableOrInvalidDocument,
                    backupAvailable: hasVerifiedBackup(),
                    recoveryCopyAvailable: quarantinePrimaryIfPossible()
                )
            )
        }
    }

    /// Stages the candidate and then preserves a verified previous primary as
    /// backup before publishing the candidate. Each `Data.write(.atomic)` is a
    /// same-directory atomic file replacement; it does not by itself replace the
    /// backup protocol or imply a power-loss durability guarantee.
    func save(_ document: CatalogDocument) throws {
        do {
            try document.validate()
        } catch let error as CatalogValidationError {
            throw CatalogPersistenceError.validation(error)
        } catch {
            throw CatalogPersistenceError.fileOperation(.validatePrimary)
        }

        do {
            try fileSystem.createDirectory(at: directory)
        } catch {
            throw CatalogPersistenceError.fileOperation(.createDirectory)
        }

        let candidateData: Data
        do {
            candidateData = try encoder.encode(document)
        } catch {
            throw CatalogPersistenceError.fileOperation(.encodeCandidate)
        }

        let primaryStagingURL = stagingURL(label: "primary")
        do {
            try fileSystem.writeAtomically(candidateData, to: primaryStagingURL)
        } catch {
            throw CatalogPersistenceError.fileOperation(.writePrimaryStaging)
        }

        if fileSystem.itemExists(at: primaryURL) {
            let existingData: Data
            do {
                existingData = try fileSystem.readData(at: primaryURL)
            } catch {
                throw CatalogPersistenceError.fileOperation(.readPrimary)
            }
            do {
                let existingDocument = try decoder.decode(CatalogDocument.self, from: existingData)
                try existingDocument.validate()
            } catch {
                throw CatalogPersistenceError.fileOperation(.validatePrimary)
            }

            let backupStagingURL = stagingURL(label: "backup")
            do {
                try fileSystem.writeAtomically(existingData, to: backupStagingURL)
            } catch {
                throw CatalogPersistenceError.fileOperation(.writeBackupStaging)
            }
            do {
                try fileSystem.publishStagedItem(at: backupStagingURL, to: backupURL)
            } catch {
                throw CatalogPersistenceError.fileOperation(.publishBackup)
            }
        }

        do {
            try fileSystem.publishStagedItem(at: primaryStagingURL, to: primaryURL)
        } catch {
            throw CatalogPersistenceError.fileOperation(.publishPrimary)
        }
    }

    var primaryURL: URL {
        directory.appendingPathComponent("catalog-v2.json", isDirectory: false)
    }

    var backupURL: URL {
        directory.appendingPathComponent("catalog-v2.backup.json", isDirectory: false)
    }

    private func stagingURL(label: String) -> URL {
        directory.appendingPathComponent(".catalog-v2.\(label).\(UUID().uuidString).staging", isDirectory: false)
    }

    private var quarantineURL: URL {
        directory.appendingPathComponent("catalog-v2.invalid.json", isDirectory: false)
    }

    private func quarantinePrimaryIfPossible() -> Bool {
        if fileSystem.itemExists(at: quarantineURL) {
            return true
        }
        do {
            try fileSystem.copyItem(at: primaryURL, to: quarantineURL)
            return true
        } catch {
            return false
        }
    }

    private func hasVerifiedBackup() -> Bool {
        guard fileSystem.itemExists(at: backupURL) else { return false }
        return (try? decodeValidatedDocument(at: backupURL)) != nil
    }

    private func decodeValidatedDocument(at url: URL) throws -> CatalogDocument {
        let data = try fileSystem.readData(at: url)
        let document = try decoder.decode(CatalogDocument.self, from: data)
        try document.validate()
        return document
    }
}
