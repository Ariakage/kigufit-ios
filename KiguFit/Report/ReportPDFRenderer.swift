import UIKit

@MainActor
enum ReportPDFRenderer {
    static let pageSize = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 40
    static let contentWidth: CGFloat = 595 - 80

    private static let ink = UIColor.black
    private static let inkSecondary = UIColor(white: 0.32, alpha: 1)
    private static let inkTertiary = UIColor(white: 0.55, alpha: 1)
    private static let hairline = UIColor(white: 0.85, alpha: 1)

    private static let levelGreen = UIColor(red: 0.11, green: 0.60, blue: 0.26, alpha: 1)
    private static let levelOrange = UIColor(red: 0.93, green: 0.53, blue: 0.08, alpha: 1)
    private static let levelBlue = UIColor(red: 0.05, green: 0.42, blue: 0.88, alpha: 1)
    private static let levelRed = UIColor(red: 0.83, green: 0.18, blue: 0.18, alpha: 1)

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
            drawFitOverlay(&layout, record: record)
            drawShellInfo(&layout, shell: shell, shellName: record.shellName)
        }
    }

    struct Layout {
        let context: UIGraphicsPDFRendererContext
        var y: CGFloat = 40

        mutating func beginPage() {
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: ReportPDFRenderer.pageSize))
            y = 40
        }

        mutating func ensure(_ height: CGFloat) {
            if y + height > 780 {
                context.beginPage()
                beginPage()
            }
        }

        mutating func footer(_ text: String) {
            ReportPDFRenderer.draw(
                text,
                in: CGRect(x: ReportPDFRenderer.margin, y: 802, width: ReportPDFRenderer.contentWidth, height: 14),
                font: .systemFont(ofSize: 9),
                color: ReportPDFRenderer.inkTertiary,
                alignment: .center
            )
        }

        mutating func space(_ amount: CGFloat = 10) {
            y += amount
        }

        mutating func draw(_ text: String, font: UIFont, color: UIColor = .black, alignment: NSTextAlignment = .natural, spacing: CGFloat = 6) {
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
            ReportPDFRenderer.hairline.setStroke()
            path.lineWidth = 0.5
            path.stroke()
            y += 1
        }
    }

    private static func drawHeader(_ layout: inout Layout, record: ScanRecord, dateText: String) {
        layout.draw("KiguFit 测量报告", font: .boldSystemFont(ofSize: 22), spacing: 4)
        let subtitle = "客户：\(record.clientName.isEmpty ? "未命名" : record.clientName)    头壳：\(record.shellName)    日期：\(dateText)"
        layout.draw(subtitle, font: .systemFont(ofSize: 11), color: inkSecondary, spacing: 8)
        layout.separator()
        layout.space(10)
    }

    private static func drawVerdict(_ layout: inout Layout, verdict: FitVerdict?) {
        guard let verdict else { return }
        let tint = color(for: verdict.level)

        let levelFont = UIFont.boldSystemFont(ofSize: 18)
        let summaryFont = UIFont.systemFont(ofSize: 11)
        let summaryWidth = contentWidth - 28
        let summaryHeight = textHeight(verdict.summary, width: summaryWidth, font: summaryFont)
        let boxHeight = 14 + 24 + 6 + summaryHeight + 14

        layout.ensure(boxHeight + 18)

        let rect = CGRect(x: margin, y: layout.y, width: contentWidth, height: boxHeight)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 10)
        tint.withAlphaComponent(0.10).setFill()
        path.fill()
        tint.withAlphaComponent(0.45).setStroke()
        path.lineWidth = 1
        path.stroke()

        draw(
            verdict.level.displayName,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 12, width: 160, height: 26),
            font: levelFont,
            color: tint,
            alignment: .left
        )
        draw(
            verdict.summary,
            in: CGRect(x: rect.minX + 14, y: rect.minY + 44, width: summaryWidth, height: summaryHeight),
            font: summaryFont,
            color: inkSecondary,
            alignment: .left
        )
        layout.space(boxHeight + 18)
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
        let rowFont = UIFont.systemFont(ofSize: 10.5)
        for value in values {
            layout.ensure(19)
            draw(
                value.key.displayName,
                in: CGRect(x: margin, y: layout.y, width: 300, height: 15),
                font: rowFont,
                color: ink,
                alignment: .left
            )
            draw(
                String(format: "%.1f mm · %@", value.valueMM, value.source.displayName),
                in: CGRect(x: margin + 300, y: layout.y, width: contentWidth - 300, height: 15),
                font: rowFont,
                color: inkSecondary,
                alignment: .right
            )
            layout.y += 17
        }
        layout.space(12)
    }

    private static func drawChecks(_ layout: inout Layout, verdict: FitVerdict?) {
        guard let verdict, !verdict.checks.isEmpty else { return }
        layout.draw("对照明细", font: .systemFont(ofSize: 14, weight: .semibold), spacing: 8)

        let titleFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let detailFont = UIFont.systemFont(ofSize: 10)
        let statusFont = UIFont.boldSystemFont(ofSize: 11)

        for check in verdict.checks {
            let detailHeight = textHeight(check.detail, width: contentWidth - 100, font: detailFont)
            layout.ensure(detailHeight + 30)

            draw(
                check.title,
                in: CGRect(x: margin, y: layout.y, width: contentWidth - 90, height: 16),
                font: titleFont,
                color: ink,
                alignment: .left
            )
            draw(
                check.status.displayName,
                in: CGRect(x: margin, y: layout.y, width: contentWidth, height: 16),
                font: statusFont,
                color: color(for: check.status),
                alignment: .right
            )
            layout.y += 18

            draw(
                check.detail,
                in: CGRect(x: margin, y: layout.y, width: contentWidth - 100, height: detailHeight),
                font: detailFont,
                color: inkTertiary,
                alignment: .left
            )
            if let marginValue = check.marginMM {
                draw(
                    String(format: "余量 %.1f mm", marginValue),
                    in: CGRect(x: margin + contentWidth - 100, y: layout.y, width: 100, height: detailHeight),
                    font: detailFont,
                    color: inkSecondary,
                    alignment: .right
                )
            }
            layout.y += detailHeight + 6
            layout.separator()
        }
        layout.space(12)
    }

    private static func drawSuggestions(_ layout: inout Layout, verdict: FitVerdict?) {
        guard let verdict, !verdict.suggestions.isEmpty else { return }
        layout.draw("建议", font: .systemFont(ofSize: 14, weight: .semibold), spacing: 6)
        for suggestion in verdict.suggestions {
            let line = "• " + suggestion.detail
            let height = textHeight(line, width: contentWidth, font: .systemFont(ofSize: 11))
            layout.ensure(height + 6)
            layout.draw(line, font: .systemFont(ofSize: 11), spacing: 5)
        }
        layout.space(6)
    }

    private static func drawAI(_ layout: inout Layout, narrative: String?) {
        guard let narrative, !narrative.isEmpty else { return }
        layout.draw("AI 解读", font: .systemFont(ofSize: 14, weight: .semibold), spacing: 6)
        let height = textHeight(narrative, width: contentWidth, font: .systemFont(ofSize: 11))
        layout.ensure(height + 6)
        layout.draw(narrative, font: .systemFont(ofSize: 11), spacing: 8)
    }

    private static func drawMeasurements(_ layout: inout Layout, measurements: [MeasurementValue]) {
        layout.draw("测量数据", font: .boldSystemFont(ofSize: 16), spacing: 10)

        let rowFont = UIFont.systemFont(ofSize: 10)
        let itemX = margin
        let itemWidth: CGFloat = 230
        let valueX = itemX + itemWidth + 10
        let valueWidth: CGFloat = 80
        let sourceX = valueX + valueWidth + 12
        let sourceWidth: CGFloat = 60
        let confidenceX = sourceX + sourceWidth + 10
        let confidenceWidth = pageSize.width - margin - confidenceX

        layout.ensure(18)
        draw("项目", in: CGRect(x: itemX, y: layout.y, width: itemWidth, height: 14), font: .boldSystemFont(ofSize: 10), color: inkSecondary, alignment: .left)
        draw("数值 (mm)", in: CGRect(x: valueX, y: layout.y, width: valueWidth, height: 14), font: .boldSystemFont(ofSize: 10), color: inkSecondary, alignment: .right)
        draw("来源", in: CGRect(x: sourceX, y: layout.y, width: sourceWidth, height: 14), font: .boldSystemFont(ofSize: 10), color: inkSecondary, alignment: .left)
        draw("置信度", in: CGRect(x: confidenceX, y: layout.y, width: confidenceWidth, height: 14), font: .boldSystemFont(ofSize: 10), color: inkSecondary, alignment: .right)
        layout.y += 16
        layout.separator()

        let ordered: [MeasurementSource] = [.scan, .tape, .estimated]
        let sorted = measurements.sorted { lhs, rhs in
            let lhsIndex = ordered.firstIndex(of: lhs.source) ?? 3
            let rhsIndex = ordered.firstIndex(of: rhs.source) ?? 3
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs.key.rawValue < rhs.key.rawValue
        }

        for measurement in sorted {
            layout.ensure(19)
            draw(measurement.key.displayName, in: CGRect(x: itemX, y: layout.y, width: itemWidth, height: 15), font: rowFont, color: ink, alignment: .left)
            draw(String(format: "%.1f", measurement.valueMM), in: CGRect(x: valueX, y: layout.y, width: valueWidth, height: 15), font: rowFont, color: ink, alignment: .right)
            draw(measurement.source.displayName, in: CGRect(x: sourceX, y: layout.y, width: sourceWidth, height: 15), font: rowFont, color: inkSecondary, alignment: .left)
            draw(String(format: "%.2f", measurement.confidence), in: CGRect(x: confidenceX, y: layout.y, width: confidenceWidth, height: 15), font: rowFont, color: inkSecondary, alignment: .right)
            layout.y += 17
        }
        layout.space(16)
    }

    private static func drawFitOverlay(_ layout: inout Layout, record: ScanRecord) {
        guard let headWidth = record.measurements.value(for: .headWidth)?.valueMM,
              let headDepth = record.measurements.value(for: .headDepth)?.valueMM,
              let shell = record.shellPayload,
              let shellWidth = shell.inner.bandWidth(),
              let shellDepth = shell.inner.bandDepth() else {
            return
        }

        layout.draw("俯视对照（示意）", font: .systemFont(ofSize: 14, weight: .semibold), spacing: 8)

        let boxWidth: CGFloat = 320
        let boxHeight: CGFloat = 150
        layout.ensure(boxHeight + 36)

        let scale = min(boxWidth / CGFloat(shellDepth), boxHeight / CGFloat(shellWidth))
        let center = CGPoint(x: margin + boxWidth / 2, y: layout.y + boxHeight / 2)

        let shellRect = CGRect(
            x: center.x - CGFloat(shellDepth) * scale / 2,
            y: center.y - CGFloat(shellWidth) * scale / 2,
            width: CGFloat(shellDepth) * scale,
            height: CGFloat(shellWidth) * scale
        )
        let shellPath = UIBezierPath(ovalIn: shellRect)
        UIColor(white: 0.94, alpha: 1).setFill()
        shellPath.fill()
        UIColor(white: 0.55, alpha: 1).setStroke()
        shellPath.lineWidth = 1.5
        shellPath.stroke()

        let headRect = CGRect(
            x: center.x - CGFloat(headDepth) * scale / 2,
            y: center.y - CGFloat(headWidth) * scale / 2,
            width: CGFloat(headDepth) * scale,
            height: CGFloat(headWidth) * scale
        )
        let headPath = UIBezierPath(ovalIn: headRect)
        levelBlue.withAlphaComponent(0.22).setFill()
        headPath.fill()
        levelBlue.setStroke()
        headPath.lineWidth = 2
        headPath.stroke()

        layout.y += boxHeight + 6
        layout.draw(
            String(format: "蓝 = 头部 %.0f×%.0f mm ｜ 灰 = 头壳内腔 %.0f×%.0f mm（宽×深，头带高度）", headWidth, headDepth, shellWidth, shellDepth),
            font: .systemFont(ofSize: 10),
            color: inkTertiary,
            spacing: 12
        )
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
            layout.draw("备注：\(notes)", font: .systemFont(ofSize: 10), color: inkTertiary, spacing: 4)
        }
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, alignment: NSTextAlignment) {
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

    private static func textHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        ceil((text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).height)
    }

    private static func color(for level: FitVerdict.Level) -> UIColor {
        switch level {
        case .good: return levelGreen
        case .tight: return levelOrange
        case .loose: return levelBlue
        case .unfit: return levelRed
        }
    }

    private static func color(for status: FitVerdict.Check.Status) -> UIColor {
        switch status {
        case .ok: return levelGreen
        case .warn: return levelOrange
        case .fail: return levelRed
        }
    }
}
