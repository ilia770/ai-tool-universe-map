import Testing
import Foundation
import simd
@testable import MyAIMap

/// Coverage for `PlanetData.makePlanets` / `PlanetData.core` — the bridge from
/// product data to the 3D scene contract. Inputs are built from a real model so
/// no fragile hand-rolled `Tool` fixtures are needed.
@Suite("PlanetData scene model")
@MainActor
struct PlanetDataTests {
    private func makeModel(sample: Bool = false) -> UniverseViewModel {
        let defaults = UserDefaults(suiteName: "planet-\(UUID().uuidString)")!
        let model = UniverseViewModel(store: UniverseStore(defaults: defaults))
        if sample { model.loadSampleUniverse() }
        return model
    }

    // MARK: - makePlanets

    @Test func emptyUniverseYieldsNoPlanets() {
        let model = makeModel()
        let planets = PlanetData.makePlanets(categories: model.allCategories, tools: model.visibleAllTools)
        #expect(planets.isEmpty)
    }

    @Test func onlyCategoriesHoldingToolsBecomePlanets() {
        let model = makeModel()
        #expect(model.addCustomTool(name: "Solo", urlString: "", category: .analytics))
        let planets = PlanetData.makePlanets(categories: model.allCategories, tools: model.visibleAllTools)
        // Exactly one populated category (analytics) → one planet; every empty
        // branch is dropped.
        #expect(planets.count == 1)
        #expect(planets.first?.id == .analytics)
        #expect(planets.first?.toolCount == 1)
    }

    @Test func corePlanetSitsAtOriginWithFixedRadiusAndTitle() {
        let model = makeModel(sample: true)
        let planets = PlanetData.makePlanets(categories: model.allCategories, tools: model.visibleAllTools)
        let core = planets.first { $0.id == .core }
        #expect(core != nil)
        #expect(core?.position3D == .zero)
        #expect(core?.radius == 0.94)
        #expect(core?.title == "Founder OS")
    }

    @Test func branchPlanetRadiusFollowsCappedToolCountFormula() {
        let model = makeModel(sample: true)
        let planets = PlanetData.makePlanets(categories: model.allCategories, tools: model.visibleAllTools)
        // Pin the radius contract against the planet's own (real) tool count,
        // including the min(count, 4) cap, for an arbitrary populated branch.
        let branch = planets.first { $0.id != .core }!
        let expected = 0.62 + min(Float(branch.toolCount), 4) * 0.045
        #expect(branch.radius == expected)
        #expect(branch.position3D != .zero)
    }

    @Test func toolCountMatchesVisibleToolsInCategory() {
        let model = makeModel(sample: true)
        let planets = PlanetData.makePlanets(categories: model.allCategories, tools: model.visibleAllTools)
        for planet in planets {
            let actual = model.visibleAllTools.filter { $0.category == planet.id }.count
            #expect(planet.toolCount == actual)
            #expect(planet.tools.count == actual)
        }
    }

    // MARK: - core(from:) fallback

    @Test func coreFallbackSynthesizesEmptyCoreWhenNoTools() {
        // The selected-planet projection needs a non-optional core even on an
        // empty universe — synthesize one rather than crash.
        let core = PlanetData.core(from: [])
        #expect(core.id == .core)
        #expect(core.position3D == .zero)
        #expect(core.radius == 0.94)
        #expect(core.toolCount == 0)
        #expect(core.tools.isEmpty)
        #expect(core.title == "Founder OS")
    }

    @Test func coreFallbackUsesRealCoreWhenToolsExist() {
        let model = makeModel(sample: true)
        let coreTools = model.visibleAllTools.filter { $0.category == .core }
        #expect(!coreTools.isEmpty)
        let core = PlanetData.core(from: coreTools)
        #expect(core.id == .core)
        #expect(core.toolCount == coreTools.count)
    }
}
