// ios-app/Sources/MyAIMap/Universe/CameraEasing.swift
import RealityKit
import simd

/// Premium camera fly-to curve: an expo-out decelerate that reads as physical
/// and expensive instead of the mechanical `.easeInOut`. Mirrors the web
/// build's `cubic-bezier(0.16, 1, 0.3, 1)` (same curve as `BrandMotion.entry`).
enum CameraEasing {
    static let flyControlPoint1 = SIMD2<Float>(0.16, 1.0)
    static let flyControlPoint2 = SIMD2<Float>(0.30, 1.0)

    static var fly: AnimationTimingFunction {
        .cubicBezier(controlPoint1: flyControlPoint1, controlPoint2: flyControlPoint2)
    }
}
