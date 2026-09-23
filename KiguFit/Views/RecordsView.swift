import SwiftUI
import SwiftData

struct RecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScanRecord.createdAt, order: .reverse) private var records: [ScanRecord]
    @State private var isShowingNewRecord = false

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "暂无测量记录",
                        systemImage: "person.text.rectangle",
                        description: Text("点击右上角 + 开始一次测量")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            NavigationLink {
                                RecordOverviewView(record: record)
                            } label: {
                                RecordRow(record: record)
                            }
                        }
                        .onDelete(perform: deleteRecords)
                    }
                }
            }
            .navigationTitle("记录")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingNewRecord = true
                    } label: {
                        Label("新建测量", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewRecord) {
                NewRecordPlaceholderView()
            }
        }
    }

    private func deleteRecords(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(records[index])
            }
        }
    }
}

private struct RecordRow: View {
    let record: ScanRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.clientName.isEmpty ? "未命名" : record.clientName)
                    .font(.headline)
                Spacer()
                if let verdict = record.verdict {
                    VerdictBadge(level: verdict.level)
                }
            }
            Text(record.shellName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(record.createdAt, format: Date.FormatStyle(date: .numeric, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct VerdictBadge: View {
    let level: FitVerdict.Level

    var body: some View {
        Text(level.displayName)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor.opacity(0.18), in: Capsule())
            .foregroundStyle(backgroundColor)
    }

    private var backgroundColor: Color {
        switch level {
        case .good: return .green
        case .tight: return .orange
        case .loose: return .blue
        case .unfit: return .red
        }
    }
}

private struct RecordOverviewView: View {
    let record: ScanRecord

    var body: some View {
        List {
            Section("客户") {
                LabeledContent("代号", value: record.clientName.isEmpty ? "未命名" : record.clientName)
                LabeledContent("头壳", value: record.shellName)
                LabeledContent("时间", value: record.createdAt.formatted(date: .numeric, time: .shortened))
            }
            if let verdict = record.verdict {
                Section("结论") {
                    HStack {
                        VerdictBadge(level: verdict.level)
                        Text(verdict.summary)
                    }
                }
            }
            Section("测量值") {
                ForEach(record.measurements) { measurement in
                    LabeledContent(measurement.key.displayName) {
                        HStack(spacing: 6) {
                            Text(String(format: "%.1f mm", measurement.valueMM))
                            Text(measurement.source.displayName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .navigationTitle("测量详情")
    }
}

private struct NewRecordPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "扫描向导开发中",
                systemImage: "arkit",
                description: Text("下一次提交将接入 TrueDepth 扫描与手动测量流程")
            )
            .navigationTitle("新建测量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RecordsView()
        .modelContainer(for: [ShellProfile.self, ScanRecord.self], inMemory: true)
}
