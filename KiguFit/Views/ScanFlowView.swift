import SwiftUI
import SwiftData

@MainActor
@Observable
final class ScanFlowModel {
    enum Step: Int, CaseIterable {
        case setup
        case scan
        case manual
        case summary
        case report
    }

    var step: Step = .setup
    var clientName: String = ""
    var selectedShell: ShellProfile?
    var manualEntries: [MeasurementKey: Double] = [:]
    var scanMeasurements: [MeasurementValue] = []
    var previewMeasurements: [MeasurementValue] = []
    var verdict: FitVerdict?
    var savedRecord: ScanRecord?
    var scanSkipped = false

    let scanSession = FaceScanSession()

    var selectedShellPayload: ShellProfilePayload? {
        selectedShell?.payload
    }

    func beginScan() {
        scanMeasurements = []
        scanSkipped = false
        step = .scan
        scanSession.start()
    }

    func skipScan() {
        scanSkipped = true
        scanSession.cancel()
        step = .manual
    }

    func handleScanFinished() {
        guard let capture = scanSession.result else { return }
        scanMeasurements = MeasurementEngine.measurements(from: capture)
        step = .manual
    }

    func buildPreview() {
        var merged: [MeasurementKey: MeasurementValue] = [:]
        for value in scanMeasurements {
            merged[value.key] = value
        }
        for (key, numeric) in manualEntries {
            merged[key] = MeasurementValue(key: key, valueMM: numeric, source: .tape, confidence: 1.0)
        }
        previewMeasurements = HeadEstimator.complete(Array(merged.values))
            .sorted { $0.key.rawValue < $1.key.rawValue }
        step = .summary
    }

    func generateReport(modelContext: ModelContext) {
        if let shell = selectedShellPayload {
            verdict = FitEngine.evaluate(shell: shell, measurements: previewMeasurements)
        } else {
            verdict = nil
        }

        let record = ScanRecord(
            clientName: clientName.trimmingCharacters(in: .whitespacesAndNewlines),
            shellName: selectedShell?.name ?? "未指定头壳",
            shellPayloadData: selectedShell?.payloadData,
            measurements: previewMeasurements
        )
        record.verdict = verdict
        if let capture = scanSession.result {
            record.meshData = FaceMeshCodec.encode(capture)
        }
        modelContext.insert(record)
        savedRecord = record
        step = .report
    }
}

struct ScanFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ShellProfile.createdAt) private var shells: [ShellProfile]
    @State private var model = ScanFlowModel()

    var body: some View {
        NavigationStack {
            Group {
                switch model.step {
                case .setup:
                    setupView
                case .scan:
                    ScanGuidanceView(
                        session: model.scanSession,
                        onFinished: model.handleScanFinished,
                        onSkip: model.skipScan
                    )
                case .manual:
                    ManualEntryView(
                        initialEntries: model.manualEntries,
                        scanSkipped: model.scanSkipped,
                        onContinue: { entries in
                            model.manualEntries = entries
                            model.buildPreview()
                        },
                        onBack: { model.step = .scan }
                    )
                case .summary:
                    ScanSummaryView(
                        measurements: model.previewMeasurements,
                        hasShell: model.selectedShell != nil,
                        onGenerate: { model.generateReport(modelContext: modelContext) },
                        onBack: { model.step = .manual }
                    )
                case .report:
                    if let record = model.savedRecord {
                        ReportView(record: record, embedded: true, onDone: { dismiss() })
                    } else {
                        ContentUnavailableView("生成失败", systemImage: "exclamationmark.triangle")
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.step != .report {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            model.scanSession.cancel()
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private var navigationTitle: String {
        switch model.step {
        case .setup: return "新建测量"
        case .scan: return "3D 扫描"
        case .manual: return "软尺测量"
        case .summary: return "测量总览"
        case .report: return "适配报告"
        }
    }

    private var setupView: some View {
        Form {
            Section("客户") {
                TextField("客户代号（可选）", text: $model.clientName)
            }
            Section("头壳档案") {
                if shells.isEmpty {
                    Text("暂无头壳档案，可在「头壳」页添加内置示例")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("选择头壳", selection: $model.selectedShell) {
                        Text("不指定").tag(ShellProfile?.none)
                        ForEach(shells) { shell in
                            Text(shell.name).tag(ShellProfile?.some(shell))
                        }
                    }
                }
            }
            Section {
                Button {
                    model.beginScan()
                } label: {
                    Label("开始 3D 扫描", systemImage: "faceid")
                }
            } footer: {
                Text("将手机置于面前 30–50cm，正对屏幕；不支持 TrueDepth 的设备可跳过扫描、仅用软尺数据。")
            }
        }
    }
}

#Preview {
    ScanFlowView()
        .modelContainer(for: [ShellProfile.self, ScanRecord.self], inMemory: true)
}
