import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            RecordsView()
                .tabItem { Label("记录", systemImage: "list.bullet.rectangle") }

            ShellsView()
                .tabItem { Label("头壳", systemImage: "cube") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
}
