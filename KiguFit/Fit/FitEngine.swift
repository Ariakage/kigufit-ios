import Foundation

nonisolated enum FitEngine {
    struct Thresholds: Sendable {
        var minPaddingPerSide: Double = 8
        var warnPaddingPerSide: Double = 12
        var comfortablePaddingPerSide: Double = 40
        var maxPaddingPerSide: Double = 55
        var eyeAlignmentWarn: Double = 15
        var eyeAlignmentFail: Double = 25
        var minFaceBowlClearance: Double = 5
        var comfortableFaceBowlClearance: Double = 15
        var maxFaceBowlClearance: Double = 90
        var minHeightClearance: Double = 15
        var warnHeightClearance: Double = 30
        var maxHeightClearance: Double = 110
        var targetPaddingPerSide: Double = 15
    }

    static func evaluate(
        shell: ShellProfilePayload,
        measurements: [MeasurementValue],
        thresholds: Thresholds = Thresholds()
    ) -> FitVerdict {
        let dict = Dictionary(uniqueKeysWithValues: measurements.map { ($0.key, $0) })

        func value(_ key: MeasurementKey) -> Double? {
            dict[key]?.valueMM
        }

        var checks: [FitVerdict.Check] = []
        var suggestions: [FitVerdict.Suggestion] = []
        var tight = false
        var loose = false
        var alignmentFailed = false

        if let bandWidth = shell.inner.innerWidth(nearest: 20), let headWidth = value(.headWidth) {
            let marginPerSide = (bandWidth - headWidth) / 2
            var status = FitVerdict.Check.Status.ok
            if marginPerSide < thresholds.minPaddingPerSide {
                status = .fail
                tight = true
            } else if marginPerSide < thresholds.warnPaddingPerSide {
                status = .warn
            } else if marginPerSide > thresholds.maxPaddingPerSide {
                status = .fail
                loose = true
            } else if marginPerSide > thresholds.comfortablePaddingPerSide {
                status = .warn
            }
            checks.append(.init(
                title: "内腔宽度（头带高度）",
                shellValueMM: bandWidth,
                measuredMM: headWidth,
                marginMM: marginPerSide,
                status: status,
                detail: String(format: "头带高度内腔 %.1fmm，预计单侧余量 %.1fmm", bandWidth, marginPerSide)
            ))

            if marginPerSide >= thresholds.minPaddingPerSide {
                let padding = min(marginPerSide, 60)
                suggestions.append(.init(
                    kind: .padding,
                    detail: String(format: "预计单侧内衬海绵约 %.0f mm", padding),
                    valueMM: padding,
                    scalePercent: nil
                ))
            }
            if marginPerSide < thresholds.minPaddingPerSide {
                let needed = (headWidth + 2 * thresholds.targetPaddingPerSide) - bandWidth
                let percent = max(0, needed / bandWidth * 100)
                suggestions.append(.init(
                    kind: .scale,
                    detail: String(format: "内腔宽度不足，建议整体放大约 %.1f%%", percent),
                    valueMM: nil,
                    scalePercent: percent
                ))
            }
        }

        if let holes = shell.eyeHoles, let eyeToChin = value(.eyeToChin) {
            let delta = eyeToChin - holes.centerAboveInnerBottom
            var status = FitVerdict.Check.Status.ok
            if abs(delta) > thresholds.eyeAlignmentFail {
                status = .fail
                alignmentFailed = true
            } else if abs(delta) > thresholds.eyeAlignmentWarn {
                status = .warn
            }
            checks.append(.init(
                title: "眼位对位",
                shellValueMM: holes.centerAboveInnerBottom,
                measuredMM: eyeToChin,
                marginMM: delta,
                status: status,
                detail: String(format: "眼孔中心高于内底 %.1fmm，实测眼-下巴 %.1fmm，偏差 %.1fmm", holes.centerAboveInnerBottom, eyeToChin, delta)
            ))
            if abs(delta) > thresholds.eyeAlignmentWarn {
                suggestions.append(.init(
                    kind: .note,
                    detail: String(format: "眼位偏差 %.0fmm，可通过头壳前倾角与内衬厚度补偿", delta),
                    valueMM: delta,
                    scalePercent: nil
                ))
            }
        }

        if let bowl = shell.inner.faceBowlWidth, let face = value(.bizygomaticWidth) {
            let clearance = bowl - face
            var status = FitVerdict.Check.Status.ok
            if clearance < thresholds.minFaceBowlClearance {
                status = .fail
                tight = true
            } else if clearance < thresholds.comfortableFaceBowlClearance {
                status = .warn
            } else if clearance > thresholds.maxFaceBowlClearance {
                status = .fail
                loose = true
            }
            checks.append(.init(
                title: "脸碗宽度",
                shellValueMM: bowl,
                measuredMM: face,
                marginMM: clearance,
                status: status,
                detail: String(format: "脸碗内宽 %.1fmm，颧骨宽 %.1fmm，余量 %.1fmm", bowl, face, clearance)
            ))
        }

        if let headHeight = value(.headHeight) {
            let clearance = shell.inner.height - headHeight
            var status = FitVerdict.Check.Status.ok
            if clearance < thresholds.minHeightClearance {
                status = .fail
                tight = true
            } else if clearance < thresholds.warnHeightClearance {
                status = .warn
            } else if clearance > thresholds.maxHeightClearance {
                status = .fail
                loose = true
            }
            checks.append(.init(
                title: "内腔高度",
                shellValueMM: shell.inner.height,
                measuredMM: headHeight,
                marginMM: clearance,
                status: status,
                detail: String(format: "内腔高 %.1fmm，头高 %.1fmm，余量 %.1fmm", shell.inner.height, headHeight, clearance)
            ))
        }

        if let range = shell.fit?.headCircumferenceRange, range.count == 2, let circumference = value(.headCircumference) {
            let lower = range[0]
            let upper = range[1]
            var status = FitVerdict.Check.Status.ok
            if circumference < lower {
                status = .fail
                loose = true
            } else if circumference > upper {
                status = .fail
                tight = true
            }
            checks.append(.init(
                title: "建议头围区间",
                shellValueMM: nil,
                measuredMM: circumference,
                marginMM: circumference < lower ? circumference - lower : (circumference > upper ? circumference - upper : 0),
                status: status,
                detail: String(format: "该壳建议头围 %.0f–%.0fmm，实测 %.0fmm", lower, upper, circumference)
            ))
            if circumference < lower {
                suggestions.append(.init(kind: .note, detail: "头围低于建议区间，佩戴偏松，需要加厚内衬海绵", valueMM: circumference - lower, scalePercent: nil))
            } else if circumference > upper {
                suggestions.append(.init(kind: .note, detail: "头围高于建议区间，佩戴偏紧，可能需要放大头壳", valueMM: circumference - upper, scalePercent: nil))
            }
        }

        let level: FitVerdict.Level
        if tight && loose {
            level = .unfit
        } else if tight {
            level = .tight
        } else if loose {
            level = .loose
        } else if alignmentFailed {
            level = .tight
        } else {
            level = .good
        }

        let failedTitles = checks.filter { $0.status == .fail }.map(\.title)
        let summary: String
        switch level {
        case .good:
            summary = "各项余量正常，可正常佩戴"
        case .tight:
            summary = failedTitles.isEmpty ? "存在需要调整的项（眼位偏差）" : "偏紧项：\(failedTitles.joined(separator: "、"))"
        case .loose:
            summary = "偏松项：\(failedTitles.joined(separator: "、"))，建议加厚内衬"
        case .unfit:
            summary = "多项超出范围：\(failedTitles.joined(separator: "、"))"
        }

        return FitVerdict(level: level, summary: summary, checks: checks, suggestions: suggestions)
    }
}
