import SwiftUI
import SwiftData

struct ShellsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShellProfile.createdAt) private var shells: [ShellProfile]

    var body: some View {
        NavigationStack {
            Group {
                if shells.isEmpty {
                    ContentUnavailableView(
                        "暂无头壳档案",
                        systemImage: "cube",
                        description: Text("点击右上角 + 添加头壳（暂提供内置示例）")
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
                    Button {
                        addSampleShell()
                    } label: {
                        Label("添加示例头壳", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addSampleShell() {
        withAnimation {
            modelContext.insert(ShellProfile(payload: SampleShell.payload))
        }
    }

    private func deleteShells(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(shells[index])
            }
        }
    }
}

struct ShellDetailView: View {
    let shell: ShellProfile

    var body: some View {
        List {
            if let payload = shell.payload {
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
                    if let bandWidth = payload.inner.innerWidth(nearest: 20) {
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
        }
        .navigationTitle(shell.name)
    }

    private func mm(_ value: Double) -> String {
        String(format: "%.1f mm", value)
    }
}

#Preview {
    ShellsView()
        .modelContainer(for: [ShellProfile.self, ScanRecord.self], inMemory: true)
}
