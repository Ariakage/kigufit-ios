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
        case collecting(captured: Int, target: Int)
        case finished
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var result: ScanCaptureResult?

    var targetFrameCount = 45

    private let session = ARSession()
    private var frames: [FaceFrame] = []
    private var sumVertices: [SIMD3<Float>] = []
    private var sumLeft: SIMD3<Float> = .zero
    private var sumRight: SIMD3<Float> = .zero

    override init() {
        super.init()
        session.delegate = self
    }

    func start() {
        frames = []
        sumVertices = []
        sumLeft = .zero
        sumRight = .zero
        result = nil

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
        state = .running
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first,
              face.isTracked else { return }

        let vertices = face.geometry.vertices
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
        let transform = flatten(face.transform)

        Task { @MainActor [weak self] in
            self?.append(vertices: vertices, left: left, right: right, transform: transform)
        }
    }

    nonisolated private func flatten(_ matrix: simd_float4x4) -> [Float] {
        [
            matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
            matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
            matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
            matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w
        ]
    }

    private func append(vertices: [SIMD3<Float>], left: SIMD3<Float>, right: SIMD3<Float>, transform: [Float]) {
        switch state {
        case .running, .collecting:
            break
        default:
            return
        }
        guard frames.count < targetFrameCount else { return }

        let frame = FaceFrame(
            vertices: vertices,
            leftEye: left,
            rightEye: right,
            faceTransform: transform,
            timestamp: Date().timeIntervalSince1970
        )
        frames.append(frame)

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

        let captured = frames.count
        state = .collecting(captured: captured, target: targetFrameCount)

        if captured >= targetFrameCount {
            completeCapture()
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
        let quality = min(1.0, Double(frames.count) / Double(targetFrameCount))

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
