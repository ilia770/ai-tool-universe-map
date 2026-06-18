import CoreGraphics
import simd

/// Procedurally generates the equirectangular cosmic environment map that
/// drives image-based lighting (backlog 29) — and, later, the skybox
/// backdrop (backlog 28). The earlier ambient-fill slice (#71) deferred true
/// IBL because it assumed a *bundled* `.exr`/`.hdr` art asset we don't have.
/// We don't need one: a deep-space gradient with a warm horizon band and a
/// sprinkle of stars is generated in CoreGraphics at launch and handed to
/// `EnvironmentResource.generate(fromEquirectangular:)`, giving PBR materials
/// real reflections without shipping a binary texture.
///
/// The colour math (`skyColor`) is kept pure (CoreGraphics + simd, no
/// RealityKit) so `CosmicEnvironmentTextureTests` can exercise the gradient,
/// determinism, and seeding in the `MyAIMapTests` target. `makeEquirectangular`
/// is the thin sampler that paints `skyColor` into a `CGImage`.
enum CosmicEnvironmentTexture {

    /// Equirectangular maps must be 2:1. 512×256 is ample for soft IBL —
    /// the specular cube RealityKit derives from it is downsampled anyway,
    /// and a small source keeps launch-time generation cheap.
    static let defaultHeight = 256
    static let defaultWidth = 512

    /// Default seed for the production environment (drives the star sprinkle
    /// and faint per-cell variation).
    static let defaultSeed: UInt64 = 0x0C05_31C0

    /// Deep space at the poles — near-black blue-violet.
    private static let poleColor = SIMD3<Float>(0.015, 0.018, 0.045)
    /// Luminous nebular band at the horizon (equator).
    private static let horizonColor = SIMD3<Float>(0.10, 0.085, 0.16)
    /// Subtle warm tint pushed in right at the horizon line.
    private static let horizonWarm = SIMD3<Float>(0.16, 0.09, 0.11)

    /// Equirectangular sky colour at longitude `u` (0…1) and latitude `v`
    /// (0 = top pole … 1 = bottom pole), in linear RGB clamped to 0…1.
    static func skyColor(u: Float, v: Float, seed: UInt64 = defaultSeed) -> SIMD3<Float> {
        // 1 at the equator, 0 at either pole.
        let equator = 1 - abs(2 * v - 1)
        // Concentrate brightness into the horizon band.
        let band = pow(max(0, equator), 1.6)
        var color = lerp(poleColor, horizonColor, band)
        // A tight warm push only in the last few degrees of the horizon.
        color += horizonWarm * (pow(max(0, equator), 6) * 0.5)
        color += starAndDust(u: u, v: v, seed: seed)
        return simd_clamp(color, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
    }

    /// Paints `skyColor` into a premultiplied-RGBA8 `CGImage`. Returns nil
    /// only for non-positive dimensions or an unexpected context failure.
    static func makeEquirectangular(width: Int = defaultWidth,
                                    height: Int = defaultHeight,
                                    seed: UInt64 = defaultSeed) -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)

        for y in 0..<height {
            let v = (Float(y) + 0.5) / Float(height)
            for x in 0..<width {
                let u = (Float(x) + 0.5) / Float(width)
                let c = skyColor(u: u, v: v, seed: seed)
                let offset = y * bytesPerRow + x * bytesPerPixel
                data[offset] = channelByte(c.x)
                data[offset + 1] = channelByte(c.y)
                data[offset + 2] = channelByte(c.z)
                data[offset + 3] = 255
            }
        }

        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        return data.withUnsafeMutableBytes { raw -> CGImage? in
            guard let ctx = CGContext(data: raw.baseAddress,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: space,
                                      bitmapInfo: info) else { return nil }
            return ctx.makeImage()
        }
    }

    // MARK: - Helpers

    private static func lerp(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }

    private static func channelByte(_ value: Float) -> UInt8 {
        UInt8(min(255, max(0, value * 255)))
    }

    /// Faint always-on per-cell variation (so the field isn't a sterile
    /// gradient and every point is seed-dependent) plus a sparse bright-star
    /// layer. Amplitudes are tiny relative to the horizon gradient so the
    /// large-scale brightness curve is preserved.
    private static func starAndDust(u: Float, v: Float, seed: UInt64) -> SIMD3<Float> {
        let cols: Float = 512, rows: Float = 256
        let cx = UInt64(min(max(u, 0), 0.99999) * cols)
        let cy = UInt64(min(max(v, 0), 0.99999) * rows)
        let cell = seed
            &+ cx &* 0x9E37_79B9_7F4A_7C15
            &+ cy &* 0xC2B2_AE3D_27D4_EB4F
        let h = splitmix(cell)

        // Always-on faint dust: ±0.01 grey jitter, seed-dependent everywhere.
        let dust = (unitFloat(h) - 0.5) * 0.02
        var contribution = SIMD3<Float>(repeating: dust)

        // ~1 cell in 130 is a star: a small near-white point.
        if h % 130 == 0 {
            let brightness = 0.45 + 0.55 * unitFloat(splitmix(h ^ 0xABCD_EF01))
            contribution += SIMD3<Float>(brightness * 0.85, brightness * 0.85, brightness)
        }
        return contribution
    }

    private static func splitmix(_ input: UInt64) -> UInt64 {
        var z = input &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    private static func unitFloat(_ bits: UInt64) -> Float {
        Float((bits >> 40) & 0xFFFF) / Float(0xFFFF)
    }
}
