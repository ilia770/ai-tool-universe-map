import CoreGraphics
import Testing
@testable import MyAIMap

@Suite("ConstellationLayout — clustered star-field")
struct ConstellationLayoutTests {

    private func make(_ size: CGSize = CGSize(width: 393, height: 852)) -> ConstellationLayoutResult {
        let planets = PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools)
        return ConstellationLayout.make(planets: planets, size: size)
    }

    @Test func everyToolBecomesAStar() {
        let result = make()
        for tool in UniverseSeed.tools where tool.id != PlanetData.centralCoreToolID {
            #expect(result.stars.contains { $0.toolID == tool.id }, "missing star for \(tool.id)")
        }
    }

    @Test func coreStarExistsAndIsCentral() {
        let size = CGSize(width: 393, height: 852)
        let result = ConstellationLayout.make(
            planets: PlanetData.makePlanets(categories: UniverseSeed.categories, tools: UniverseSeed.tools),
            size: size
        )
        let core = result.stars.first { $0.isCore }
        #expect(core != nil)
        #expect(abs((core?.position.x ?? 0) - size.width / 2) < 60)
    }

    @Test func starsDoNotOverlapAtIPhoneWidth() {
        let stars = make().stars
        for i in stars.indices {
            for j in stars.indices where j > i {
                let d = hypot(stars[i].position.x - stars[j].position.x,
                              stars[i].position.y - stars[j].position.y)
                #expect(d >= stars[i].radius + stars[j].radius,
                        "\(stars[i].id) overlaps \(stars[j].id)")
            }
        }
    }

    @Test func starsAreNearTheirClusterCenter() {
        let result = make()
        let clustersByID = Dictionary(uniqueKeysWithValues: result.clusters.map { ($0.id, $0) })
        for star in result.stars where !star.isCore {
            guard let cluster = clustersByID[star.category] else { continue }
            let d = hypot(star.position.x - cluster.center.x, star.position.y - cluster.center.y)
            #expect(d <= cluster.radius * 1.4 + star.radius + 1, "\(star.id) is outside its constellation")
        }
    }

    @Test func everyNonCoreCategoryHasACluster() {
        let result = make()
        for category in UniverseSeed.categories.map(\.id) where category != .core {
            #expect(result.clusters.contains { $0.id == category }, "missing cluster for \(category.rawValue)")
        }
    }

    @Test func layoutIsDeterministic() {
        let a = make()
        let b = make()
        #expect(a == b)
    }
}
