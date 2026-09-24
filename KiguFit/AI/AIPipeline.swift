import Foundation

nonisolated enum AIPipeline {
    struct MeasurementLine: Sendable {
        var label: String
        var valueMM: Double
        var source: String
    }

    struct CheckLine: Sendable {
        var title: String
        var detail: String
        var status: String
    }

    struct ReportContext: Sendable {
        var clientName: String
        var shellName: String
        var dateText: String
        var measurements: [MeasurementLine]
        var verdictLevel: String?
        var verdictSummary: String?
        var checks: [CheckLine]
        var suggestions: [String]
    }

    @MainActor
    static func context(from record: ScanRecord) -> ReportContext {
        ReportContext(
            clientName: record.clientName.isEmpty ? "未命名" : record.clientName,
            shellName: record.shellName,
            dateText: record.createdAt.formatted(date: .numeric, time: .shortened),
            measurements: record.measurements.map {
                MeasurementLine(label: $0.key.displayName, valueMM: $0.valueMM, source: $0.source.displayName)
            },
            verdictLevel: record.verdict?.level.displayName,
            verdictSummary: record.verdict?.summary,
            checks: record.verdict?.checks.map {
                CheckLine(title: $0.title, detail: $0.detail, status: $0.status.displayName)
            } ?? [],
            suggestions: record.verdict?.suggestions.map(\.detail) ?? []
        )
    }

    static func recordMessages(context: ReportContext) -> [LLMMessage] {
        let system = """
        你是 Kigurumi 头壳定制工作室的测量顾问。根据提供的测量数据与适配判定，用中文写一段 150~250 字的解读，面向佩戴客户与头壳制作方：\
        先用一句话给出结论，再引用关键数值说明依据，最后给出 1~2 条可执行的佩戴或制作建议（例如海绵厚度、佩戴前倾角、是否需要放大头壳）。\
        只使用提供的数据，不要编造任何数值，不要使用 Markdown 标题或列表符号。
        """

        var lines: [String] = []
        lines.append("客户：\(context.clientName)　头壳：\(context.shellName)　日期：\(context.dateText)")

        if let level = context.verdictLevel, let summary = context.verdictSummary {
            lines.append("适配结论：\(level)——\(summary)")
        } else {
            lines.append("适配结论：未选择头壳档案，仅有测量数据")
        }

        lines.append("测量数据：")
        for measurement in context.measurements {
            lines.append("- \(measurement.label)：\(String(format: "%.1f", measurement.valueMM)) mm（\(measurement.source)）")
        }

        if !context.checks.isEmpty {
            lines.append("对照明细：")
            for check in context.checks {
                lines.append("- \(check.title)【\(check.status)】\(check.detail)")
            }
        }

        if !context.suggestions.isEmpty {
            lines.append("规则引擎建议：")
            for suggestion in context.suggestions {
                lines.append("- \(suggestion)")
            }
        }

        return [
            LLMMessage(role: "system", content: system),
            LLMMessage(role: "user", content: lines.joined(separator: "\n"))
        ]
    }
}
