import ARKit
import AVFoundation
import Observation

@MainActor
@Observable
final class FaceScanSession: NSObject, ARSessionDelegate {
    enum State: Equatable {
        case idle
        case unsupported
        case unauthorized
        case running
        case collecting(pose: ScanPose, collected: Int, target: Int)
        case finished
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var result: ScanCaptureResult?
    private(set) var liveYaw: Double = 0
    private(set) var livePitch: Double = 0
    private(set) var isPoseSatisfied = false
    private(set) var feedback: String = ""

    let poses: [ScanPose] = ScanPose.standardSequence
    var minimumFrameInterval: TimeInterval = 0.1

    private let session = ARSession()
    private var poseIndex = 0
    private var poseFrameCount = 0
    private var frames: [FaceFrame] = []
    private var lastCollectedAt: TimeInterval = 0
    private var sumVertices: [SIMD3<Float>] = []
    private var sumLeft: SIMD3<Float> = .zero
    private var sumRight: SIMD3<Float> = .zero

    var totalTargetFrames: Int {
        poses.reduce(0) { $0 + $1.targetFrames }
    }

    var collectedFrames: Int {
        frames.count
    }

    var currentPose: ScanPose? {
        guard poseIndex < poses.count else { return nil }
        return poses[poseIndex]
    }

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        poseIndex = 0
        poseFrameCount = 0
        frames = []
        sumVertices = []
        sumLeft = .zero
        sumRight = .zero
        lastCollectedAt = 0
        result = nil
        liveYaw = 0
        livePitch = 0
        isPoseSatisfied = false
        feedback = ""

        guard ARFaceTrackingConfiguration.isSupported else {
            state = .unsupported
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            runSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        self.runSession()
                    } else {
                        self.state = .unauthorized
                    }
                }
            }
        default:
            state = .unauthorized
        }
    }

    func cancel() {
        session.pause()
        frames = []
        sumVertices = []
        result = nil
        state = .idle
    }

    private func runSession() {
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = false
        configuration.maximumNumberOfTrackedFaces = 1
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        poseIndex = 0
        poseFrameCount = 0
        state = .collecting(pose: poses[0], collected: 0, target: poses[0].targetFrames)
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let face = frame.anchors.compactMap({ $0 as? ARFaceAnchor }).first,
              face.isTracked else { return }

        let vertices = face.geometry.vertices
        let sign = PoseDetector.forwardSign(vertices: vertices)
        let pose = PoseDetector.pose(
            faceTransform: face.transform,
            cameraTransform: frame.camera.transform,
            forwardSign: sign
        )
        let left = SIMD3<Float>(
            face.leftEyeTransform.columns.3.x,
            face.leftEyeTransform.columns.3.y,
            face.leftEyeTransform.columns.3.z
        )
        let right = SIMD3<Float>(
            face.rightEyeTransform.columns.3.x,
            face.rightEyeTransform.columns.3.y,
            face.rightEyeTransform.columns.3.z
        )
        let transform = Self.flatten(face.transform)
        let timestamp = frame.timestamp

        Task { @MainActor [weak self] in
            self?.handle(
                vertices: vertices,
                left: left,
                right: right,
                transform: transform,
                timestamp: timestamp,
                yaw: pose.yaw,
                pitch: pose.pitch
            )
        }
    }

    nonisolated private static func flatten(_ matrix: simd_float4x4) -> [Float] {
        [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w
        ]
    }

    private func handle(
        vertices: [SIMD3<Float>],
        left: SIMD3<Float>,
        right: SIMD3<Float>,
        transform: [Float],
        timestamp: TimeInterval,
        yaw: Double,
        pitch: Double
    ) {
        switch state {
        case .running, .collecting:
            break
        default:
            return
        }

        liveYaw = yaw
        livePitch = pitch

        guard poseIndex < poses.count else { return }
        let pose = poses[poseIndex]
        let satisfied = pose.matches(yaw: yaw, pitch: pitch)
        isPoseSatisfied = satisfied
        feedback = pose.feedback(yaw: yaw, pitch: pitch)

        guard satisfied else { return }
        guard timestamp - lastCollectedAt >= minimumFrameInterval else { return }

        lastCollectedAt = timestamp
        let faceFrame = FaceFrame(
            vertices: vertices,
            leftEye: left,
            rightEye: right,
            faceTransform: transform,
            timestamp: timestamp,
            yaw: Float(yaw),
            pitch: Float(pitch)
        )
        frames.append(faceFrame)

        if sumVertices.isEmpty {
            sumVertices = [SIMD3<Float>](repeating: .zero, count: vertices.count)
        }
        if sumVertices.count == vertices.count {
            for index in vertices.indices {
                sumVertices[index] += vertices[index]
            }
        }
        sumLeft += left
        sumRight += right

        poseFrameCount += 1

        if poseFrameCount >= pose.targetFrames {
            poseIndex += 1
            poseFrameCount = 0
            if poseIndex >= poses.count {
                completeCapture()
                return
            }
            let nextPose = poses[poseIndex]
            state = .collecting(pose: nextPose, collected: 0, target: nextPose.targetFrames)
        } else {
            state = .collecting(pose: pose, collected: poseFrameCount, target: pose.targetFrames)
        }
    }

    private func completeCapture() {
        session.pause()
        guard let last = frames.last, !sumVertices.isEmpty else {
            state = .failed("未采集到有效帧")
            return
        }

        let count = Float(frames.count)
        let averaged = sumVertices.map { $0 / count }
        let left = sumLeft / count
        let right = sumRight / count
        let quality = min(1.0, Double(frames.count) / Double(totalTargetFrames))

        result = ScanCaptureResult(
            averagedVertices: averaged,
            leftEye: left,
            rightEye: right,
            faceTransform: last.faceTransform,
            frames: frames,
            quality: quality,
            capturedAt: Date()
        )
        state = .finished
    }
}
