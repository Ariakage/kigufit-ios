import Foundation

nonisolated struct ShellProfilePayload: Codable, Hashable, Sendable {
    var schema: String
    var name: String
    var source: SourceInfo?
    var outer: OuterDimensions
    var inner: InnerDimensions
    var eyeHoles: EyeHoles?
    var fit: FitSpec?
    var notes: String?
    var aiInterpretation: String?

    init(
        schema: String = "kigufit.shell/v1",
        name: String,
        source: SourceInfo? = nil,
        outer: OuterDimensions,
        inner: InnerDimensions,
        eyeHoles: EyeHoles? = nil,
        fit: FitSpec? = nil,
        notes: String? = nil,
        aiInterpretation: String? = nil
    ) {
        self.schema = schema
        self.name = name
        self.source = source
        self.outer = outer
        self.inner = inner
        self.eyeHoles = eyeHoles
        self.fit = fit
        self.notes = notes
        self.aiInterpretation = aiInterpretation
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

        func width(atFraction fraction: Double) -> Double? {
            let points = widthProfile.compactMap { point -> (Double, Double)? in
                guard let value = point.fraction else { return nil }
                return (value, point.width)
            }
            guard !points.isEmpty else { return nil }
            return points.min { abs($0.0 - fraction) < abs($1.0 - fraction) }?.1
        }

        func depth(atFraction fraction: Double) -> Double? {
            guard let depthProfile else { return nil }
            let points = depthProfile.compactMap { point -> (Double, Double)? in
                guard let value = point.fraction else { return nil }
                return (value, point.depth)
            }
            guard !points.isEmpty else { return nil }
            return points.min { abs($0.0 - fraction) < abs($1.0 - fraction) }?.1
        }

        func bandWidth() -> Double? {
            width(atFraction: 0.5) ?? innerWidth(nearest: 20)
        }

        func bandDepth() -> Double? {
            depth(atFraction: 0.5) ?? depthProfile?.min { abs($0.z - 20) < abs($1.z - 20) }?.depth
        }

        func bowlWidth() -> Double? {
            faceBowlWidth ?? width(atFraction: 0.22)
        }
    }

    struct WidthPoint: Codable, Hashable, Sendable {
        var z: Double
        var width: Double
        var fraction: Double? = nil
    }

    struct DepthPoint: Codable, Hashable, Sendable {
        var z: Double
        var depth: Double
        var fraction: Double? = nil
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
