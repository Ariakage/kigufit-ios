import Foundation
import ModelIO
import SwiftData

@Model
final class HeadModelScan {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var usdzFileName: String
    var objFileName: String?
    var shotCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        usdzFileName: String,
        objFileName: String? = nil,
        shotCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.usdzFileName = usdzFileName
        self.objFileName = objFileName
        self.shotCount = shotCount
    }

    var usdzURL: URL {
        HeadModelStore.fileURL(for: usdzFileName)
    }

    var objURL: URL? {
        objFileName.map { HeadModelStore.fileURL(for: $0) }
    }

    var formattedDate: String {
        createdAt.formatted(date: .numeric, time: .shortened)
    }
}

nonisolated enum HeadModelStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("HeadModels", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileURL(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func tempUSDZURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KiguFit-scan-\(UUID().uuidString).usdz")
    }

    static func persist(usdzTempURL: URL, name: String, shotCount: Int) throws -> HeadModelScan {
        let id = UUID()
        let usdzName = "\(id.uuidString).usdz"
        let usdzDestination = fileURL(for: usdzName)
        try FileManager.default.moveItem(at: usdzTempURL, to: usdzDestination)

        var objName: String?
        if MDLAsset.canExportFileExtension("obj") {
            let objDestination = fileURL(for: "\(id.uuidString).obj")
            do {
                let asset = MDLAsset(url: usdzDestination)
                try asset.export(to: objDestination)
                objName = objDestination.lastPathComponent
            } catch {
                objName = nil
            }
        }

        return HeadModelScan(
            id: id,
            name: name,
            usdzFileName: usdzName,
            objFileName: objName,
            shotCount: shotCount
        )
    }

    static func deleteFiles(for model: HeadModelScan) {
        try? FileManager.default.removeItem(at: model.usdzURL)
        if let objURL = model.objURL {
            try? FileManager.default.removeItem(at: objURL)
        }
    }
}
