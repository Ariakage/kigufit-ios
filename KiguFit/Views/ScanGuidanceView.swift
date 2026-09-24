import SwiftUI
import UIKit

struct ScanGuidanceView: View {
    let session: FaceScanSession
    let onFinished: () -> Void
    let onSkip: () -> Void

    @State private var didHandleFinish = false
    @State private var isPrepared = false

    var body: some View {
        Group {
            if isPrepared {
                guidanceContent
            } else {
                preparationView
            }
        }
        .onChange(of: session.state) { _, newValue in
            if case .finished = newValue, !didHandleFinish {
                didHandleFinish = true
                onFinished()
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var preparationView: some View {
        List {
            Section("扫描前准备") {
                checklistRow("取下眼镜 / 墨镜", detail: "镜框与镜片会影响面部网格拟合")
                checklistRow("撩起刘海与碎发", detail: "露出额头与发际线，避免遮挡")
                checklistRow("取下口罩、耳饰、帽子", detail: "任何遮挡物都会影响测量精度")
                checklistRow("面朝均匀光源", detail: "避免背光或单侧强光造成阴影")
            }
            Section("扫描流程") {
                Text("将依次采集 5 个姿势：正视 → 左转 → 右转 → 抬头 → 低头。每个姿势保持约 2–3 秒，屏幕会实时提示转向角度，全程约 30–60 秒。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button {
                    session.start()
                    isPrepared = true
                } label: {
                    Label("准备就绪，开始扫描", systemImage: "faceid")
                }
                Button {
                    onSkip()
                } label: {
                    Label("跳过扫描，仅手动测量", systemImage: "hand.raised")
                }
                .font(.footnote)
            }
        }
    }

    private func checklistRow(_ title: String, detail: String) -> some View {
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

    private var guidanceContent: some View {
        VStack(spacing: 22) {
            poseProgressRow
            Spacer()
            switch session.state {
            case .unsupported:
                messageBlock(
                    icon: "iphone.slash",
                    title: "此设备不支持 TrueDepth 扫描",
                    detail: "需要带 Face ID 的 iPhone；可跳过扫描仅用软尺数据。"
                )
            case .unauthorized:
                messageBlock(
                    icon: "camera.fill",
                    title: "相机权限未开启",
                    detail: "请到系统设置中允许 KiguFit 使用相机；也可跳过扫描。"
                )
            case let .failed(message):
                messageBlock(icon: "exclamationmark.triangle", title: message, detail: "")
            default:
                poseGuide
            }
            Spacer()
            footerButtons
        }
        .padding()
    }

    private var poseProgressRow: some View {
        HStack(spacing: 14) {
            ForEach(session.poses) { pose in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(poseState(pose).color.opacity(0.18))
                            .frame(width: 34, height: 34)
                        if poseState(pose) == .done {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: pose.systemImage)
                                .font(.system(size: 13))
                                .foregroundStyle(poseState(pose).color)
                        }
                    }
                    Text(pose.title)
                        .font(.system(size: 10))
                        .foregroundStyle(poseState(pose) == .current ? .primary : .secondary)
                }
            }
        }
        .animation(Motion.snappy, value: session.currentPose)
    }

    private enum PoseUIState {
        case done
        case current
        case pending

        var color: Color {
            switch self {
            case .done: return .green
            case .current: return .blue
            case .pending: return .gray
            }
        }
    }

    private func poseState(_ pose: ScanPose) -> PoseUIState {
        guard let current = session.currentPose else { return .done }
        guard let currentIndex = session.poses.firstIndex(of: current),
              let index = session.poses.firstIndex(of: pose) else { return .pending }
        if index < currentIndex { return .done }
        if index == currentIndex { return .current }
        return .pending
    }

    private var poseGuide: some View {
        VStack(spacing: 16) {
            if let pose = session.currentPose {
                Image(systemName: pose.systemImage)
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(session.isPoseSatisfied ? .green : .blue)
                    .symbolEffect(.pulse, options: .repeating)
                    .contentTransition(.symbolEffect(.replace))
                Text(pose.title)
                    .font(.title2.bold())
                Text(pose.instruction)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if case let .collecting(_, collected, target) = session.state {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                            .frame(width: 110, height: 110)
                        Circle()
                            .trim(from: 0, to: Double(collected) / Double(max(target, 1)))
                            .stroke(session.isPoseSatisfied ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 110, height: 110)
                        Text("\(collected)/\(target)")
                            .font(.title3.monospacedDigit())
                    }
                    .animation(Motion.snappy, value: collected)
                }

                Text(session.feedback)
                    .font(.headline)
                    .foregroundStyle(session.isPoseSatisfied ? .green : .orange)
                    .contentTransition(.interpolate)
                    .animation(Motion.snappy, value: session.feedback)

                Text(String(format: "偏转 %.0f° · 俯仰 %.0f°", session.liveYaw, session.livePitch))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func messageBlock(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if !detail.isEmpty {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var footerButtons: some View {
        VStack(spacing: 12) {
            switch session.state {
            case .collecting, .running:
                Button {
                    didHandleFinish = false
                    session.cancel()
                    session.start()
                } label: {
                    Label("重新开始", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            default:
                EmptyView()
            }
            Button("跳过扫描，仅手动测量") {
                onSkip()
            }
            .font(.footnote)
        }
    }
}
