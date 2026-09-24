import SwiftUI

struct ScanSummaryView: View {
    let measurements: [MeasurementValue]
    let hasShell: Bool
    let onGenerate: () -> Void
    let onBack: () -> Void

    private var grouped: [(source: MeasurementSource, values: [MeasurementValue])] {
        let ordered: [MeasurementSource] = [.scan, .tape, .estimated]
        return ordered.compactMap { source in
            let values = measurements.filter { $0.source == source }
            return values.isEmpty ? nil : (source, values)
        }
    }

    var body: some View {
        List {
            if !hasShell {
                Section {
                    Label("未选择头壳档案，将不生成适配结论", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(grouped, id: \.source) { group in
                Section("\(group.source.displayName)（\(group.values.count)）") {
                    ForEach(group.values) { value in
                        LabeledContent(value.key.displayName) {
                            HStack(spacing: 6) {
                                AnimatedNumber(value: value.valueMM, format: "%.1f mm")
                                if value.source == .estimated {
                                    Text("估算")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Button(action: onBack) {
                    Label("上一步", systemImage: "chevron.left")
                }
                Button(action: onGenerate) {
                    Label("生成适配报告", systemImage: "doc.text")
                }
            }
        }
    }
}
