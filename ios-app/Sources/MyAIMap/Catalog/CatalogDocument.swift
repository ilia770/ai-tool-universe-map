import Foundation

/// The single durable representation of a person's local tool universe.
///
/// The document deliberately contains catalog content only. Small preferences,
/// secrets, chat state, and relation-cache data have separate owners and must
/// never be swept into an import, export, or recovery payload.
struct CatalogDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2
    static let builtinCategoryIDs = Set(ToolCategoryId.builtins + [.core])

    /// Bounds for the current on-device, fully interactive renderer. They are
    /// catalog invariants rather than importer-only checks, so a version-skewed
    /// local document cannot repeatedly launch into an unrecoverable rendering
    /// workload either. A future paged renderer can raise these with a schema
    /// migration and explicit performance evidence.
    static let maximumToolCount = 512
    static let maximumCustomCategoryCount = 64
    static let maximumRelationsPerTool = 64
    static let maximumRelationCount = 4_096

    let schemaVersion: Int
    var tools: [Tool]
    var customCategories: [ToolCategory]
    var hiddenToolIDs: Set<String>

    init(
        schemaVersion: Int = CatalogDocument.currentSchemaVersion,
        tools: [Tool] = [],
        customCategories: [ToolCategory] = [],
        hiddenToolIDs: Set<String> = []
    ) {
        self.schemaVersion = schemaVersion
        self.tools = tools
        self.customCategories = customCategories
        self.hiddenToolIDs = hiddenToolIDs
    }

    /// Encodes hidden IDs in a stable order. The runtime needs set membership;
    /// the on-disk document benefits from deterministic exports and backups.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case tools
        case customCategories
        case hiddenToolIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        tools = try container.decode([Tool].self, forKey: .tools)
        customCategories = try container.decode([ToolCategory].self, forKey: .customCategories)
        let decodedHiddenToolIDs = try container.decode([String].self, forKey: .hiddenToolIDs)
        guard Set(decodedHiddenToolIDs).count == decodedHiddenToolIDs.count else {
            throw DecodingError.dataCorruptedError(
                forKey: .hiddenToolIDs,
                in: container,
                debugDescription: "A catalog cannot contain the same hidden tool identifier twice."
            )
        }
        hiddenToolIDs = Set(decodedHiddenToolIDs)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(tools, forKey: .tools)
        try container.encode(customCategories, forKey: .customCategories)
        try container.encode(hiddenToolIDs.sorted(), forKey: .hiddenToolIDs)
    }

    /// Validates all durable domain references before a document can become the
    /// live catalog. Invalid content is returned to the repository as recovery,
    /// never converted to an empty universe.
    func validate(builtinCategoryIDs: Set<ToolCategoryId> = CatalogDocument.builtinCategoryIDs) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw CatalogValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        guard hasInteractiveFootprintWithinLimits else {
            throw CatalogValidationError.interactiveResourceLimitsExceeded
        }

        let toolIDs = tools.map(\.id)
        guard toolIDs.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CatalogValidationError.emptyToolIdentifier
        }
        guard Set(toolIDs).count == toolIDs.count else {
            throw CatalogValidationError.duplicateToolIdentifier
        }

        let customCategoryIDs = customCategories.map(\.id)
        guard customCategoryIDs.allSatisfy({ !$0.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CatalogValidationError.emptyCategoryIdentifier
        }
        guard Set(customCategoryIDs).count == customCategoryIDs.count else {
            throw CatalogValidationError.duplicateCategoryIdentifier
        }
        guard Set(customCategoryIDs).isDisjoint(with: builtinCategoryIDs) else {
            throw CatalogValidationError.customCategoryConflictsWithBuiltin
        }

        let availableCategoryIDs = builtinCategoryIDs.union(customCategoryIDs)
        guard tools.allSatisfy({ availableCategoryIDs.contains($0.category) }) else {
            throw CatalogValidationError.toolReferencesUnknownCategory
        }

        let toolIDSet = Set(toolIDs)
        guard hiddenToolIDs.isSubset(of: toolIDSet) else {
            throw CatalogValidationError.hiddenToolIsMissing
        }
        guard !hiddenToolIDs.contains(UniverseIdentity.centralCoreToolID) else {
            throw CatalogValidationError.hiddenCoreTool
        }

        guard tools.allSatisfy({ Set($0.relationIds).isSubset(of: toolIDSet) }) else {
            throw CatalogValidationError.relationReferencesMissingTool
        }
        guard tools.allSatisfy({ tool in
            guard let url = tool.url else { return true }
            return url.scheme?.lowercased() == "https" && url.host != nil
        }) else {
            throw CatalogValidationError.toolURLIsNotHTTPS
        }
    }

    private var hasInteractiveFootprintWithinLimits: Bool {
        guard tools.count <= Self.maximumToolCount,
              customCategories.count <= Self.maximumCustomCategoryCount,
              hiddenToolIDs.count <= Self.maximumToolCount else {
            return false
        }

        let relationCount = tools.reduce(into: 0) { partialResult, tool in
            partialResult += tool.relationIds.count
        }
        guard relationCount <= Self.maximumRelationCount else { return false }

        for tool in tools {
            guard tool.relationIds.count <= Self.maximumRelationsPerTool,
                  Self.isWithinUTF8Limit(tool.id, maximumBytes: 128),
                  Self.isWithinUTF8Limit(tool.name, maximumBytes: 160),
                  Self.isWithinUTF8Limit(tool.summary, maximumBytes: 2_000),
                  tool.url.map({ Self.isWithinUTF8Limit($0.absoluteString, maximumBytes: 2_048) }) ?? true,
                  tool.logoDomain.map({ Self.isWithinUTF8Limit($0, maximumBytes: 255) }) ?? true,
                  tool.relationIds.allSatisfy({ Self.isWithinUTF8Limit($0, maximumBytes: 128) }) else {
                return false
            }
            if let classification = tool.classification {
                guard classification.matchedKeywords.count <= 16,
                      Self.isWithinUTF8Limit(classification.reason, maximumBytes: 1_000),
                      classification.matchedKeywords.allSatisfy({ Self.isWithinUTF8Limit($0, maximumBytes: 80) }) else {
                    return false
                }
            }
        }

        return customCategories.allSatisfy { category in
            Self.isWithinUTF8Limit(category.id.rawValue, maximumBytes: 128)
                && Self.isWithinUTF8Limit(category.name, maximumBytes: 160)
                && Self.isWithinUTF8Limit(category.shortName, maximumBytes: 160)
                && Self.isWithinUTF8Limit(category.description, maximumBytes: 2_000)
                && Self.isWithinUTF8Limit(category.color.rawValue, maximumBytes: 64)
                && Self.isWithinUTF8Limit(category.glow.rawValue, maximumBytes: 64)
        }
    }

    private static func isWithinUTF8Limit(_ value: String, maximumBytes: Int) -> Bool {
        value.utf8.count <= maximumBytes
    }

    /// Stable, validated transfer bytes for native export. This is deliberately
    /// the catalog only: preferences, secrets, chats, caches, and attachments
    /// never enter the portable document.
    func transferData() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    static func document(fromTransferData data: Data) throws -> CatalogDocument {
        let document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        try document.validate()
        return document
    }
}

enum CatalogValidationError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case emptyToolIdentifier
    case duplicateToolIdentifier
    case emptyCategoryIdentifier
    case duplicateCategoryIdentifier
    case customCategoryConflictsWithBuiltin
    case toolReferencesUnknownCategory
    case hiddenToolIsMissing
    case hiddenCoreTool
    case relationReferencesMissingTool
    case toolURLIsNotHTTPS
    case interactiveResourceLimitsExceeded

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported catalog version \(version)."
        case .emptyToolIdentifier:
            return "A tool is missing its identifier."
        case .duplicateToolIdentifier:
            return "Two tools share an identifier."
        case .emptyCategoryIdentifier:
            return "A category is missing its identifier."
        case .duplicateCategoryIdentifier:
            return "Two custom categories share an identifier."
        case .customCategoryConflictsWithBuiltin:
            return "A custom category conflicts with a built-in category."
        case .toolReferencesUnknownCategory:
            return "A tool references a missing category."
        case .hiddenToolIsMissing:
            return "A hidden tool is missing from the catalog."
        case .hiddenCoreTool:
            return "The protected core tool cannot be hidden."
        case .relationReferencesMissingTool:
            return "A tool relation references a missing tool."
        case .toolURLIsNotHTTPS:
            return "A tool URL must use HTTPS."
        case .interactiveResourceLimitsExceeded:
            return "This catalog is too large for the current interactive map."
        }
    }
}
