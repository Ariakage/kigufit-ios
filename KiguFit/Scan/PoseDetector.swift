import ARKit
import simd

nonisolated enum PoseDetector {
    struct Pose: Sendable {
        var yaw: Double
        var pitch: Double
    }

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

    static func pose(faceTransform: simd_float4x4, cameraTransform: simd_float4x4, forwardSign: Float) -> Pose {
        let cameraInverse = simd_inverse(cameraTransform)
        let faceInCamera = simd_mul(cameraInverse, faceTransform)
        let rotation = simd_float3x3(
            SIMD3<Float>(faceInCamera.columns.0.x, faceInCamera.columns.0.y, faceInCamera.columns.0.z),
            SIMD3<Float>(faceInCamera.columns.1.x, faceInCamera.columns.1.y, faceInCamera.columns.1.z),
            SIMD3<Float>(faceInCamera.columns.2.x, faceInCamera.columns.2.y, faceInCamera.columns.2.z)
        )
        let forwardLocal = SIMD3<Float>(0, 0, forwardSign)
        let forwardCamera = rotation * forwardLocal
        let yaw = atan2(Double(forwardCamera.x), Double(-forwardCamera.z)) * 180 / .pi
        let pitch = atan2(Double(forwardCamera.y), Double(-forwardCamera.z)) * 180 / .pi
        return Pose(yaw: yaw, pitch: pitch)
    }
}
