import Foundation
import SwiftData

@Model
final class ScanRecord {
    @Attribute(.unique) var id: UUID
    var clientName: String
    var createdAt: Date
    var shellName: String
    var shellPayloadData: Data?
    var measurementsData: Data
    var verdictData: Data?
    var aiNarrative: String?
    var notes: String?
    @Attribute(.externalStorage) var meshData: Data?
    @Attribute(.externalStorage) var meshFramesData: Data?

    init(
        clientName: String,
        shellName: String,
        shellPayloadData: Data? = nil,
        measurements: [MeasurementValue] = []
    ) {
        self.id = UUID()
        self.clientName = clientName
        self.createdAt = Date()
        self.shellName = shellName
        self.shellPayloadData = shellPayloadData
        self.measurementsData = (try? JSONEncoder().encode(measurements)) ?? Data()
    }

    var measurements: [MeasurementValue] {
        get {
            (try? JSONDecoder().decode([MeasurementValue].self, from: measurementsData)) ?? []
        }
        set {
            measurementsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var verdict: FitVerdict? {
        get {
            guard let verdictData else { return nil }
            return try? JSONDecoder().decode(FitVerdict.self, from: verdictData)
        }
        set {
            verdictData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    var shellPayload: ShellProfilePayload? {
        guard let shellPayloadData else { return nil }
        return try? ShellProfilePayload.decode(from: shellPayloadData)
    }
}
