import Foundation
import CryptoKit

/// Read-only view of the three v1 defaults values that together formed the
/// catalog. It deliberately excludes small preferences, Keychain values,
/// relation cache, developer flags, and all other defaults keys.
@MainActor
struct LegacyCatalogV1 {
    enum Key {
        static let tools = "universe.customTools.v1"
        static let categories = "universe.customCategories.v1"
        static let hiddenToolIDs = "universe.hiddenToolIDs.v1"
    }

    static let catalogKeys = [Key.tools, Key.categories, Key.hiddenToolIDs]

    private let defaults: UserDefaults
    private let decoder: JSONDecoder

    init(defaults: UserDefaults, decoder: JSONDecoder = JSONDecoder()) {
        self.defaults = defaults
        self.decoder = decoder
    }

    /// Returns `.absent` only when none of the catalog keys has ever been
    /// written. Once any v1 catalog key exists, all three must be decodable:
    /// accepting a partial multi-key write as empty data would silently erase
    /// user content during the very migration meant to protect it.
    func loadDocument() -> LegacyCatalogV1LoadResult {
        guard containsCatalogData else { return .absent }

        do {
            let snapshot = try rawSnapshot()
            let hiddenToolIDs = try decode([String].self, from: snapshot.hiddenToolIDs)
            guard Set(hiddenToolIDs).count == hiddenToolIDs.count else {
                throw LegacyCatalogV1DecodingError.duplicateHiddenIdentifier
            }
            let document = CatalogDocument(
                tools: try decode([Tool].self, from: snapshot.tools),
                customCategories: try decode([ToolCategory].self, from: snapshot.categories),
                hiddenToolIDs: Set(hiddenToolIDs)
            )
            try document.validate()
            return .document(document, fingerprint: snapshot.fingerprint)
        } catch {
            return .invalid
        }
    }

    var containsCatalogData: Bool {
        Self.catalogKeys.contains { defaults.object(forKey: $0) != nil }
    }

    /// A byte-exact fingerprint lets the next cold initialization prove that
    /// it is deleting the same v1 snapshot it migrated, not data subsequently
    /// written by an older rollback build.
    var currentFingerprint: Data? {
        try? rawSnapshot().fingerprint
    }

    private func rawSnapshot() throws -> LegacyCatalogV1RawSnapshot {
        guard let tools = defaults.data(forKey: Key.tools),
              let categories = defaults.data(forKey: Key.categories),
              let hiddenToolIDs = defaults.data(forKey: Key.hiddenToolIDs) else {
            throw LegacyCatalogV1DecodingError.missingOrNonDataValue
        }
        return LegacyCatalogV1RawSnapshot(
            tools: tools,
            categories: categories,
            hiddenToolIDs: hiddenToolIDs
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        return try decoder.decode(T.self, from: data)
    }
}

enum LegacyCatalogV1LoadResult: Equatable, Sendable {
    case absent
    case document(CatalogDocument, fingerprint: Data)
    case invalid
}

private struct LegacyCatalogV1RawSnapshot {
    let tools: Data
    let categories: Data
    let hiddenToolIDs: Data

    var fingerprint: Data {
        var hasher = SHA256()
        for part in [tools, categories, hiddenToolIDs] {
            var byteCount = UInt64(part.count).bigEndian
            let length = withUnsafeBytes(of: &byteCount) { Data($0) }
            hasher.update(data: length)
            hasher.update(data: part)
        }
        return Data(hasher.finalize())
    }
}

private enum LegacyCatalogV1DecodingError: Error {
    case missingOrNonDataValue
    case duplicateHiddenIdentifier
}
