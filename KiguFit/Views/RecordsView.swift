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
                                ReportView(record: record)
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
                ScanFlowView()
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

#Preview {
    RecordsView()
        .modelContainer(for: [ShellProfile.self, ScanRecord.self], inMemory: true)
}
