import SwiftUI
import SwiftData

struct ReportView: View {
    let record: ScanRecord
    var embedded = false
    var onDone: (() -> Void)?

    @State private var pdfURL: URL?
    @State private var jsonURL: URL?
    @State private var isEditingMeasurements = false
    @State private var isRenamingClient = false
    @State private var newClientName = ""
    @State private var isShowingScaleAdvisor = false
    @State private var isGeneratingAI = false
    @State private var aiError: String?
    @Environment(AISettings.self) private var aiSettings

    private var tapeEntries: [MeasurementKey: Double] {
        Dictionary(
            uniqueKeysWithValues: record.measurements
                .filter { $0.source == .tape }
                .map { ($0.key, $0.valueMM) }
        )
    }

    private var grouped: [(source: MeasurementSource, values: [MeasurementValue])] {
        let ordered: [MeasurementSource] = [.scan, .tape, .estimated]
        return ordered.compactMap { source in
            let values = record.measurements.filter { $0.source == source }
            return values.isEmpty ? nil : (source, values)
        }
    }

    var body: some View {
        List {
            verdictSection
            overlaySection
            if let verdict = record.verdict {
                if !verdict.checks.isEmpty {
                    Section("对照明细") {
                        ForEach(verdict.checks, id: \.title) { check in
                            CheckRow(check: check)
                        }
                    }
                }
                if !verdict.suggestions.isEmpty {
                    Section("建议") {
                        ForEach(verdict.suggestions, id: \.detail) { suggestion in
                            Label(suggestion.detail, systemImage: icon(for: suggestion.kind))
                                .font(.callout)
                        }
                    }
                }
            }
            measurementsSection
            exportSection
            aiSection
        }
        .navigationTitle("适配报告")
        .toolbar {
            if !embedded {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            isEditingMeasurements = true
                        } label: {
                            Label("编辑测量值", systemImage: "ruler")
                        }
                        Button {
                            newClientName = record.clientName
                            isRenamingClient = true
                        } label: {
                            Label("重命名客户", systemImage: "person.text.rectangle")
                        }
                        if record.shellPayload != nil {
                            Button {
                                isShowingScaleAdvisor = true
                            } label: {
                                Label("头壳放大试算", systemImage: "arrow.up.left.and.arrow.down.right")
                            }
                        }
                    } label: {
                        Text("编辑")
                    }
                }
            }
            if embedded, let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { onDone() }
                }
            }
        }
        .alert("重命名客户", isPresented: $isRenamingClient) {
            TextField("客户代号", text: $newClientName)
            Button("保存") {
                record.clientName = newClientName.trimmingCharacters(in: .whitespacesAndNewlines)
                generateExports()
            }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $isEditingMeasurements) {
            NavigationStack {
                ManualEntryView(
                    initialEntries: tapeEntries,
                    scanSkipped: false,
                    onContinue: { entries in
                        saveEdits(entries)
                        isEditingMeasurements = false
                    },
                    onBack: {
                        isEditingMeasurements = false
                    }
                )
                .navigationTitle("编辑测量值")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $isShowingScaleAdvisor) {
            if let payload = record.shellPayload {
                ScaleAdvisorView(shell: payload, measurements: record.measurements)
            }
        }
        .task {
            generateExports()
        }
    }

    @ViewBuilder
    private var verdictSection: some View {
        Section("结论") {
            if let verdict = record.verdict {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VerdictBadge(level: verdict.level)
                        Spacer()
                    }
                    Text(verdict.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } else {
                Text("未选择头壳档案，未生成适配结论")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var overlaySection: some View {
        if let headWidth = record.measurements.value(for: .headWidth)?.valueMM,
           let headDepth = record.measurements.value(for: .headDepth)?.valueMM,
           let shell = record.shellPayload,
           let shellWidth = shell.inner.bandWidth(),
           let shellDepth = shell.inner.bandDepth() {
            Section("俯视对照（示意）") {
                FitOverlayChart(
                    headWidth: headWidth,
                    headDepth: headDepth,
                    shellWidth: shellWidth,
                    shellDepth: shellDepth
                )
                .padding(.vertical, 4)
                Text(String(format: "蓝=头部 %.0f×%.0f mm ｜ 灰=头壳内腔 %.0f×%.0f mm（宽×深，头带高度）", headWidth, headDepth, shellWidth, shellDepth))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var measurementsSection: some View {
        ForEach(grouped, id: \.source) { group in
            Section("\(group.source.displayName)（\(group.values.count)）") {
                ForEach(group.values) { value in
                    LabeledContent(value.key.displayName) {
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f mm", value.valueMM))
                                .monospacedDigit()
                            Text(String(format: "%.2f", value.confidence))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private var exportSection: some View {
        Section("导出") {
            if let pdfURL {
                ShareLink(item: pdfURL, preview: SharePreview("KiguFit 报告.pdf")) {
                    Label("导出 PDF 报告（三方通用）", systemImage: "doc.richtext")
                }
            }
            if let jsonURL {
                ShareLink(item: jsonURL, preview: SharePreview("测量数据.json")) {
                    Label("导出 JSON 数据", systemImage: "curlybraces")
                }
            }
            if pdfURL == nil && jsonURL == nil {
                HStack {
                    ProgressView()
                    Text("正在生成导出文件…").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var aiSection: some View {
        Section("AI 解读") {
            if let narrative = record.aiNarrative, !narrative.isEmpty {
                Text(narrative)
                Button {
                    generateAI()
                } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                }
                .disabled(!aiSettings.isConfigured || isGeneratingAI)
            } else {
                Button {
                    generateAI()
                } label: {
                    Label("生成 AI 解读", systemImage: "sparkles")
                }
                .disabled(!aiSettings.isConfigured || isGeneratingAI)
                if !aiSettings.isConfigured {
                    Text("请先在「设置 → AI 解读（BYOK）」里配置 API Key")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if isGeneratingAI {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在生成解读…")
                        .foregroundStyle(.secondary)
                }
            }
            if let aiError {
                Text(aiError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private func generateAI() {
        guard aiSettings.isConfigured else { return }
        isGeneratingAI = true
        aiError = nil
        let context = AIPipeline.context(from: record)
        let messages = AIPipeline.recordMessages(context: context)
        let client = LLMClient(
            baseURL: aiSettings.baseURL,
            apiKey: aiSettings.apiKey,
            model: aiSettings.model
        )
        Task {
            do {
                let narrative = try await client.complete(messages: messages)
                record.aiNarrative = narrative
                generateExports()
            } catch {
                aiError = error.localizedDescription
            }
            isGeneratingAI = false
        }
    }

    private func icon(for kind: FitVerdict.Suggestion.Kind) -> String {
        switch kind {
        case .padding: return "square.fill.on.square.fill"
        case .scale: return "arrow.up.left.and.arrow.down.right"
        case .note: return "info.circle"
        }
    }

    private func generateExports() {
        let basename = ExportService.sanitizedFilename(record.clientName)
        let pdfData = ReportPDFRenderer.renderPDF(record: record)
        pdfURL = ExportService.writeTempFile(pdfData, filename: "KiguFit-\(basename).pdf")
        if let jsonData = ExportService.scanJSON(record: record) {
            jsonURL = ExportService.writeTempFile(jsonData, filename: "KiguFit-\(basename).json")
        }
    }

    private func saveEdits(_ entries: [MeasurementKey: Double]) {
        var merged: [MeasurementKey: MeasurementValue] = [:]
        for value in record.measurements where value.source == .scan {
            merged[value.key] = value
        }
        for (key, numeric) in entries {
            merged[key] = MeasurementValue(key: key, valueMM: numeric, source: .tape, confidence: 1.0)
        }
        let completed = HeadEstimator.complete(Array(merged.values))
            .sorted { $0.key.rawValue < $1.key.rawValue }
        record.measurements = completed
        if let payload = record.shellPayload {
            record.verdict = FitEngine.evaluate(shell: payload, measurements: completed)
        }
        generateExports()
    }
}

struct CheckRow: View {
    let check: FitVerdict.Check

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(check.title)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let margin = check.marginMM {
                    Text(String(format: "余量 %.1f mm", margin))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(check.status.displayName)
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
            }
            Text(check.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        switch check.status {
        case .ok: return .green
        case .warn: return .orange
        case .fail: return .red
        }
    }
}

#Preview {
    NavigationStack {
        ReportView(record: ScanRecord(clientName: "示例客户", shellName: "示例头壳"))
    }
    .environment(AISettings())
    .modelContainer(for: [ShellProfile.self, ScanRecord.self], inMemory: true)
}
