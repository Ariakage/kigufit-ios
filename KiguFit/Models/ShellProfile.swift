import Foundation
import SwiftData

nonisolated struct ShellProfilePayload: Codable, Hashable, Sendable {
    var schema: String
    var name: String
    var source: SourceInfo?
    var outer: OuterDimensions
    var inner: InnerDimensions
    var eyeHoles: EyeHoles?
    var fit: FitSpec?
    var notes: String?

    init(
        schema: String = "kigufit.shell/v1",
        name: String,
        source: SourceInfo? = nil,
        outer: OuterDimensions,
        inner: InnerDimensions,
        eyeHoles: EyeHoles? = nil,
        fit: FitSpec? = nil,
        notes: String? = nil
    ) {
        self.schema = schema
        self.name = name
        self.source = source
        self.outer = outer
        self.inner = inner
        self.eyeHoles = eyeHoles
        self.fit = fit
        self.notes = notes
    }

    struct SourceInfo: Codable, Hashable, Sendable {
        var file: String?
        var unit: String?
    }

    struct OuterDimensions: Codable, Hashable, Sendable {
        var width: Double
        var depth: Double
        var height: Double
    }

    struct InnerDimensions: Codable, Hashable, Sendable {
        var height: Double
        var wallThickness: Double?
        var widthProfile: [WidthPoint]
        var depthProfile: [DepthPoint]?
        var faceBowlWidth: Double?

        func innerWidth(nearest z: Double) -> Double? {
            guard !widthProfile.isEmpty else { return nil }
            return widthProfile.min { abs($0.z - z) < abs($1.z - z) }?.width
        }
    }

    struct WidthPoint: Codable, Hashable, Sendable {
        var z: Double
        var width: Double
    }

    struct DepthPoint: Codable, Hashable, Sendable {
        var z: Double
        var depth: Double
    }

    struct EyeHoles: Codable, Hashable, Sendable {
        var width: Double
        var height: Double
        var centerSpacing: Double
        var centerAboveInnerBottom: Double
    }

    struct FitSpec: Codable, Hashable, Sendable {
        var headCircumferenceRange: [Double]?
        var notes: String?
    }

    static func decode(from data: Data) throws -> ShellProfilePayload {
        try JSONDecoder().decode(ShellProfilePayload.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

@Model
final class ShellProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var sourceFileName: String?
    var payloadData: Data

    init(payload: ShellProfilePayload, sourceFileName: String? = nil) {
        self.id = UUID()
        self.name = payload.name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sourceFileName = sourceFileName ?? payload.source?.file
        self.payloadData = (try? payload.encoded()) ?? Data()
    }

    var payload: ShellProfilePayload? {
        try? ShellProfilePayload.decode(from: payloadData)
    }

    var outerSummary: String {
        guard let outer = payload?.outer else { return "" }
        return String(format: "外 %.0f×%.0f×%.0f mm", outer.width, outer.depth, outer.height)
    }
}
