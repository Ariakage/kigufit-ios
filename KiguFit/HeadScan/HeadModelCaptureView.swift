import RealityKit
import SwiftData
import SwiftUI

struct HeadModelCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var model = HeadModelCaptureModel()
    @State private var captureState: ObjectCaptureSession.CaptureState = .initializing
    @State private var isPrepared = false

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
        .navigationTitle("扫描头模")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.phase != .done {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        model.cancelAndCleanup()
                        dismiss()
                    }
                }
            }
        }
        .task {
            model.configure(modelContext: modelContext)
        }
    }

    private var preparationView: some View {
        List {
            Section("扫描前准备") {
                preparationRow("头发用浅色头套 / 泳帽压平", detail: "黑发、染深色、油亮发质会严重干扰 LiDAR；长发先盘起再戴帽")
                preparationRow("必要时取下眼镜、耳饰", detail: "避免扫描时反光与遮挡")
                preparationRow("光线要充足", detail: "摄影测量对环境光要求高：开顶灯 / 加补光灯；提示「环境光偏弱」时若不补光，模型容易出空洞")
                preparationRow("扫描对象保持不动", detail: "扫真人时请他人持手机绕行，头部不要转动")
                preparationRow("绕 2–3 圈效果更好", detail: "每完成一圈点「再绕一圈」补采；能翻面的物体可翻面扫")
            }
            Section("为什么") {
                Text("头壳佩戴时头发是压平状态（还要垫海绵），所以扫描也应在压发状态进行，尺寸才对应真实佩戴。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    isPrepared = true
                } label: {
                    Label("准备就绪，开始扫描", systemImage: "lidar.scanner")
                }
            }
        }
    }

    private func preparationRow(_ title: String, detail: String) -> some View {
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

    private var unsupportedView: some View {
        ContentUnavailableView(
            "此设备不支持 LiDAR 扫描",
            systemImage: "lidar.scanner",
            description: Text("头模扫描需要带 LiDAR 的 iPhone Pro 机型（如 iPhone 16 Pro）。记录页的面部扫描不受影响。")
        )
    }

    @ViewBuilder
    private var captureView: some View {
        if let session = model.session {
            ObjectCaptureView(session: session) {
                VStack(spacing: 0) {
                    Spacer()
                    statusPill
                    controls(session: session)
                }
                .padding()
            }
            .ignoresSafeArea()
            .onAppear {
                model.startSession()
            }
            .task {
                for await state in session.stateUpdates {
                    captureState = state
                    model.handleStateChange(state)
                }
            }
            .task {
                for await feedback in session.feedbackUpdates {
                    model.updateFeedback(feedback)
                }
            }
            .task {
                for await completed in session.userCompletedScanPassUpdates {
                    model.updateUserCompletedScanPass(completed)
                }
            }
            .task {
                for await shots in session.numberOfShotsTakenUpdates {
                    model.updateShotCount(shots)
                }
            }
        }
    }

    private var statusPill: some View {
        VStack(spacing: 5) {
            Text(stateText)
                .font(.subheadline.weight(.semibold))
            if !model.feedbackMessages.isEmpty {
                Text(model.feedbackMessages.prefix(2).joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 6)
    }

    private var stateText: String {
        switch captureState {
        case .initializing: return "初始化相机…"
        case .ready: return "对准头模，准备开始"
        case .detecting: return "正在识别头模…"
        case .capturing:
            return model.userCompletedScanPass ? "本圈完成，可翻转继续或结束" : "绕头模缓慢移动（已拍 \(model.numberOfShots) 张）"
        case .finishing: return "正在收尾…"
        case .completed: return "采集完成"
        case .failed: return "采集失败"
        @unknown default: return "请按屏幕提示操作"
        }
    }

    @ViewBuilder
    private func controls(session: ObjectCaptureSession) -> some View {
        VStack(spacing: 10) {
            switch captureState {
            case .ready:
                Button {
                    model.beginCapturing()
                } label: {
                    Label("开始拍摄", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            case .capturing:
                if model.userCompletedScanPass {
                    Button {
                        model.beginAnotherPass()
                    } label: {
                        Label("再绕一圈", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        model.continueAfterFlip()
                    } label: {
                        Label("已翻面，继续扫描", systemImage: "arrow.uturn.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    Button {
                        model.finishCapture()
                    } label: {
                        Label("完成扫描", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            default:
                EmptyView()
            }
        }
    }

    private func reconstructingView(progress: Double) -> some View {
        VStack(spacing: 18) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 280)
            Text("机内重建 3D 模型中 \(Int(progress * 100))%")
                .font(.headline)
            Text("约需 1–3 分钟，请保持 App 在前台")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func doneView() -> some View {
        List {
            Section {
                HStack(spacing: 8) {
                    SuccessSymbol()
                    Text("扫描完成")
                        .font(.headline)
                }
                if let record = model.savedRecord {
                    LabeledContent("名称", value: record.name)
                    LabeledContent("拍摄张数", value: "\(record.shotCount)")
                    let usdz = record.usdzURL
                    ShareLink(item: usdz, preview: SharePreview("\(record.name).usdz")) {
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
        ContentUnavailableView(
            "扫描失败",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
    }

    private var stageID: String {
        switch model.phase {
        case .unsupported: return "unsupported"
        case .preparing: return isPrepared ? "capturing" : "preparing"
        case .capturing: return "capturing"
        case .reconstructing: return "reconstructing"
        case .done: return "done"
        case .failed: return "failed"
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .unsupported:
            unsupportedView
        case .preparing, .capturing:
            if isPrepared {
                captureView
            } else {
                preparationView
            }
        case let .reconstructing(progress):
            reconstructingView(progress: progress)
        case .done:
            doneView()
        case let .failed(message):
            failedView(message: message)
        }
    }
}
