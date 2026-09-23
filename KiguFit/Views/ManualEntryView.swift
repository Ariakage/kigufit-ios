import SwiftUI

struct ManualEntryView: View {
    let scanSkipped: Bool
    let onContinue: ([MeasurementKey: Double]) -> Void
    let onBack: () -> Void

    @State private var values: [MeasurementKey: String]

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
    }

    private func measurementRow(_ key: MeasurementKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key.displayName)
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
