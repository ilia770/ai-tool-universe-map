import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Native file-export wrapper for a validated catalog or an explicit recovery
/// copy. The UI controls the filename and confirmation; this value carries no
/// paths, filesystem errors, preferences, secrets, or unrelated app state.
struct CatalogFileDocument: FileDocument {
    static let catalogContentType = UTType.json
    static var readableContentTypes: [UTType] { [catalogContentType] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(catalog: CatalogDocument) throws {
        self.data = try catalog.transferData()
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CatalogFileDocumentError.missingContents
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum CatalogFileDocumentError: Error {
    case missingContents
}

/// A recovery copy intentionally preserves opaque bytes, which might not be
/// valid JSON. It therefore advertises a generic binary type rather than
/// claiming a malformed file is a normal catalog export.
struct CatalogRecoveryCopyDocument: FileDocument {
    static let contentType = UTType.data
    static var readableContentTypes: [UTType] { [contentType] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CatalogFileDocumentError.missingContents
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum CatalogImportPreparationError: Error, Equatable, Sendable {
    case cannotAccessSelectedFile
    case invalidOrOversizedFile
}

/// Performs the potentially slow, bounded file read away from SwiftUI's main
/// actor. Only a schema-validated document crosses back to the UI.
enum CatalogImportPreparation {
    static let maximumBytes = 5 * 1_024 * 1_024

    static func prepare(from url: URL) -> Result<CatalogDocument, CatalogImportPreparationError> {
        guard url.isFileURL else { return .failure(.invalidOrOversizedFile) }

        let grantedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if grantedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard grantedAccess else { return .failure(.cannotAccessSelectedFile) }

        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true,
                  let fileSize = values.fileSize,
                  fileSize >= 0,
                  fileSize <= maximumBytes else {
                return .failure(.invalidOrOversizedFile)
            }
            return validatedDocument(from: try boundedData(from: url))
        } catch {
            return .failure(.invalidOrOversizedFile)
        }
    }

    static func boundedData(from url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else {
            throw CatalogImportPreparationError.invalidOrOversizedFile
        }
        return data
    }

    static func validatedDocument(from data: Data) -> Result<CatalogDocument, CatalogImportPreparationError> {
        guard data.count <= maximumBytes else {
            return .failure(.invalidOrOversizedFile)
        }
        do {
            return .success(try CatalogDocument.document(fromTransferData: data))
        } catch {
            return .failure(.invalidOrOversizedFile)
        }
    }
}
