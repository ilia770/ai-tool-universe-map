import Foundation

/// Bounds untrusted catalog structure before `JSONDecoder` materializes it.
///
/// The decoder otherwise has to allocate every array in an unknown extension
/// field before the catalog's domain validation can reject it.
enum CatalogJSONPreflight {
    static let maximumNestingDepth = 32
    static let maximumArrayElementCount = CatalogDocument.maximumToolCount
    static let maximumObjectMemberCount = CatalogDocument.maximumToolCount
    /// A valid maximum catalog needs 13,376 array elements at most: tools,
    /// categories, hidden IDs, relations, and classification keywords.
    static let maximumTotalArrayElementCount = 16_384
    /// A valid maximum catalog needs fewer than 8,000 object members.
    static let maximumTotalObjectMemberCount = 16_384
    static let maximumStringByteCount = 16 * 1_024
    static let maximumScalarByteCount = 256

    static func validate(_ data: Data) throws {
        try data.withUnsafeBytes { rawBuffer in
            var scanner = Scanner(bytes: rawBuffer.bindMemory(to: UInt8.self))
            try scanner.validate()
        }
    }

    private struct Scanner {
        private enum ArrayState: Equatable { case firstValueOrEnd, nextValue, commaOrEnd }
        private enum ObjectState: Equatable { case firstKeyOrEnd, nextKey, colon, value, commaOrEnd }
        private enum Container {
            case array(elements: Int, state: ArrayState)
            case object(members: Int, state: ObjectState)
        }

        private let bytes: UnsafeBufferPointer<UInt8>
        private var index = 0
        private var stack: [Container] = []
        private var hasRootValue = false
        private var totalArrayElementCount = 0
        private var totalObjectMemberCount = 0

        init(bytes: UnsafeBufferPointer<UInt8>) {
            self.bytes = bytes
        }

        mutating func validate() throws {
            while true {
                skipWhitespace()
                guard index < bytes.count else { break }
                switch bytes[index] {
                case 0x7B:
                    try beginValue()
                    try push(.object(members: 0, state: .firstKeyOrEnd))
                    index += 1
                case 0x5B:
                    try beginValue()
                    try push(.array(elements: 0, state: .firstValueOrEnd))
                    index += 1
                case 0x7D:
                    try closeObject()
                    index += 1
                case 0x5D:
                    try closeArray()
                    index += 1
                case 0x3A:
                    try consumeColon()
                    index += 1
                case 0x2C:
                    try consumeComma()
                    index += 1
                case 0x22:
                    if expectsObjectKey {
                        try beginObjectKey()
                        try scanString(maximumByteCount: CatalogJSONPreflight.maximumScalarByteCount)
                    } else {
                        try beginValue()
                        try scanString(maximumByteCount: CatalogJSONPreflight.maximumStringByteCount)
                    }
                default:
                    try beginValue()
                    try scanScalar()
                }
            }
            guard hasRootValue, stack.isEmpty else { throw invalidJSON() }
        }

        private var expectsObjectKey: Bool {
            guard let container = stack.last, case .object(_, let state) = container else { return false }
            return state == .firstKeyOrEnd || state == .nextKey
        }

        private mutating func skipWhitespace() {
            while index < bytes.count, Self.isWhitespace(bytes[index]) { index += 1 }
        }

        private mutating func beginValue() throws {
            guard let container = stack.last else {
                guard !hasRootValue else { throw invalidJSON() }
                hasRootValue = true
                return
            }
            switch container {
            case .array(let elements, let state) where state == .firstValueOrEnd || state == .nextValue:
                guard elements < CatalogJSONPreflight.maximumArrayElementCount,
                      totalArrayElementCount < CatalogJSONPreflight.maximumTotalArrayElementCount else {
                    throw resourceLimitExceeded()
                }
                stack[stack.count - 1] = .array(elements: elements + 1, state: .commaOrEnd)
                totalArrayElementCount += 1
            case .object(let members, .value):
                stack[stack.count - 1] = .object(members: members, state: .commaOrEnd)
            default:
                throw invalidJSON()
            }
        }

        private mutating func beginObjectKey() throws {
            guard let container = stack.last else { throw invalidJSON() }
            switch container {
            case .object(let members, let state) where state == .firstKeyOrEnd || state == .nextKey:
                guard members < CatalogJSONPreflight.maximumObjectMemberCount,
                      totalObjectMemberCount < CatalogJSONPreflight.maximumTotalObjectMemberCount else {
                    throw resourceLimitExceeded()
                }
                stack[stack.count - 1] = .object(members: members + 1, state: .colon)
                totalObjectMemberCount += 1
            default:
                throw invalidJSON()
            }
        }

        private mutating func consumeColon() throws {
            guard let container = stack.last, case .object(let members, .colon) = container else { throw invalidJSON() }
            stack[stack.count - 1] = .object(members: members, state: .value)
        }

        private mutating func consumeComma() throws {
            guard let container = stack.last else { throw invalidJSON() }
            switch container {
            case .array(let elements, .commaOrEnd):
                stack[stack.count - 1] = .array(elements: elements, state: .nextValue)
            case .object(let members, .commaOrEnd):
                stack[stack.count - 1] = .object(members: members, state: .nextKey)
            default:
                throw invalidJSON()
            }
        }

        private mutating func closeArray() throws {
            guard let container = stack.last,
                  case .array(_, let state) = container,
                  state == .firstValueOrEnd || state == .commaOrEnd else { throw invalidJSON() }
            stack.removeLast()
        }

        private mutating func closeObject() throws {
            guard let container = stack.last,
                  case .object(_, let state) = container,
                  state == .firstKeyOrEnd || state == .commaOrEnd else { throw invalidJSON() }
            stack.removeLast()
        }

        private mutating func push(_ container: Container) throws {
            guard stack.count < CatalogJSONPreflight.maximumNestingDepth else { throw resourceLimitExceeded() }
            stack.append(container)
        }

        private mutating func scanString(maximumByteCount: Int) throws {
            guard index < bytes.count, bytes[index] == 0x22 else { throw invalidJSON() }
            index += 1
            let contentStart = index
            while index < bytes.count {
                guard index - contentStart <= maximumByteCount else { throw resourceLimitExceeded() }
                let byte = bytes[index]
                if byte == 0x22 {
                    index += 1
                    return
                }
                if byte == 0x5C {
                    index += 1
                    guard index < bytes.count else { throw invalidJSON() }
                } else {
                    guard byte >= 0x20 else { throw invalidJSON() }
                }
                index += 1
            }
            throw invalidJSON()
        }

        private mutating func scanScalar() throws {
            let start = index
            while index < bytes.count, !Self.isValueDelimiter(bytes[index]) {
                index += 1
                guard index - start <= CatalogJSONPreflight.maximumScalarByteCount else { throw resourceLimitExceeded() }
            }
            guard index > start else { throw invalidJSON() }
        }

        private static func isWhitespace(_ byte: UInt8) -> Bool {
            byte == 0x09 || byte == 0x0A || byte == 0x0D || byte == 0x20
        }

        private static func isValueDelimiter(_ byte: UInt8) -> Bool {
            isWhitespace(byte) || byte == 0x2C || byte == 0x5D || byte == 0x7D
        }

        private func invalidJSON() -> DecodingError {
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The catalog JSON is malformed."))
        }

        private func resourceLimitExceeded() -> DecodingError {
            DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "The catalog JSON exceeds the supported resource limits."))
        }
    }
}

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
        try CatalogJSONPreflight.validate(data)
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
