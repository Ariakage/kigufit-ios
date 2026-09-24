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

    static func recordMessages(context: ReportContext, geometry: String? = nil) -> [LLMMessage] {
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

        if let geometry, !geometry.isEmpty {
            lines.append("补充几何数据（降采样）：")
            lines.append(geometry)
        }

        return [
            LLMMessage(role: "system", content: system),
            LLMMessage(role: "user", content: lines.joined(separator: "\n"))
        ]
    }

    struct ShellContext: Sendable {
        var name: String
        var outerWidth: Double
        var outerDepth: Double
        var outerHeight: Double
        var innerHeight: Double
        var wallThickness: Double?
        var bandWidth: Double?
        var bowlWidth: Double?
        var eyeHoles: String?
        var fitRange: String?
        var notes: String?
    }

    static func context(from analysis: ShellAnalysis) -> ShellContext {
        ShellContext(
            name: analysis.name,
            outerWidth: analysis.outerWidth,
            outerDepth: analysis.outerDepth,
            outerHeight: analysis.outerHeight,
            innerHeight: analysis.innerHeight,
            wallThickness: analysis.wallThickness,
            bandWidth: analysis.width(atFraction: 0.5),
            bowlWidth: analysis.faceBowlWidth,
            eyeHoles: analysis.eyeHoles.map {
                String(format: "%.0f×%.0f mm，中心距 %.0f mm，高于内底 %.0f mm", $0.width, $0.height, $0.spacing, $0.aboveInnerBottom)
            },
            fitRange: nil,
            notes: analysis.notes.joined(separator: "；")
        )
    }

    static func context(from payload: ShellProfilePayload) -> ShellContext {
        ShellContext(
            name: payload.name,
            outerWidth: payload.outer.width,
            outerDepth: payload.outer.depth,
            outerHeight: payload.outer.height,
            innerHeight: payload.inner.height,
            wallThickness: payload.inner.wallThickness,
            bandWidth: payload.inner.bandWidth(),
            bowlWidth: payload.inner.bowlWidth(),
            eyeHoles: payload.eyeHoles.map {
                String(format: "%.0f×%.0f mm，中心距 %.0f mm，高于内底 %.0f mm", $0.width, $0.height, $0.centerSpacing, $0.centerAboveInnerBottom)
            },
            fitRange: payload.fit?.headCircumferenceRange.map { String(format: "%.0f–%.0f mm", $0[0], $0[1]) },
            notes: payload.notes
        )
    }

    static func shellMessages(context: ShellContext, geometry: String? = nil) -> [LLMMessage] {
        let system = """
        你是 Kigurumi 头壳定制工作室的技术顾问。根据提供的头壳内部尺寸数据，用中文写一段 120~200 字的规格解读，面向店家与建模方：        先一句话概括这是什么类型的头壳（容积大小/脸型宽窄/头围适配倾向），再引用关键数值说明（内腔宽度、脸碗、内腔高、眼孔），        最后给 1~2 条使用建议（适合的头围区间、海绵配置或需要注意的适配点）。只使用提供的数据，不要编造任何数值，不要使用 Markdown。
        """
        var lines: [String] = []
        lines.append("头壳：\(context.name)")
        lines.append(String(format: "外形：%.0f × %.0f × %.0f mm（宽×深×高）", context.outerWidth, context.outerDepth, context.outerHeight))
        lines.append(String(format: "内腔高：%.1f mm", context.innerHeight))
        if let wall = context.wallThickness {
            lines.append(String(format: "壁厚：%.1f mm", wall))
        }
        if let band = context.bandWidth {
            lines.append(String(format: "头带高度内宽：%.1f mm（单侧余量按头宽推算）", band))
        }
        if let bowl = context.bowlWidth {
            lines.append(String(format: "脸碗内宽（嘴部水平）：%.1f mm", bowl))
        }
        if let eyes = context.eyeHoles {
            lines.append("眼孔：\(eyes)")
        }
        if let range = context.fitRange {
            lines.append("档案标注建议头围：\(range)")
        }
        if let notes = context.notes, !notes.isEmpty {
            lines.append("备注：\(notes)")
        }
        if let geometry, !geometry.isEmpty {
            lines.append("补充几何数据（降采样）：")
            lines.append(geometry)
        }
        return [
            LLMMessage(role: "system", content: system),
            LLMMessage(role: "user", content: lines.joined(separator: "\n"))
        ]
    }

    static func contourBlock(from contours: [ShellProfilePayload.ContourLine]) -> String? {
        guard !contours.isEmpty else { return nil }
        var lines = ["内腔截面轮廓采样（单位 mm，俯视平面坐标 x=左右 / y=前后，fraction=相对内底高度比例）："]
        for contour in contours {
            var pairs: [String] = []
            var index = 0
            while index + 1 < contour.points.count {
                pairs.append(String(format: "(%.0f,%.0f)", contour.points[index], contour.points[index + 1]))
                index += 2
            }
            lines.append(String(format: "fraction %.2f：%@", contour.fraction, pairs.joined(separator: " ")))
        }
        return lines.joined(separator: "\n")
    }

    @MainActor
    static func faceGeometrySummary(for record: ScanRecord, maxPoints: Int = 160) -> String? {
        guard let data = record.meshData,
              let capture = FaceMeshCodec.decode(data),
              !capture.averagedVertices.isEmpty else {
            return nil
        }
        let vertices = capture.averagedVertices
        let stride = max(1, vertices.count / maxPoints)
        var pairs: [String] = []
        var index = 0
        while index < vertices.count {
            let vertex = vertices[index]
            pairs.append(String(format: "(%.0f,%.0f,%.0f)", Double(vertex.x) * 1000, Double(vertex.y) * 1000, Double(vertex.z) * 1000))
            index += stride
        }
        return "面部网格采样点（单位 mm，人脸坐标系）：\n" + pairs.joined(separator: " ")
    }
}
