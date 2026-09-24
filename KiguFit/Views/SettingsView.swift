import SwiftUI

struct SettingsView: View {
    @Environment(AISettings.self) private var aiSettings
    @State private var isTesting = false
    @State private var testStatus: String?

    var body: some View {
        @Bindable var settings = aiSettings

        NavigationStack {
            Form {
                Section("AI 解读（BYOK）") {
                    Picker("服务商", selection: $settings.provider) {
                        ForEach(AISettings.Provider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .onChange(of: settings.provider) { _, _ in
                        settings.applyProviderDefaults()
                    }

                    TextField("Base URL", text: $settings.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("模型", text: $settings.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("API Key", text: $settings.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button {
                        testConnection()
                    } label: {
                        HStack(spacing: 8) {
                            if isTesting { ProgressView() }
                            Text("测试连接")
                        }
                    }
                    .disabled(!aiSettings.isConfigured || isTesting)

                    if let testStatus {
                        Text(testStatus)
                            .font(.footnote)
                            .foregroundStyle(testStatus == "连接成功" ? .green : .orange)
                    }

                    Toggle("允许 AI 读取几何数据", isOn: $settings.allowGeometryUpload)

                    Text(aiSettings.allowGeometryUpload
                         ? "已开启：AI 解读请求会附带降采样的几何摘要（内腔截面轮廓 / 面部点云采样），仅发送给你自己配置的服务商。"
                         : "关闭时只发送测量数值与判定结果，不上传任何几何数据；Key 仅保存在本机钥匙串。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("测量") {
                    LabeledContent("单位", value: "毫米 (mm)")
                    LabeledContent("必填软尺项", value: "头围、头高")
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

    private func testConnection() {
        isTesting = true
        testStatus = nil
        let client = LLMClient(baseURL: aiSettings.baseURL, apiKey: aiSettings.apiKey, model: aiSettings.model)
        Task {
            do {
                _ = try await client.complete(
                    messages: [LLMMessage(role: "user", content: "ping，请只回复 ok")],
                    maxTokens: 8
                )
                testStatus = "连接成功"
            } catch {
                testStatus = "失败：\(error.localizedDescription)"
            }
            isTesting = false
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
        .environment(AISettings())
}
