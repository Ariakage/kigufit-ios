import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var shells: [ShellProfile]

    var body: some View {
        TabView {
            RecordsView()
                .tabItem { Label("记录", systemImage: "list.bullet.rectangle") }

            ShellsView()
                .tabItem { Label("头壳", systemImage: "cube") }

            HeadModelsView()
                .tabItem { Label("头模", systemImage: "rotate.3d") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .task {
            if shells.isEmpty {
                modelContext.insert(ShellProfile(payload: SampleShell.payload))
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [ShellProfile.self, ScanRecord.self, HeadModelScan.self], inMemory: true)
}
