import ARKit
import simd

nonisolated enum PoseDetector {
    struct Orientation: Sendable {
        var forward: SIMD3<Float>
        var left: SIMD3<Float>
        var pitch: Double
    }

    struct Baseline: Sendable {
        var forward: SIMD3<Float>
        var left: SIMD3<Float>
        var pitch: Double
    }

    struct RelativeAngles: Sendable {
        var yaw: Double
        var pitch: Double

        static let zero = RelativeAngles(yaw: 0, pitch: 0)
    }

    static let lateralPolarity: Float = 1

    static func forwardSign(vertices: [SIMD3<Float>]) -> Float {
        guard !vertices.isEmpty else { return 1 }
        let ys = vertices.map { Double($0.y) }
        guard let yMin = ys.min(), let yMax = ys.max(), yMax > yMin else { return 1 }
        let height = yMax - yMin
        let midline = vertices.filter { abs($0.x) < 0.012 }
        let candidates = midline.filter {
            let u = (Double($0.y) - yMin) / height
            return u >= 0.35 && u <= 0.60
        }
        guard let extreme = candidates.max(by: { abs(Double($0.z)) < abs(Double($1.z)) }) else { return 1 }
        return extreme.z >= 0 ? 1 : -1
    }

    static func orientation(
        faceTransform: simd_float4x4,
        leftEyeLocal: SIMD3<Float>,
        rightEyeLocal: SIMD3<Float>,
        forwardSign: Float
    ) -> Orientation {
        let rotation = simd_float3x3(
            SIMD3<Float>(faceTransform.columns.0.x, faceTransform.columns.0.y, faceTransform.columns.0.z),
            SIMD3<Float>(faceTransform.columns.1.x, faceTransform.columns.1.y, faceTransform.columns.1.z),
            SIMD3<Float>(faceTransform.columns.2.x, faceTransform.columns.2.y, faceTransform.columns.2.z)
        )
        let forward = safeNormalize(rotation * SIMD3<Float>(0, 0, forwardSign))
        let eyeDelta = (leftEyeLocal - rightEyeLocal) * lateralPolarity
        let left = safeNormalize(rotation * eyeDelta)
        let pitch = asin(max(-1, min(1, Double(forward.y)))) * 180 / .pi
        return Orientation(forward: forward, left: left, pitch: pitch)
    }

    static func makeBaseline(from samples: [Orientation]) -> Baseline? {
        guard !samples.isEmpty else { return nil }
        var forward = SIMD3<Float>(repeating: 0)
        var left = SIMD3<Float>(repeating: 0)
        var pitch = 0.0
        for sample in samples {
            forward += sample.forward
            left += sample.left
            pitch += sample.pitch
        }
        return Baseline(
            forward: safeNormalize(forward),
            left: safeNormalize(left),
            pitch: pitch / Double(samples.count)
        )
    }

    static func relativeAngles(_ orientation: Orientation, baseline: Baseline) -> RelativeAngles {
        let baseForward2 = SIMD2<Double>(Double(baseline.forward.x), Double(baseline.forward.z))
        let currentForward2 = SIMD2<Double>(Double(orientation.forward.x), Double(orientation.forward.z))
        var baseLeft2 = SIMD2<Double>(Double(baseline.left.x), Double(baseline.left.z))

        let baseForwardLength = simd_length(baseForward2)
        guard baseForwardLength > 0.0001 else {
            return RelativeAngles(yaw: 0, pitch: orientation.pitch - baseline.pitch)
        }
        let baseForward = baseForward2 / baseForwardLength

        if simd_length(baseLeft2) > 0.0001 {
            baseLeft2 -= baseForward * simd_dot(baseLeft2, baseForward)
        }
        let baseLeftLength = simd_length(baseLeft2)
        let baseLeft = baseLeftLength > 0.0001 ? baseLeft2 / baseLeftLength : SIMD2<Double>(-baseForward.y, baseForward.x)

        let currentLength = simd_length(currentForward2)
        let currentForward = currentLength > 0.0001 ? currentForward2 / currentLength : baseForward

        let yaw = atan2(simd_dot(currentForward, baseLeft), simd_dot(currentForward, baseForward)) * 180 / .pi
        let pitch = orientation.pitch - baseline.pitch
        return RelativeAngles(yaw: yaw, pitch: pitch)
    }

    private static func safeNormalize(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        guard length > 0.0001, length.isFinite else { return SIMD3<Float>(0, 0, 1) }
        return vector / length
    }
}
