import SwiftUI
import ARKit

struct ScanGuidanceView: View {
    let session: FaceScanSession
    let onFinished: () -> Void
    let onSkip: () -> Void
    @State private var didHandleFinish = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            statusIcon
            statusText
            if case let .collecting(captured, target) = session.state {
                progressRing(captured: captured, target: target)
            }
            tips
            Spacer()
            footerButtons
        }
        .padding()
        .onChange(of: session.state) { _, newValue in
            if case .finished = newValue, !didHandleFinish {
                didHandleFinish = true
                onFinished()
            }
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch session.state {
        case .unsupported:
            Image(systemName: "iphone.slash").font(.system(size: 52)).foregroundStyle(.orange)
        case .unauthorized:
            Image(systemName: "camera.fill").font(.system(size: 52)).foregroundStyle(.orange)
        case .failed:
            Image(systemName: "exclamationmark.triangle").font(.system(size: 52)).foregroundStyle(.red)
        case .finished:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(.green)
        default:
            Image(systemName: "faceid").font(.system(size: 52)).foregroundStyle(.blue)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch session.state {
        case .idle, .running:
            Text("正在启动扫描…").font(.headline)
        case .collecting:
            Text("采集中，请保持头部不动").font(.headline)
        case .finished:
            Text("采集完成").font(.headline)
        case .unsupported:
            VStack(spacing: 8) {
                Text("此设备不支持 TrueDepth 扫描").font(.headline)
                Text("需要带 Face ID 的 iPhone；可跳过扫描仅用软尺数据。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .unauthorized:
            VStack(spacing: 8) {
                Text("相机权限未开启").font(.headline)
                Text("请到系统设置中允许 KiguFit 使用相机；也可跳过扫描。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case let .failed(message):
            Text(message).font(.headline)
        }
    }

    private func progressRing(captured: Int, target: Int) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                .frame(width: 160, height: 160)
            Circle()
                .trim(from: 0, to: Double(captured) / Double(max(target, 1)))
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 160, height: 160)
            Text("\(captured)/\(target)")
                .font(.title2.monospacedDigit())
        }
        .animation(.easeOut(duration: 0.15), value: captured)
    }

    private var tips: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("手机与脸保持 30–50cm", systemImage: "ruler")
            Label("正对屏幕，光线均匀", systemImage: "sun.max")
            Label("表情自然、睁眼、嘴自然闭合", systemImage: "face.smiling")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var footerButtons: some View {
        VStack(spacing: 12) {
            if case .collecting = session.state {
                Button("重新开始") {
                    didHandleFinish = false
                    session.cancel()
                    session.start()
                }
                .buttonStyle(.bordered)
            }
            Button("跳过扫描，仅手动测量") {
                onSkip()
            }
            .font(.footnote)
        }
    }
}
