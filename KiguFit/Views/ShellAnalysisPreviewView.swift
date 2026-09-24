import SwiftUI

struct ShellAnalysisPreviewView: View {
    let analysis: ShellAnalysis
    let onSave: (String, String?) -> Void

    @State private var name: String
    @State private var interpretation: String?
    @State private var isGeneratingAI = false
    @State private var aiError: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(AISettings.self) private var aiSettings

    init(analysis: ShellAnalysis, onSave: @escaping (String, String?) -> Void) {
        self.analysis = analysis
        self.onSave = onSave
        _name = State(initialValue: analysis.name)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("名称") {
                    TextField("头壳名称", text: $name)
                }

                Section("识别结果") {
                    LabeledContent("外形", value: String(format: "%.1f × %.1f × %.1f mm", analysis.outerWidth, analysis.outerDepth, analysis.outerHeight))
                    LabeledContent("内腔高", value: String(format: "%.1f mm", analysis.innerHeight))
                    if let wall = analysis.wallThickness {
                        LabeledContent("壁厚", value: String(format: "%.1f mm", wall))
                    }
                    if let band = analysis.width(atFraction: 0.5) {
                        LabeledContent("头带内宽", value: String(format: "%.1f mm", band))
                    }
                    if let bowl = analysis.faceBowlWidth {
                        LabeledContent("脸碗内宽", value: String(format: "%.1f mm", bowl))
                    }
                    if let eye = analysis.eyeHoles {
                        LabeledContent("眼孔", value: String(format: "%.0f×%.0f mm，中心距 %.0f，高于内底 %.0f", eye.width, eye.height, eye.spacing, eye.aboveInnerBottom))
                    }
                }

                if !analysis.componentSummaries.isEmpty {
                    Section("部件") {
                        ForEach(analysis.componentSummaries, id: \.self) { summary in
                            Text(summary)
                                .font(.callout)
                        }
                    }
                }

                Section("说明") {
                    ForEach(analysis.notes, id: \.self) { note in
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("AI 解读") {
                    if let interpretation {
                        Text(interpretation)
                    }
                    Button {
                        generateAI()
                    } label: {
                        Label(interpretation == nil ? "生成 AI 解读" : "重新生成", systemImage: "sparkles")
                    }
                    .disabled(!aiSettings.isConfigured || isGeneratingAI)
                    if !aiSettings.isConfigured {
                        Text("请先在「设置 → AI 解读（BYOK）」里配置 API Key")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if isGeneratingAI {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在生成…")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let aiError {
                        Text(aiError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), interpretation)
                        dismiss()
                    } label: {
                        Label("保存为头壳档案", systemImage: "square.and.arrow.down")
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("OBJ 分析结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func generateAI() {
        guard aiSettings.isConfigured else { return }
        isGeneratingAI = true
        aiError = nil
        let geometry = aiSettings.allowGeometryUpload ? AIPipeline.contourBlock(from: analysis.contourSamples) : nil
        let messages = AIPipeline.shellMessages(context: AIPipeline.context(from: analysis), geometry: geometry)
        let client = LLMClient(
            baseURL: aiSettings.baseURL,
            apiKey: aiSettings.apiKey,
            model: aiSettings.model
        )
        Task {
            do {
                interpretation = try await client.complete(messages: messages, maxTokens: 600)
            } catch {
                aiError = error.localizedDescription
            }
            isGeneratingAI = false
        }
    }
}
