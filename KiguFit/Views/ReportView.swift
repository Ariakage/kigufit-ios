import SwiftUI
import SwiftData

struct ReportView: View {
    let record: ScanRecord
    var embedded = false
    var onDone: (() -> Void)?

    @State private var pdfURL: URL?
    @State private var jsonURL: URL?

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
            if embedded, let onDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { onDone() }
                }
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
            } else {
                Text("P3 阶段接入（BYOK），届时可一键生成自然语言解读并写入 PDF。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
    .modelContainer(for: [ShellProfile.self, ScanRecord.self], inMemory: true)
}
