import Foundation

/// The single durable representation of a person's local tool universe.
///
/// The document deliberately contains catalog content only. Small preferences,
/// secrets, chat state, and relation-cache data have separate owners and must
/// never be swept into an import, export, or recovery payload.
struct CatalogDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 2
    static let builtinCategoryIDs = Set(ToolCategoryId.builtins + [.core])

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
        }
    }
}
