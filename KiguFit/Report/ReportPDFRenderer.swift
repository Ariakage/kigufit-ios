import UIKit

@MainActor
enum ReportPDFRenderer {
    static let pageSize = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 40
    static let contentWidth: CGFloat = 595 - 80

    static func renderPDF(record: ScanRecord) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let measurements = record.measurements
        let verdict = record.verdict
        let shell = record.shellPayload
        let dateText = record.createdAt.formatted(date: .numeric, time: .shortened)

        return renderer.pdfData { context in
            var layout = Layout(context: context)

            context.beginPage()
            layout.beginPage()
            layout.footer("KiguFit · \(dateText)")
            drawHeader(&layout, record: record, dateText: dateText)
            drawVerdict(&layout, verdict: verdict)
            drawKeySummary(&layout, measurements: measurements, hasVerdict: verdict != nil)
            drawChecks(&layout, verdict: verdict)
            drawSuggestions(&layout, verdict: verdict)
            drawAI(&layout, narrative: record.aiNarrative)

            context.beginPage()
            layout.beginPage()
            layout.footer("KiguFit · 数据页 · \(dateText)")
            drawMeasurements(&layout, measurements: measurements)
            drawShellInfo(&layout, shell: shell, shellName: record.shellName)
        }
    }

    struct Layout {
        let context: UIGraphicsPDFRendererContext
        var y: CGFloat = 40

        mutating func beginPage() {
            y = 40
        }

        mutating func ensure(_ height: CGFloat) {
            if y + height > 780 {
                context.beginPage()
                y = 40
            }
        }

        mutating func footer(_ text: String) {
            ReportPDFRenderer.draw(
                text,
                in: CGRect(x: 40, y: 800, width: contentWidth, height: 14),
                font: .systemFont(ofSize: 9),
                color: .gray,
                alignment: .center
            )
        }

        mutating func space(_ amount: CGFloat = 10) {
            y += amount
        }
    }

    private static func drawHeader(_ layout: inout Layout, record: ScanRecord, dateText: String) {
        layout.draw("KiguFit 测量报告", font: .boldSystemFont(ofSize: 22), spacing: 4)
        let subtitle = "客户：\(record.clientName.isEmpty ? "未命名" : record.clientName)    头壳：\(record.shellName)    日期：\(dateText)"
        layout.draw(subtitle, font: .systemFont(ofSize: 11), color: .darkGray, spacing: 10)
        layout.separator()
        layout.space(8)
    }

    private static func drawVerdict(_ layout: inout Layout, verdict: FitVerdict?) {
        guard let verdict else { return }
        let tint = color(for: verdict.level)
        let boxHeight: CGFloat = 64
        layout.ensure(boxHeight + 16)

        let rect = CGRect(x: margin, y: layout.y, width: contentWidth, height: boxHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        tint.withAlphaComponent(0.12).setFill()
        path.fill()
        tint.withAlphaComponent(0.5).setStroke()
        path.lineWidth = 1
        path.stroke()

        draw(
            verdict.level.displayName,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 10, width: 120, height: 24),
            font: .boldSystemFont(ofSize: 18),
            color: tint,
            alignment: .left
        )
        draw(
            verdict.summary,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 34, width: rect.width - 28, height: 22),
            font: .systemFont(ofSize: 11),
            color: .darkGray,
            alignment: .left
        )
        layout.space(boxHeight + 16)
    }

    private static func drawKeySummary(_ layout: inout Layout, measurements: [MeasurementValue], hasVerdict: Bool) {
        let keys: [MeasurementKey] = [
            .headCircumference, .headHeight, .headWidth, .headDepth,
            .interpupillaryDistance, .bizygomaticWidth
        ]
        let values = keys.compactMap { key in measurements.first { $0.key == key } }
        guard !values.isEmpty else { return }

        layout.draw(
            hasVerdict ? "关键测量" : "测量摘要（未选择头壳，未生成适配结论）",
            font: .systemFont(ofSize: 14, weight: .semibold),
            spacing: 8
        )
        for value in values {
            layout.ensure(18)
            draw(
                value.key.displayName,
                in: CGRect(x: margin, y: layout.y, width: 300, height: 14),
                font: .systemFont(ofSize: 10),
                color: .label,
                alignment: .left
            )
            draw(
                String(format: "%.1f mm · %@", value.valueMM, value.source.displayName),
                in: CGRect(x: margin + 300, y: layout.y, width: contentWidth - 300, height: 14),
                font: .systemFont(ofSize: 10),
                color: .darkGray,
                alignment: .right
            )
            layout.y += 16
        }
        layout.space(10)
    }

    private static func drawChecks(_ layout: inout Layout, verdict: FitVerdict?) {
        guard let verdict, !verdict.checks.isEmpty else { return }
        layout.draw("对照明细", font: .systemFont(ofSize: 14, weight: .semibold), spacing: 8)
        for check in verdict.checks {
            let detailHeight = textHeight(check.detail, width: contentWidth - 90, font: .systemFont(ofSize: 10))
            layout.ensure(detailHeight + 26)
            let titleRect = CGRect(x: margin, y: layout.y, width: contentWidth - 80, height: 16)
            draw(check.title, in: titleRect, font: .systemFont(ofSize: 12, weight: .semibold), color: .label, alignment: .left)
            draw(
                check.status.displayName,
                in: CGRect(x: margin, y: layout.y, width: contentWidth, height: 16),
                font: .boldSystemFont(ofSize: 11),
                color: color(for: check.status),
                alignment: .right
            )
            layout.y += 17
            draw(
                check.detail,
                in: CGRect(x: margin, y: layout.y, width: contentWidth - 90, height: detailHeight),
                font: .systemFont(ofSize: 10),
                color: .gray,
                alignment: .left
            )
            if let marginValue = check.marginMM {
                draw(
                    String(format: "余量 %.1f mm", marginValue),
                    in: CGRect(x: margin, y: layout.y, width: contentWidth, height: detailHeight),
                    font: .systemFont(ofSize: 10),
                    color: .darkGray,
                    alignment: .right
                )
            }
            layout.y += detailHeight + 4
            layout.separator()
        }
        layout.space(10)
    }

    private static func drawSuggestions(_ layout: inout Layout, verdict: FitVerdict?) {
        guard let verdict, !verdict.suggestions.isEmpty else { return }
        layout.draw("建议", font: .systemFont(ofSize: 14, weight: .semibold), spacing: 6)
        for suggestion in verdict.suggestions {
            let height = textHeight("• " + suggestion.detail, width: contentWidth, font: .systemFont(ofSize: 11))
            layout.ensure(height + 4)
            layout.draw("• " + suggestion.detail, font: .systemFont(ofSize: 11), spacing: 4)
        }
        layout.space(6)
    }

    private static func drawAI(_ layout: inout Layout, narrative: String?) {
        guard let narrative, !narrative.isEmpty else { return }
        layout.draw("AI 解读", font: .systemFont(ofSize: 14, weight: .semibold), spacing: 6)
        let height = textHeight(narrative, width: contentWidth, font: .systemFont(ofSize: 11))
        layout.ensure(height + 4)
        layout.draw(narrative, font: .systemFont(ofSize: 11), spacing: 6)
    }

    private static func drawMeasurements(_ layout: inout Layout, measurements: [MeasurementValue]) {
        layout.draw("测量数据", font: .boldSystemFont(ofSize: 16), spacing: 10)

        let columns: [(String, CGFloat, NSTextAlignment)] = [
            ("项目", margin, .left),
            ("数值 (mm)", margin + 250, .right),
            ("来源", margin + 330, .left),
            ("置信度", margin + 420, .right)
        ]
        layout.ensure(18)
        for (title, x, alignment) in columns {
            draw(
                title,
                in: CGRect(x: x, y: layout.y, width: 90, height: 14),
                font: .boldSystemFont(ofSize: 10),
                color: .darkGray,
                alignment: alignment
            )
        }
        layout.y += 16
        layout.separator()

        let ordered = [MeasurementSource.scan, .tape, .estimated]
        let sorted = measurements.sorted { lhs, rhs in
            let lhsIndex = ordered.firstIndex(of: lhs.source) ?? 3
            let rhsIndex = ordered.firstIndex(of: rhs.source) ?? 3
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs.key.rawValue < rhs.key.rawValue
        }

        for measurement in sorted {
            layout.ensure(18)
            draw(
                measurement.key.displayName,
                in: CGRect(x: margin, y: layout.y, width: 240, height: 14),
                font: .systemFont(ofSize: 10),
                color: .label,
                alignment: .left
            )
            draw(
                String(format: "%.1f", measurement.valueMM),
                in: CGRect(x: margin + 250, y: layout.y, width: 80, height: 14),
                font: .systemFont(ofSize: 10),
                color: .label,
                alignment: .right
            )
            draw(
                measurement.source.displayName,
                in: CGRect(x: margin + 330, y: layout.y, width: 60, height: 14),
                font: .systemFont(ofSize: 10),
                color: .darkGray,
                alignment: .left
            )
            draw(
                String(format: "%.2f", measurement.confidence),
                in: CGRect(x: margin + 400, y: layout.y, width: 115, height: 14),
                font: .systemFont(ofSize: 10),
                color: .darkGray,
                alignment: .right
            )
            layout.y += 16
        }
        layout.space(14)
    }

    private static func drawShellInfo(_ layout: inout Layout, shell: ShellProfilePayload?, shellName: String) {
        layout.draw("头壳信息", font: .boldSystemFont(ofSize: 16), spacing: 8)
        layout.draw("名称：\(shellName)", font: .systemFont(ofSize: 11), spacing: 4)
        guard let shell else { return }
        layout.draw(
            String(format: "外形：%.1f × %.1f × %.1f mm", shell.outer.width, shell.outer.depth, shell.outer.height),
            font: .systemFont(ofSize: 11),
            spacing: 4
        )
        layout.draw(String(format: "内腔高：%.1f mm", shell.inner.height), font: .systemFont(ofSize: 11), spacing: 4)
        if let thickness = shell.inner.wallThickness {
            layout.draw(String(format: "壁厚：%.1f mm", thickness), font: .systemFont(ofSize: 11), spacing: 4)
        }
        if let bowl = shell.inner.faceBowlWidth {
            layout.draw(String(format: "脸碗内宽：%.1f mm", bowl), font: .systemFont(ofSize: 11), spacing: 4)
        }
        if let holes = shell.eyeHoles {
            layout.draw(
                String(format: "眼孔：%.0f×%.0f mm，中心距 %.0f mm，高于内底 %.1f mm", holes.width, holes.height, holes.centerSpacing, holes.centerAboveInnerBottom),
                font: .systemFont(ofSize: 11),
                spacing: 4
            )
        }
        if let range = shell.fit?.headCircumferenceRange, range.count == 2 {
            layout.draw(String(format: "建议头围：%.0f–%.0f mm", range[0], range[1]), font: .systemFont(ofSize: 11), spacing: 4)
        }
        if let notes = shell.notes {
            layout.draw("备注：\(notes)", font: .systemFont(ofSize: 10), color: .gray, spacing: 4)
        }
    }

    static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style],
            context: nil
        )
    }

    static func textHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        ceil((text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height)
    }

    private static func color(for level: FitVerdict.Level) -> UIColor {
        switch level {
        case .good: return .systemGreen
        case .tight: return .systemOrange
        case .loose: return .systemBlue
        case .unfit: return .systemRed
        }
    }

    private static func color(for status: FitVerdict.Check.Status) -> UIColor {
        switch status {
        case .ok: return .systemGreen
        case .warn: return .systemOrange
        case .fail: return .systemRed
        }
    }
}

extension ReportPDFRenderer.Layout {
    mutating func draw(_ text: String, font: UIFont, color: UIColor = .label, alignment: NSTextAlignment = .natural, spacing: CGFloat = 6) {
        let height = ReportPDFRenderer.textHeight(text, width: ReportPDFRenderer.contentWidth, font: font)
        ensure(height + spacing)
        ReportPDFRenderer.draw(
            text,
            in: CGRect(x: ReportPDFRenderer.margin, y: y, width: ReportPDFRenderer.contentWidth, height: height),
            font: font,
            color: color,
            alignment: alignment
        )
        y += height + spacing
    }

    mutating func separator() {
        ensure(12)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: ReportPDFRenderer.margin, y: y))
        path.addLine(to: CGPoint(x: ReportPDFRenderer.pageSize.width - ReportPDFRenderer.margin, y: y))
        UIColor.systemGray4.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        y += 1
    }
}
