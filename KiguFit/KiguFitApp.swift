import SwiftUI
import SwiftData

@main
struct KiguFitApp: App {
    @State private var aiSettings = AISettings()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ShellProfile.self,
            ScanRecord.self,
            HeadModelScan.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .environment(aiSettings)
        .modelContainer(sharedModelContainer)
    }
}
