import SwiftUI

struct ShellAnalysisPreviewView: View {
    let analysis: ShellAnalysis
    let onSave: (String) -> Void

    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(analysis: ShellAnalysis, onSave: @escaping (String) -> Void) {
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

                Section {
                    Button {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
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
}
