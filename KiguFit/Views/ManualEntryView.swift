import SwiftUI

struct ManualEntryView: View {
    let scanSkipped: Bool
    let onContinue: ([MeasurementKey: Double]) -> Void
    let onBack: () -> Void

    @State private var values: [MeasurementKey: String]
    @State private var guideKey: MeasurementKey?

    private static let requiredKeys: [MeasurementKey] = [.headCircumference, .headHeight]
    private static let optionalKeys: [MeasurementKey] = [
        .headWidth, .headDepth, .earToEarOverTop, .foreheadToOcciputOverTop, .neckCircumference
    ]

    init(
        initialEntries: [MeasurementKey: Double],
        scanSkipped: Bool,
        onContinue: @escaping ([MeasurementKey: Double]) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.scanSkipped = scanSkipped
        self.onContinue = onContinue
        self.onBack = onBack
        var initial: [MeasurementKey: String] = [:]
        for (key, value) in initialEntries {
            initial[key] = String(format: "%.0f", value)
        }
        _values = State(initialValue: initial)
    }

    var body: some View {
        Form {
            if scanSkipped {
                Section {
                    Label("已跳过 3D 扫描，报告将基于软尺与估算数据", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(Self.requiredKeys, id: \.self) { key in
                    measurementRow(key)
                }
            } header: {
                Text("必填")
            }

            Section {
                ForEach(Self.optionalKeys, id: \.self) { key in
                    measurementRow(key)
                }
            } header: {
                Text("选填（留空则按比例估算）")
            }

            Section {
                Button {
                    onBack()
                } label: {
                    Label("上一步", systemImage: "chevron.left")
                }
                Button {
                    onContinue(parsedEntries())
                } label: {
                    Label("下一步：测量总览", systemImage: "chevron.right")
                }
                .disabled(!isValid)
            }
        }
        .sheet(item: $guideKey) { key in
            MeasurementGuideSheet(key: key)
        }
    }

    private func measurementRow(_ key: MeasurementKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key.displayName)
                if key.guide != nil {
                    Button {
                        guideKey = key
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.footnote)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                Spacer()
                TextField("跳过", text: binding(for: key))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                    .monospacedDigit()
                Text("mm")
                    .foregroundStyle(.secondary)
            }
            if let hint = key.tapeHint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func binding(for key: MeasurementKey) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }

    private func parsed(_ key: MeasurementKey) -> Double? {
        guard let text = values[key]?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        return Double(text)
    }

    private var isValid: Bool {
        guard let circumference = parsed(.headCircumference), circumference >= 350, circumference <= 750 else { return false }
        guard let height = parsed(.headHeight), height >= 150, height <= 350 else { return false }
        return true
    }

    private func parsedEntries() -> [MeasurementKey: Double] {
        var entries: [MeasurementKey: Double] = [:]
        for key in Self.requiredKeys + Self.optionalKeys {
            if let value = parsed(key), value > 0 {
                entries[key] = value
            }
        }
        return entries
    }
}

struct MeasurementGuideSheet: View {
    let key: MeasurementKey
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let guide = key.guide {
                    Section("方法") {
                        ForEach(Array(guide.method.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.blue)
                                    .frame(width: 18, alignment: .leading)
                                Text(step)
                            }
                        }
                    }
                    Section("位置") {
                        Text(guide.location)
                    }
                    Section("细节与注意") {
                        ForEach(guide.details, id: \.self) { detail in
                            Label(detail, systemImage: "exclamationmark.circle")
                                .font(.callout)
                        }
                    }
                } else {
                    Text("暂无说明")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(key.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
