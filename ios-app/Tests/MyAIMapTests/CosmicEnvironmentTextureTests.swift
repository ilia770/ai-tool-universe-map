import Testing
import CoreGraphics
import simd
@testable import MyAIMap

@Suite("CosmicEnvironmentTexture — procedural IBL / skybox source")
struct CosmicEnvironmentTextureTests {

    // MARK: skyColor — pure equirectangular sampler

    @Test func sameInputsAreDeterministic() {
        let a = CosmicEnvironmentTexture.skyColor(u: 0.3, v: 0.6, seed: 42)
        let b = CosmicEnvironmentTexture.skyColor(u: 0.3, v: 0.6, seed: 42)
        #expect(a == b)
    }

    @Test func everyChannelIsUnitClamped() {
        for v: Float in stride(from: 0, through: 1, by: 0.1) {
            for u: Float in stride(from: 0, through: 1, by: 0.1) {
                let c = CosmicEnvironmentTexture.skyColor(u: u, v: v, seed: 7)
                #expect(c.x >= 0 && c.x <= 1)
                #expect(c.y >= 0 && c.y <= 1)
                #expect(c.z >= 0 && c.z <= 1)
            }
        }
    }

    @Test func horizonIsBrighterThanThePoles() {
        // Cosmic gradient: deep dark at the poles (v=0 top, v=1 bottom),
        // a warmer brighter band at the equator/horizon (v=0.5). Average
        // across u to cancel star speckle noise.
        func bandLuminance(_ v: Float) -> Float {
            var sum: Float = 0
            let samples = 32
            for i in 0..<samples {
                let u = Float(i) / Float(samples)
                let c = CosmicEnvironmentTexture.skyColor(u: u, v: v, seed: 11)
                sum += c.x + c.y + c.z
            }
            return sum / Float(samples)
        }
        #expect(bandLuminance(0.5) > bandLuminance(0.0))
        #expect(bandLuminance(0.5) > bandLuminance(1.0))
    }

    @Test func seedChangesTheStarSpeckle() {
        // The base gradient is seed-independent, but the sprinkled stars are
        // seeded — so across the sphere at least one sample must differ.
        var differs = false
        for i in 0..<200 {
            let u = Float(i % 20) / 20
            let v = Float(i / 20) / 10
            if CosmicEnvironmentTexture.skyColor(u: u, v: v, seed: 1)
                != CosmicEnvironmentTexture.skyColor(u: u, v: v, seed: 2) {
                differs = true
                break
            }
        }
        #expect(differs)
    }

    // MARK: makeEquirectangular — CoreGraphics image

    @Test func producesImageOfRequestedSize() {
        let image = CosmicEnvironmentTexture.makeEquirectangular(width: 64, height: 32, seed: 3)
        #expect(image != nil)
        #expect(image?.width == 64)
        #expect(image?.height == 32)
    }

    @Test func widthIsTwiceHeightByDefault() {
        // Equirectangular maps must be 2:1 or RealityKit rejects them.
        #expect(CosmicEnvironmentTexture.defaultWidth == 2 * CosmicEnvironmentTexture.defaultHeight)
    }
}
