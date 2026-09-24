import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct VideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("kigufit-import-\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

struct PhotoReconstructionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var model = PhotoReconstructionModel()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedVideos: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false

    var body: some View {
        ZStack {
            phaseContent
                .id(stageID)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
        }
        .animation(Motion.smooth, value: stageID)
        .sensoryFeedback(.selection, trigger: stageID)
        .sensoryFeedback(.success, trigger: stageID == "done")
        .navigationTitle("照片重建")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.phase != .done {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .task {
            model.configure(modelContext: modelContext)
        }
    }

    private var pickingView: some View {
        List {
            Section("自扫推荐流程") {
                guideRow("手机固定", detail: "三脚架或支架，高度与头齐平，镜头正对坐姿头部")
                guideRow("Apple Watch 遥控拍摄", detail: "手表相机 App 可实时看画面按快门；每转约 15° 拍一张")
                guideRow("也可以直接录视频", detail: "固定手机录 4K30 / 1080p60 转圈视频（每圈 25–40 秒），App 自动抽帧重建")
                guideRow("转 2–3 圈，每圈换俯仰", detail: "一圈平视、一圈略低头、一圈略抬头，覆盖头顶与下巴")
                guideRow("背景干净", detail: "背后一面纯色墙（白墙最佳），避免杂物；穿深色衣服")
                guideRow("头发压平", detail: "浅色头套 / 泳帽把头发压贴头皮再拍")
            }
            Section("选择素材") {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 80, matching: .images) {
                    Label("从相册选择照片", systemImage: "photo.on.rectangle.angled")
                }
                if !selectedItems.isEmpty {
                    Text("已选 \(selectedItems.count) 张照片")
                        .foregroundStyle(.secondary)
                }
                PhotosPicker(selection: $selectedVideos, maxSelectionCount: 3, matching: .videos) {
                    Label("从相册选择视频（自动抽帧）", systemImage: "video")
                }
                if !selectedVideos.isEmpty {
                    Text("已选 \(selectedVideos.count) 段视频")
                        .foregroundStyle(.secondary)
                }
                Button {
                    loadAndStart()
                } label: {
                    Label("开始重建", systemImage: "wand.and.stars")
                }
                .disabled((selectedItems.isEmpty && selectedVideos.isEmpty) || isLoadingPhotos)
                if isLoadingPhotos {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("正在读取素材…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func guideRow(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func progressView(progress: Double, title: String) -> some View {
        VStack(spacing: 18) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 280)
            Text(title)
                .font(.headline)
            Text("约需 1–3 分钟，请保持 App 在前台")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var doneView: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    SuccessSymbol()
                    Text("重建完成")
                        .font(.headline)
                }
                if let record = model.savedRecord {
                    LabeledContent("名称", value: record.name)
                    LabeledContent("使用照片", value: "\(record.shotCount) 张")
                    ShareLink(item: record.usdzURL, preview: SharePreview("\(record.name).usdz")) {
                        Label("导出 USDZ 模型", systemImage: "cube")
                    }
                    if let objURL = record.objURL {
                        ShareLink(item: objURL, preview: SharePreview("\(record.name).obj")) {
                            Label("导出 OBJ 模型（Blender 用）", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            Section {
                Button("完成") { dismiss() }
            }
        }
    }

    private func failedView(message: String) -> some View {
        List {
            Section {
                Label("重建失败", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("常见原因：照片太少 / 模糊 / 背景杂乱 / 头部在照片中移动。建议在纯色墙前重拍 30 张以上。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("返回") { dismiss() }
            }
        }
    }

    private func loadAndStart() {
        isLoadingPhotos = true
        Task {
            var datas: [Data] = []
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    datas.append(data)
                }
            }
            var urls: [URL] = []
            for item in selectedVideos {
                if let file = try? await item.loadTransferable(type: VideoFile.self) {
                    urls.append(file.url)
                }
            }
            isLoadingPhotos = false
            selectedItems = []
            selectedVideos = []
            model.start(imageData: datas, videoURLs: urls)
        }
    }

    private var stageID: String {
        switch model.phase {
        case .picking: return "picking"
        case .preparing: return "preparing"
        case .reconstructing: return "reconstructing"
        case .done: return "done"
        case .failed: return "failed"
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .picking:
            pickingView
        case .preparing:
            progressView(progress: 0, title: "正在处理照片…")
        case let .reconstructing(progress):
            progressView(progress: progress, title: "机内重建 3D 模型中 \(Int(progress * 100))%")
        case .done:
            doneView
        case let .failed(message):
            failedView(message: message)
        }
    }
}
