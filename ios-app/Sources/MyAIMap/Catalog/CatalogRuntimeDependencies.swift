import Foundation

/// Production composition root for the three durable local-state owners.
/// It is deliberately created once by `MyAIMapApp`; views receive only the
/// already-initialized `UniverseViewModel` through the environment.
@MainActor
struct CatalogRuntimeDependencies {
    let repository: any CatalogRepository
    let preferences: UserDefaultsPreferences
    let migrationCoordinator: CatalogMigrationCoordinator

    static func production(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) -> CatalogRuntimeDependencies {
        let repository: any CatalogRepository
        if let directory = try? LocalCatalogRepository.applicationSupportDirectory(fileManager: fileManager) {
            repository = LocalCatalogRepository(directory: directory)
        } else {
            repository = UnavailableCatalogRepository()
        }

        let legacy = LegacyCatalogV1(defaults: defaults)
        let markerStore = UserDefaultsCatalogMigrationMarkerStore(defaults: defaults)
        return CatalogRuntimeDependencies(
            repository: repository,
            preferences: UserDefaultsPreferences(defaults: defaults),
            migrationCoordinator: CatalogMigrationCoordinator(
                repository: repository,
                legacy: legacy,
                markerStore: markerStore
            )
        )
    }

    #if DEBUG
    /// Creates an isolated corrupt-v2 fixture for the recovery UI test. This
    /// never uses Application Support or the person's defaults, and is
    /// compiled out of release builds.
    static func uiTestUnreadableCatalogFixture(
        fileManager: FileManager = .default
    ) -> CatalogRuntimeDependencies {
        let fixtureID = UUID().uuidString
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("myaimap-uitest-catalog-recovery-\(fixtureID)", isDirectory: true)
        let repository = LocalCatalogRepository(directory: directory)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data("{not-valid-json".utf8).write(to: repository.primaryURL, options: .atomic)

        guard let defaults = UserDefaults(
            suiteName: "com.ilyatur.myaimap.uitest.catalog-recovery.\(fixtureID)"
        ) else {
            fatalError("Unable to create the isolated catalog-recovery UI-test defaults suite")
        }
        let legacy = LegacyCatalogV1(defaults: defaults)
        let markerStore = UserDefaultsCatalogMigrationMarkerStore(defaults: defaults)
        return CatalogRuntimeDependencies(
            repository: repository,
            preferences: UserDefaultsPreferences(defaults: defaults),
            migrationCoordinator: CatalogMigrationCoordinator(
                repository: repository,
                legacy: legacy,
                markerStore: markerStore
            )
        )
    }
    #endif
}
