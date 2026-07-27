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
}
