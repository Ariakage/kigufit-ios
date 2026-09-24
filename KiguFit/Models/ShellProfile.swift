import Foundation
import SwiftData

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

    func rename(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        name = trimmed
        updatedAt = Date()
        if var current = payload {
            current.name = trimmed
            if let data = try? current.encoded() {
                payloadData = data
            }
        }
    }

    var outerSummary: String {
        guard let outer = payload?.outer else { return "" }
        return String(format: "外 %.0f×%.0f×%.0f mm", outer.width, outer.depth, outer.height)
    }
}
