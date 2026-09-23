import Foundation
import RealityKit

nonisolated enum HeadModelReconstructor {
    enum ReconstructionError: Error, LocalizedError {
        case cancelled

        var errorDescription: String? {
            switch self {
            case .cancelled: return "重建已取消"
            }
        }
    }

    static func reconstruct(
        imagesDirectory: URL,
        outputURL: URL,
        sampleOrdering: PhotogrammetrySession.Configuration.SampleOrdering = .unordered,
        onProgress: @MainActor @Sendable @escaping (Double) -> Void
    ) async throws {
        var configuration = PhotogrammetrySession.Configuration()
        configuration.isObjectMaskingEnabled = true
        configuration.sampleOrdering = sampleOrdering
        configuration.featureSensitivity = .high

        let session = try PhotogrammetrySession(input: imagesDirectory, configuration: configuration)
        let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced)
        try session.process(requests: [request])

        for try await output in session.outputs {
            switch output {
            case let .requestProgress(_, fractionComplete):
                await onProgress(fractionComplete)
            case .processingComplete:
                return
            case .processingCancelled:
                throw ReconstructionError.cancelled
            case let .requestError(_, error):
                throw error
            default:
                break
            }
        }
    }
}
