import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("测量") {
                    LabeledContent("单位", value: "毫米 (mm)")
                    LabeledContent("必填软尺项", value: "头围、头高")
                }
                Section("AI 解读（P3）") {
                    Text("接入方式为用户自填 API Key（BYOK），Developer 阶段暂未开放。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Section("关于") {
                    LabeledContent("版本", value: appVersion)
                    Text("KiguFit — Kigurumi 头壳测量与适配工具")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
