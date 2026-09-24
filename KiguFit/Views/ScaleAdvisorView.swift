import SwiftUI

struct ScaleAdvisorView: View {
    let shell: ShellProfilePayload
    let measurements: [MeasurementValue]
    @Environment(\.dismiss) private var dismiss
    @State private var config = ScaleAdvisor.Config()

    var body: some View {
        NavigationStack {
            List {
                Section("海绵配置（拖动调整）") {
                    foamRow("两侧海绵", value: $config.sideFoamMM, range: 0...25)
                    foamRow("顶部海绵", value: $config.topFoamMM, range: 0...30)
                    foamRow("后脑海绵", value: $config.backFoamMM, range: 0...30)
                }

                if let result = ScaleAdvisor.evaluate(shell: shell, measurements: measurements, config: config) {
                    Section("需求对照") {
                        ForEach(result.requirements) { requirement in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(requirement.title)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(requirement.deltaMM <= 0.5 ? "满足" : String(format: "缺 %.1f mm", requirement.deltaMM))
                                        .font(.caption.bold())
                                        .foregroundStyle(color(for: requirement.status))
                                }
                                Text(String(format: "需要 %.1f · 当前 %.1f（%@）", requirement.needMM, requirement.currentMM, requirement.basis))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Section("结论") {
                        if result.uniformScalePercent <= 0.05 {
                            Label("按当前配置，现有内腔已满足加海绵需求", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text(String(format: "建议均匀放大约 %.1f%%", result.uniformScalePercent))
                                .font(.headline)
                            ForEach(result.directions, id: \.self) { direction in
                                Text("• " + direction)
                                    .font(.callout)
                            }
                            Text("提示：定向扩容（只在外侧/后方加量、前脸不动）比均匀缩放更不影响五官外观。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("注意") {
                        ForEach(result.notes, id: \.self) { note in
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "缺少测量数据",
                        systemImage: "ruler",
                        description: Text("请先在记录中补齐头宽、头高、头长等测量值")
                    )
                }
            }
            .navigationTitle("头壳放大试算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func foamRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) mm")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1)
        }
    }

    private func color(for status: ScaleAdvisor.Requirement.Status) -> Color {
        switch status {
        case .satisfied: return .green
        case .marginal: return .orange
        case .insufficient: return .red
        }
    }
}

#Preview {
    ScaleAdvisorView(
        shell: SampleShell.payload,
        measurements: [
            MeasurementValue(key: .headWidth, valueMM: 181.6, source: .scan),
            MeasurementValue(key: .headHeight, valueMM: 240, source: .tape),
            MeasurementValue(key: .headDepth, valueMM: 232.5, source: .tape),
            MeasurementValue(key: .bizygomaticWidth, valueMM: 168.1, source: .scan),
            MeasurementValue(key: .eyeToChin, valueMM: 127.1, source: .scan)
        ]
    )
}
