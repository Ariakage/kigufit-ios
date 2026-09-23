import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class PhotoReconstructionModel {
    enum Phase: Equatable {
        case picking
        case preparing
        case reconstructing(Double)
        case done
        case failed(String)
    }

    var phase: Phase = .picking
    var scanName: String
    private(set) var savedRecord: HeadModelScan?
    private(set) var imageCount = 0
    private var modelContext: ModelContext?

    init() {
        scanName = "头模 \(Date().formatted(date: .numeric, time: .shortened))"
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func start(imageData: [Data]) {
        guard !imageData.isEmpty else {
            phase = .failed("未选择照片")
            return
        }
        phase = .preparing

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kigufit-photos-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var written = 0
            for (index, data) in imageData.enumerated() {
                guard let image = UIImage(data: data),
                      let jpeg = image.jpegData(compressionQuality: 0.92) else { continue }
                let url = directory.appendingPathComponent(String(format: "photo_%03d.jpg", index))
                try jpeg.write(to: url)
                written += 1
            }
            imageCount = written
            guard written >= 3 else {
                phase = .failed("有效照片不足，建议 30 张以上")
                return
            }
            reconstruct(directory: directory)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func reconstruct(directory: URL) {
        phase = .reconstructing(0)
        let outputURL = HeadModelStore.tempUSDZURL()

        Task { [weak self] in
            do {
                try await HeadModelReconstructor.reconstruct(
                    imagesDirectory: directory,
                    outputURL: outputURL
                ) { fraction in
                    self?.phase = .reconstructing(fraction)
                }
                self?.complete(tempURL: outputURL)
            } catch {
                self?.phase = .failed(error.localizedDescription)
            }
        }
    }

    private func complete(tempURL: URL) {
        guard let modelContext else {
            phase = .failed("存储上下文不可用")
            return
        }
        do {
            let record = try HeadModelStore.persist(usdzTempURL: tempURL, name: scanName, shotCount: imageCount)
            modelContext.insert(record)
            savedRecord = record
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
