import Foundation
import Observation
import RealityKit
import SwiftData
import SwiftUI

@MainActor
@Observable
final class HeadModelCaptureModel {
    enum Phase: Equatable {
        case unsupported
        case preparing
        case capturing
        case reconstructing(Double)
        case done
        case failed(String)
    }

    private(set) var phase: Phase = .preparing
    private(set) var feedbackMessages: [String] = []
    private(set) var userCompletedScanPass = false
    private(set) var shotCount = 0
    private(set) var numberOfShots = 0
    private(set) var savedRecord: HeadModelScan?
    var scanName: String

    let session: ObjectCaptureSession?
    private let imagesDirectory: URL
    private var didStartReconstruction = false
    private var didAutoStartCapturing = false
    private var modelContext: ModelContext?

    init() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kigufit-capture-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        imagesDirectory = directory
        scanName = "头模 \(Date().formatted(date: .numeric, time: .shortened))"

        if ObjectCaptureSession.isSupported {
            session = ObjectCaptureSession()
        } else {
            session = nil
            phase = .unsupported
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startSession() {
        guard let session, phase == .preparing else { return }
        var configuration = ObjectCaptureSession.Configuration()
        configuration.isOverCaptureEnabled = false
        session.start(imagesDirectory: imagesDirectory, configuration: configuration)
    }

    func beginCapturing() {
        session?.startCapturing()
        phase = .capturing
    }

    func continueAfterFlip() {
        session?.beginNewScanPassAfterFlip()
        userCompletedScanPass = false
    }

    func beginAnotherPass() {
        session?.beginNewScanPass()
        userCompletedScanPass = false
    }

    func finishCapture() {
        guard let session else { return }
        shotCount = session.numberOfShotsTaken
        phase = .reconstructing(0)
        session.finish()
    }

    func cancelAndCleanup() {
        session?.cancel()
    }

    func handleStateChange(_ state: ObjectCaptureSession.CaptureState) {
        switch state {
        case .ready:
            if phase == .reconstructing(0) { break }
        case .detecting:
            if !didAutoStartCapturing {
                didAutoStartCapturing = true
                session?.startCapturing()
            }
        case .capturing:
            phase = .capturing
        case .completed:
            startReconstruction()
        case let .failed(error):
            phase = .failed(error.localizedDescription)
        default:
            break
        }
    }

    func updateFeedback(_ feedback: Set<ObjectCaptureSession.Feedback>) {
        feedbackMessages = feedback.sorted { $0.messagePriority < $1.messagePriority }.map(\.message)
    }

    func updateUserCompletedScanPass(_ completed: Bool) {
        userCompletedScanPass = completed
    }

    func updateShotCount(_ count: Int) {
        numberOfShots = count
    }

    private func startReconstruction() {
        guard !didStartReconstruction else { return }
        didStartReconstruction = true
        phase = .reconstructing(0)

        let imagesDirectory = imagesDirectory
        let outputURL = HeadModelStore.tempUSDZURL()

        Task { [weak self] in
            do {
                try await HeadModelReconstructor.reconstruct(
                    imagesDirectory: imagesDirectory,
                    outputURL: outputURL,
                    sampleOrdering: .sequential
                ) { fraction in
                    self?.phase = .reconstructing(fraction)
                }
                self?.completeReconstruction(tempURL: outputURL)
            } catch {
                self?.phase = .failed(error.localizedDescription)
            }
        }
    }

    private func completeReconstruction(tempURL: URL) {
        guard let modelContext else {
            phase = .failed("存储上下文不可用")
            return
        }
        do {
            let record = try HeadModelStore.persist(usdzTempURL: tempURL, name: scanName, shotCount: shotCount)
            modelContext.insert(record)
            savedRecord = record
            phase = .done
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

private extension ObjectCaptureSession.Feedback {
    var messagePriority: Int {
        switch self {
        case .environmentTooDark: return 0
        case .environmentLowLight: return 1
        case .objectNotDetected: return 2
        case .outOfFieldOfView: return 3
        case .objectTooClose: return 4
        case .objectTooFar: return 5
        case .movingTooFast: return 6
        case .overCapturing: return 7
        case .objectNotFlippable: return 8
        @unknown default: return 99
        }
    }

    var message: String {
        switch self {
        case .objectTooClose: return "离远一点"
        case .objectTooFar: return "靠近一点"
        case .movingTooFast: return "移动慢一点"
        case .environmentLowLight: return "环境光偏弱：开顶灯或补光灯，避免逆光"
        case .environmentTooDark: return "环境太暗：摄影测量需要明亮光线，请显著增加照明"
        case .outOfFieldOfView: return "请让头模保持在画面内"
        case .objectNotFlippable: return "物体不适合翻转"
        case .overCapturing: return "拍摄数量已足够"
        case .objectNotDetected: return "未检测到物体，请对准头模"
        @unknown default: return "请调整拍摄姿势"
        }
    }
}
