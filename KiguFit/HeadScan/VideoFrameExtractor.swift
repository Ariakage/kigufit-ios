import AVFoundation
import CoreGraphics
import Foundation
import UIKit

nonisolated enum VideoFrameExtractor {
    static func extractFrames(
        from url: URL,
        into directory: URL,
        startIndex: Int,
        targetCount: Int,
        prefix: String,
        maxDimension: CGFloat = 2160
    ) async throws -> Int {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 1 else { return 0 }

        let count = max(3, min(targetCount, 200))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)

        var times: [CMTime] = []
        times.reserveCapacity(count)
        for index in 0..<count {
            let position = seconds * (Double(index) + 0.5) / Double(count)
            times.append(CMTime(seconds: position, preferredTimescale: 600))
        }

        var written = 0
        for await result in generator.images(for: times) {
            switch result {
            case let .success(requestedTime: _, image: image, actualTime: _):
                guard let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.9) else { continue }
                let name = String(format: "%@_%04d.jpg", prefix, startIndex + written)
                try data.write(to: directory.appendingPathComponent(name))
                written += 1
            case .failure:
                continue
            @unknown default:
                continue
            }
        }
        return written
    }
}
