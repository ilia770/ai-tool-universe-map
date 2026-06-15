import Testing
@testable import MyAIMap

// @MainActor: SkyboxEntity is MainActor-isolated, so its static constants
// can't be read from a nonisolated @Test context (Swift 6 strict concurrency).
@Suite("SkyboxEntity — cosmic backdrop shell")
@MainActor
struct SkyboxEntityTests {

    @Test func shellEnclosesEverythingElse() {
        // The skybox is the outermost layer: it must sit beyond the star
        // shell (120) — itself beyond the camera's maxDistance (46) — so it
        // always reads as the far background and never clips the stars.
        #expect(SkyboxEntity.shellRadius > StarFieldGeometry.shellRadius)
    }

    @Test func textureIsEquirectangularTwoToOne() {
        // The sphere is textured with an equirectangular map; width must be
        // 2× height or the wrap seam shows.
        #expect(SkyboxEntity.textureWidth == 2 * SkyboxEntity.textureHeight)
    }

    @Test func textureIsSharperThanTheIBLProbe() {
        // The IBL probe can be tiny (it's blurred into a cube); the visible
        // skybox needs more resolution so the backdrop isn't mushy.
        #expect(SkyboxEntity.textureWidth >= CosmicEnvironmentTexture.defaultWidth)
    }
}
