import Foundation

nonisolated struct ScanReportExport: Codable {
    var schema: String
    var client: String
    var date: String
    var shell: ShellRef
    var measurements: [Item]
    var verdict: FitVerdict?
    var aiNarrative: String?

    struct ShellRef: Codable {
        var name: String
        var schemaRef: String
    }

    struct Item: Codable {
        var key: String
        var label: String
        var value: Double
        var unit: String
        var source: String
        var confidence: Double
    }
}

@MainActor
enum ExportService {
    static func scanJSON(record: ScanRecord) -> Data? {
        let export = ScanReportExport(
            schema: "kigufit.scan/v1",
            client: record.clientName,
            date: ISO8601DateFormatter().string(from: record.createdAt),
            shell: .init(name: record.shellName, schemaRef: "kigufit.shell/v1"),
            measurements: record.measurements.map {
                .init(
                    key: $0.key.rawValue,
                    label: $0.key.displayName,
                    value: (($0.valueMM * 10).rounded() / 10),
                    unit: "mm",
                    source: $0.source.rawValue,
                    confidence: $0.confidence
                )
            },
            verdict: record.verdict,
            aiNarrative: record.aiNarrative
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try? encoder.encode(export)
    }

    static func writeTempFile(_ data: Data, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func sanitizedFilename(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "record" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(scalars)
    }
}
