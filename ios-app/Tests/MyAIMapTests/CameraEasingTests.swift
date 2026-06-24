// ios-app/Tests/MyAIMapTests/CameraEasingTests.swift
import Testing
import simd
@testable import MyAIMap

@Suite("CameraEasing — premium fly curve")
struct CameraEasingTests {
    @Test func flyMatchesWebExpoOutCurve() {
        // Web parity: cubic-bezier(0.16, 1, 0.3, 1) — expo-out decelerate.
        #expect(CameraEasing.flyControlPoint1 == SIMD2<Float>(0.16, 1.0))
        #expect(CameraEasing.flyControlPoint2 == SIMD2<Float>(0.30, 1.0))
    }
}
