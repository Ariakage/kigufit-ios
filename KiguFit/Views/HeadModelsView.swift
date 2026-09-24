import SwiftData
import SwiftUI

struct HeadModelsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \HeadModelScan.createdAt, order: .reverse) private var models: [HeadModelScan]
    @State private var isShowingCapture = false
    @State private var isShowingPhotoReconstruction = false

    var body: some View {
        NavigationStack {
            Group {
                if models.isEmpty {
                    ContentUnavailableView(
                        "暂无 3D 头模",
                        systemImage: "rotate.3d",
                        description: Text("用 LiDAR 扫描头模或实物，导出 USDZ / OBJ 到 Blender 做头壳设计。需要 iPhone Pro 机型。")
                    )
                } else {
                    List {
                        ForEach(models) { model in
                            NavigationLink {
                                HeadModelDetailView(model: model)
                            } label: {
                                HeadModelRow(model: model)
                            }
                        }
                        .onDelete(perform: deleteModels)
                    }
                }
            }
            .navigationTitle("头模")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isShowingCapture = true
                        } label: {
                            Label("LiDAR 实时扫描", systemImage: "lidar.scanner")
                        }
                        Button {
                            isShowingPhotoReconstruction = true
                        } label: {
                            Label("照片重建（自扫）", systemImage: "photo.stack")
                        }
                    } label: {
                        Label("添加", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingCapture) {
                NavigationStack {
                    HeadModelCaptureView()
                }
            }
            .sheet(isPresented: $isShowingPhotoReconstruction) {
                NavigationStack {
                    PhotoReconstructionView()
                }
            }
        }
    }

    private func deleteModels(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let model = models[index]
                HeadModelStore.deleteFiles(for: model)
                modelContext.delete(model)
            }
        }
    }
}

private struct HeadModelRow: View {
    let model: HeadModelScan

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.name)
                .font(.headline)
            HStack(spacing: 8) {
                Label("USDZ", systemImage: "cube")
                if model.objURL != nil {
                    Label("OBJ", systemImage: "square.stack.3d.up")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text("\(model.formattedDate) · \(model.shotCount) 张")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct HeadModelDetailView: View {
    let model: HeadModelScan
    @Environment(\.modelContext) private var modelContext
    @State private var isAnalyzing = false
    @State private var analysis: HeadScanAnalysis?
    @State private var analysisError: String?
    @State private var recordCreated = false

    var body: some View {
        List {
            Section("模型") {
                LabeledContent("名称", value: model.name)
                LabeledContent("创建时间", value: model.formattedDate)
                LabeledContent("拍摄张数", value: "\(model.shotCount)")
            }

            Section("自动测量") {
                if let analysis {
                    LabeledContent("头宽 (扫描)", value: String(format: "%.1f mm", analysis.headWidth))
                    LabeledContent("头深 (扫描)", value: String(format: "%.1f mm", analysis.headDepth))
                    LabeledContent("头顶-颈部高", value: String(format: "%.0f mm", analysis.headHeightApprox))
                    LabeledContent("估算头围", value: String(format: "%.0f mm", analysis.estimatedCircumference))
                    ForEach(analysis.notes, id: \.self) { note in
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if recordCreated {
                        Label("已生成测量记录（见「记录」页）", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout)
                    } else {
                        Button {
                            createRecord(from: analysis)
                        } label: {
                            Label("生成测量记录", systemImage: "square.and.pencil")
                        }
                    }
                } else {
                    Button {
                        analyze()
                    } label: {
                        if isAnalyzing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("正在分析头模…")
                            }
                        } else {
                            Label("分析头模尺寸", systemImage: "ruler")
                        }
                    }
                    .disabled(isAnalyzing || model.objURL == nil)
                    if model.objURL == nil {
                        Text("该模型没有 OBJ 文件，无法自动测量")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let analysisError {
                        Text(analysisError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("导出") {
                ShareLink(item: model.usdzURL, preview: SharePreview("\(model.name).usdz")) {
                    Label("导出 USDZ 模型", systemImage: "cube")
                }
                if let objURL = model.objURL {
                    ShareLink(item: objURL, preview: SharePreview("\(model.name).obj")) {
                        Label("导出 OBJ 模型（Blender 用）", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Text("OBJ 转换失败，仅提供 USDZ（可在 Mac 上用 Reality Converter 转换）")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(model.name)
    }

    private func analyze() {
        guard let objURL = model.objURL else { return }
        isAnalyzing = true
        analysis = nil
        analysisError = nil

        let name = model.name
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    let data = try Data(contentsOf: objURL)
                    let mesh = try OBJParser.parse(data: data)
                    return try HeadMeshAnalyzer.analyze(mesh: mesh, name: name)
                }.value
                analysis = result
            } catch {
                analysisError = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    private func createRecord(from analysis: HeadScanAnalysis) {
        let record = ScanRecord(
            clientName: model.name,
            shellName: "未指定头壳",
            measurements: analysis.measurements()
        )
        modelContext.insert(record)
        recordCreated = true
    }
}

#Preview {
    HeadModelsView()
        .modelContainer(for: [ShellProfile.self, ScanRecord.self, HeadModelScan.self], inMemory: true)
}
