import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShellsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShellProfile.createdAt) private var shells: [ShellProfile]
    @State private var isShowingImporter = false
    @State private var importError: String?
    @State private var isShowingOBJImporter = false
    @State private var analyzer = ShellAnalyzerModel()

    var body: some View {
        NavigationStack {
            Group {
                if shells.isEmpty {
                    ContentUnavailableView(
                        "暂无头壳档案",
                        systemImage: "cube",
                        description: Text("可添加内置示例，或导入 kigufit.shell/v1 JSON 档案")
                    )
                } else {
                    List {
                        ForEach(shells) { shell in
                            NavigationLink {
                                ShellDetailView(shell: shell)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(shell.name).font(.headline)
                                    Text(shell.outerSummary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .onDelete(perform: deleteShells)
                    }
                }
            }
            .navigationTitle("头壳档案")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            addSampleShell()
                        } label: {
                            Label("添加内置示例", systemImage: "cube")
                        }
                        Button {
                            isShowingImporter = true
                        } label: {
                            Label("导入 JSON 档案", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            isShowingOBJImporter = true
                        } label: {
                            Label("分析 OBJ 生成档案", systemImage: "wand.and.stars")
                        }
                    } label: {
                        Label("添加", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .fileImporter(
                isPresented: $isShowingOBJImporter,
                allowedContentTypes: [UTType(filenameExtension: "obj") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                if case let .success(urls) = result, let url = urls.first {
                    analyzer.analyze(url: url)
                }
            }
            .overlay {
                if analyzer.isAnalyzing {
                    ZStack {
                        Color.black.opacity(0.12).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("正在分析 OBJ 网格…")
                                .font(.callout)
                        }
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { analyzer.preview != nil },
                set: { if !$0 { analyzer.clearPreview() } }
            )) {
                if let preview = analyzer.preview {
                    ShellAnalysisPreviewView(analysis: preview) { name in
                        saveAnalysis(preview, name: name)
                    }
                }
            }
            .alert(
                "分析失败",
                isPresented: Binding(
                    get: { analyzer.errorMessage != nil },
                    set: { if !$0 { analyzer.errorMessage = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(analyzer.errorMessage ?? "")
            }
            .alert(
                "导入失败",
                isPresented: Binding(
                    get: { importError != nil },
                    set: { if !$0 { importError = nil } }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func addSampleShell() {
        withAnimation {
            modelContext.insert(ShellProfile(payload: SampleShell.payload))
        }
    }

    private func saveAnalysis(_ analysis: ShellAnalysis, name: String) {
        var payload = analysis.payload(sourceFile: analysis.sourceFile)
        payload.name = name
        modelContext.insert(ShellProfile(payload: payload, sourceFileName: analysis.sourceFile))
    }

    private func deleteShells(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(shells[index])
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            var imported = 0
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer {
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }
                let data = try Data(contentsOf: url)
                let payload = try ShellProfilePayload.decode(from: data)
                let sourceName = payload.source?.file ?? url.deletingPathExtension().lastPathComponent
                modelContext.insert(ShellProfile(payload: payload, sourceFileName: sourceName))
                imported += 1
            }
            if imported == 0 {
                importError = "未找到有效的 kigufit.shell/v1 档案"
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}

struct ShellDetailView: View {
    let shell: ShellProfile
    @State private var exportURL: URL?
    @State private var isRenaming = false
    @State private var newName = ""

    var body: some View {
        List {
            if let payload = shell.payload {
                profileSection(payload)
                Section("外形尺寸") {
                    LabeledContent("宽", value: mm(payload.outer.width))
                    LabeledContent("深", value: mm(payload.outer.depth))
                    LabeledContent("高", value: mm(payload.outer.height))
                }
                Section("内腔") {
                    LabeledContent("内高", value: mm(payload.inner.height))
                    if let thickness = payload.inner.wallThickness {
                        LabeledContent("壁厚", value: mm(thickness))
                    }
                    if let bowl = payload.inner.faceBowlWidth {
                        LabeledContent("脸碗内宽", value: mm(bowl))
                    }
                    if let bandWidth = payload.inner.bandWidth() {
                        LabeledContent("头带高度内宽", value: mm(bandWidth))
                    }
                }
                if let eyeHoles = payload.eyeHoles {
                    Section("眼孔") {
                        LabeledContent("单孔尺寸", value: String(format: "%.0f×%.0f mm", eyeHoles.width, eyeHoles.height))
                        LabeledContent("中心距", value: mm(eyeHoles.centerSpacing))
                        LabeledContent("高于内底", value: mm(eyeHoles.centerAboveInnerBottom))
                    }
                }
                if let fit = payload.fit {
                    Section("适配参考") {
                        if let range = fit.headCircumferenceRange, range.count == 2 {
                            LabeledContent("建议头围", value: String(format: "%.0f – %.0f mm", range[0], range[1]))
                        }
                        if let notes = fit.notes {
                            Text(notes).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("来源") {
                    LabeledContent("文件", value: payload.source?.file ?? "未标注")
                    if let notes = payload.notes {
                        Text(notes).font(.callout).foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView("档案数据无效", systemImage: "exclamationmark.triangle")
            }

            Section("导出") {
                if let exportURL {
                    ShareLink(item: exportURL, preview: SharePreview("\(shell.name).json")) {
                        Label("导出 JSON 档案", systemImage: "square.and.arrow.up")
                    }
                } else {
                    HStack {
                        ProgressView()
                        Text("正在生成导出文件…").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(shell.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("重命名") {
                    newName = shell.name
                    isRenaming = true
                }
            }
        }
        .alert("重命名头壳", isPresented: $isRenaming) {
            TextField("名称", text: $newName)
            Button("保存") {
                shell.rename(to: newName)
            }
            Button("取消", role: .cancel) {}
        }
        .task {
            generateExport()
        }
    }

    @ViewBuilder
    private func profileSection(_ payload: ShellProfilePayload) -> some View {
        let points = payload.inner.widthProfile.sorted { $0.z < $1.z }
        if points.count >= 2 {
            Section("内腔宽度剖面") {
                Canvas { context, size in
                    let minZ = points.first?.z ?? 0
                    let maxZ = points.last?.z ?? 1
                    let widths = points.map(\.width)
                    let minW = widths.min() ?? 0
                    let maxW = widths.max() ?? 1
                    let spanZ = max(maxZ - minZ, 1)
                    let spanW = max(maxW - minW, 1)

                    var path = Path()
                    for (index, point) in points.enumerated() {
                        let x = CGFloat((point.z - minZ) / spanZ) * size.width
                        let y = size.height - CGFloat((point.width - minW) / spanW) * (size.height - 12) - 6
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(path, with: .color(.blue), lineWidth: 2)
                }
                .frame(height: 120)
                .padding(.vertical, 4)
                Text("横轴：内底→顶部  纵轴：内腔宽度（左窄右宽）")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func generateExport() {
        guard let payload = shell.payload, let data = try? payload.encoded() else { return }
        let name = ExportService.sanitizedFilename(shell.name)
        exportURL = ExportService.writeTempFile(data, filename: "KiguFit-shell-\(name).json")
    }

    private func mm(_ value: Double) -> String {
        String(format: "%.1f mm", value)
    }
}

#Preview {
    ShellsView()
        .modelContainer(for: [ShellProfile.self, ScanRecord.self], inMemory: true)
}
