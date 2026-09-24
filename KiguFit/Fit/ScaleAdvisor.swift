import Foundation

nonisolated struct ScaleAdvisor {
    struct Config: Equatable {
        var sideFoamMM: Double = 8
        var topFoamMM: Double = 10
        var backFoamMM: Double = 10
    }

    struct Requirement: Identifiable {
        enum Status {
            case satisfied
            case marginal
            case insufficient
        }

        let id: String
        let title: String
        let currentMM: Double
        let needMM: Double
        let basis: String
        let isLateral: Bool

        var deltaMM: Double { needMM - currentMM }

        var status: Status {
            if deltaMM <= 0.5 { return .satisfied }
            if deltaMM <= 4 { return .marginal }
            return .insufficient
        }
    }

    struct Result {
        var requirements: [Requirement]
        var uniformScalePercent: Double
        var directions: [String]
        var notes: [String]
    }

    static func evaluate(
        shell: ShellProfilePayload,
        measurements: [MeasurementValue],
        config: Config = Config()
    ) -> Result? {
        func value(_ key: MeasurementKey) -> Double? {
            measurements.first { $0.key == key }?.valueMM
        }

        var requirements: [Requirement] = []

        if let headWidth = value(.headWidth), let band = shell.inner.bandWidth() {
            requirements.append(Requirement(
                id: "band",
                title: "头带内宽",
                currentMM: band,
                needMM: headWidth + 2 * config.sideFoamMM,
                basis: String(format: "头宽 %.1f + 两侧海绵 2×%.0f", headWidth, config.sideFoamMM),
                isLateral: true
            ))
        }

        if let faceWidth = value(.bizygomaticWidth), let bowl = shell.inner.faceBowlWidth {
            requirements.append(Requirement(
                id: "bowl",
                title: "脸碗内宽",
                currentMM: bowl,
                needMM: faceWidth + 10,
                basis: String(format: "颧骨宽 %.1f + 面部余量 10", faceWidth),
                isLateral: true
            ))
        }

        if let headHeight = value(.headHeight) {
            requirements.append(Requirement(
                id: "height",
                title: "内腔高度",
                currentMM: shell.inner.height,
                needMM: headHeight + config.topFoamMM + 8,
                basis: String(format: "头高 %.1f + 顶部海绵 %.0f + 底部余量 8", headHeight, config.topFoamMM),
                isLateral: false
            ))
        }

        if let length = value(.headDepth),
           let depth = shell.inner.bandDepth() {
            requirements.append(Requirement(
                id: "depth",
                title: "内腔深度",
                currentMM: depth,
                needMM: length + config.backFoamMM + 6,
                basis: String(format: "头长 %.1f + 后脑海绵 %.0f + 前脸间隙 6", length, config.backFoamMM),
                isLateral: false
            ))
        }

        guard !requirements.isEmpty else { return nil }

        let worstRatio = requirements.map { $0.needMM / $0.currentMM }.max() ?? 1
        let scalePercent = max(0, (worstRatio - 1) * 100)

        var directions: [String] = []
        for requirement in requirements where requirement.deltaMM > 0.5 {
            if requirement.isLateral {
                directions.append(String(format: "%@：两侧各 +%.1f mm（内腔总宽 +%.1f）", requirement.title, requirement.deltaMM / 2, requirement.deltaMM))
            } else if requirement.id == "height" {
                directions.append(String(format: "内腔顶部 +%.1f mm", requirement.deltaMM))
            } else {
                directions.append(String(format: "后壳向后 +%.1f mm", requirement.deltaMM))
            }
        }

        var notes: [String] = []
        if let eyeToChin = value(.eyeToChin), let holes = shell.eyeHoles {
            let delta = eyeToChin - holes.centerAboveInnerBottom
            if abs(delta) > 15 {
                notes.append(String(format: "眼位：实测眼-下巴 %.0fmm，该壳眼孔设计 %.0fmm，相差 %.0fmm。缩放无法解决，靠佩戴前倾角与内衬补偿；如需精准可整体上移眼孔。", eyeToChin, holes.centerAboveInnerBottom, delta))
            }
        }
        notes.append("试算基于记录中的测量数据与头壳档案；正式打印前建议先用试戴环实测海绵余量。")

        return Result(
            requirements: requirements,
            uniformScalePercent: scalePercent,
            directions: directions,
            notes: notes
        )
    }
}
