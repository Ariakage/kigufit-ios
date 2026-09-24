import Foundation
import Observation

@MainActor
@Observable
final class ShellAnalyzerModel {
    private(set) var isAnalyzing = false
    private(set) var preview: ShellAnalysis?
    var errorMessage: String?

    func analyze(url: URL) {
        isAnalyzing = true
        preview = nil

        let name = url.deletingPathExtension().lastPathComponent
        let fileName = url.lastPathComponent

        Task {
            do {
                let analysis = try await Task.detached(priority: .userInitiated) {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessing { url.stopAccessingSecurityScopedResource() }
                    }
                    let data = try Data(contentsOf: url)
                    let mesh = try OBJParser.parse(data: data)
                    return try ShellAnalyzer.analyze(mesh: mesh, name: name, sourceFile: fileName)
                }.value
                self.preview = analysis
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isAnalyzing = false
        }
    }

    func clearPreview() {
        preview = nil
    }
}
