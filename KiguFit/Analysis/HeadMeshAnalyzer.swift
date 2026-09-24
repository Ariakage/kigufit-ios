import Foundation
import simd

nonisolated struct HeadScanAnalysis: Sendable {
    var name: String
    var unitScaleApplied: Double
    var upAxisLabel: String
    var headWidth: Double
    var headDepth: Double
    var headHeightApprox: Double
    var estimatedCircumference: Double
    var hadShoulders: Bool
    var notes: [String]

    func measurements() -> [MeasurementValue] {
        [
            MeasurementValue(key: .headWidth, valueMM: headWidth, source: .scan, confidence: 0.6),
            MeasurementValue(key: .headDepth, valueMM: headDepth, source: .scan, confidence: 0.55),
            MeasurementValue(key: .headCircumference, valueMM: estimatedCircumference, source: .estimated, confidence: 0.35)
        ]
    }
}

nonisolated enum HeadMeshAnalyzer {
    enum AnalysisError: Error, LocalizedError {
        case tooFewVertices
        case orientationFailed

        var errorDescription: String? {
            switch self {
            case .tooFewVertices: return "网格数据太少，无法测量"
            case .orientationFailed: return "无法判断模型朝向"
            }
        }
    }

    private static let axisLabels = ["X", "Y", "Z"]

    static func analyze(mesh: OBJMesh, name: String) throws -> HeadScanAnalysis {
        let n = mesh.vertexCount
        guard n > 200 else { throw AnalysisError.tooFewVertices }

        var positions = [SIMD3<Float>](repeating: .zero, count: n)
        for i in 0..<n { positions[i] = mesh.vertex(i) }

        var mn = positions[0]
        var mx = positions[0]
        for p in positions {
            mn = simd_min(mn, p)
            mx = simd_max(mx, p)
        }
        let sizes = SIMD3<Float>(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
        let maxExtent = Double(max(sizes.x, max(sizes.y, sizes.z)))
        let scale = maxExtent < 10 ? 1000.0 : 1.0

        var bestAxis = 0
        var bestScore = -Double.greatestFiniteMagnitude
        var bestUpPositive = true

        for axis in 0..<3 {
            let others = [0, 1, 2].filter { $0 != axis }
            let low = Double(mn[axis])
            let high = Double(mx[axis])
            let slab = (high - low) * 0.10

            var lowMin = SIMD2<Double>(repeating: .greatestFiniteMagnitude)
            var lowMax = SIMD2<Double>(repeating: -.greatestFiniteMagnitude)
            var highMin = SIMD2<Double>(repeating: .greatestFiniteMagnitude)
            var highMax = SIMD2<Double>(repeating: -.greatestFiniteMagnitude)
            var lowCount = 0
            var highCount = 0

            for p in positions {
                let value = Double(p[axis])
                let pair = SIMD2<Double>(Double(p[others[0]]), Double(p[others[1]]))
                if value < low + slab {
                    lowMin = simd_min(lowMin, pair)
                    lowMax = simd_max(lowMax, pair)
                    lowCount += 1
                } else if value > high - slab {
                    highMin = simd_min(highMin, pair)
                    highMax = simd_max(highMax, pair)
                    highCount += 1
                }
            }

            guard lowCount > 5, highCount > 5 else { continue }
            let lowArea = max((lowMax.x - lowMin.x) * (lowMax.y - lowMin.y), 0.0001)
            let highArea = max((highMax.x - highMin.x) * (highMax.y - highMin.y), 0.0001)
            let score = abs(log(highArea / lowArea))
            if score > bestScore {
                bestScore = score
                bestAxis = axis
                bestUpPositive = highArea < lowArea
            }
        }
        guard bestScore > 0.001 else { throw AnalysisError.orientationFailed }

        let upAxis = bestAxis
        let lateralAxes = [0, 1, 2].filter { $0 != upAxis }
        let widthAxis = lateralAxes[0]
        let depthAxis = lateralAxes[1]

        let slabCount = 80
        let heightLow = Double(mn[upAxis])
        let heightHigh = Double(mx[upAxis])
        let slabHeight = (heightHigh - heightLow) / Double(slabCount)

        var rawWidths = [Double](repeating: 0, count: slabCount)
        var rawDepths = [Double](repeating: 0, count: slabCount)

        for index in 0..<slabCount {
            let low = heightLow + slabHeight * Double(index)
            let high = low + slabHeight
            var wMin = Double.greatestFiniteMagnitude
            var wMax = -Double.greatestFiniteMagnitude
            var dMin = Double.greatestFiniteMagnitude
            var dMax = -Double.greatestFiniteMagnitude
            var count = 0
            for p in positions {
                let value = Double(p[upAxis])
                guard value >= low, value < high else { continue }
                let w = Double(p[widthAxis])
                let d = Double(p[depthAxis])
                wMin = min(wMin, w)
                wMax = max(wMax, w)
                dMin = min(dMin, d)
                dMax = max(dMax, d)
                count += 1
            }
            if count > 4 {
                rawWidths[index] = (wMax - wMin) * scale
                rawDepths[index] = (dMax - dMin) * scale
            }
        }

        let widths = bestUpPositive ? rawWidths.reversed().map { $0 } : rawWidths
        let depths = bestUpPositive ? rawDepths.reversed().map { $0 } : rawDepths

        var trimTop = 0
        while trimTop < slabCount / 3, widths[trimTop] < 5 {
            trimTop += 1
        }

        let widestSearchEnd = max(trimTop + 5, slabCount * 70 / 100)
        var widestIndex = trimTop
        var widestValue = 0.0
        if widestSearchEnd > trimTop {
            for index in trimTop..<widestSearchEnd where widths[index] > widestValue {
                widestValue = widths[index]
                widestIndex = index
            }
        }

        let neckSearchStart = widestIndex + 2
        let neckSearchEnd = slabCount * 95 / 100
        var neckIndex = -1
        var neckWidth = Double.greatestFiniteMagnitude
        if neckSearchStart < neckSearchEnd {
            for index in neckSearchStart..<neckSearchEnd where widths[index] < neckWidth {
                neckWidth = widths[index]
                neckIndex = index
            }
        }

        var headRange: Range<Int>
        var hadShoulders = false

        if neckIndex > widestIndex, neckIndex > 0 {
            var maxAfterNeck = 0.0
            let scanStart = min(neckIndex + 2, slabCount)
            if scanStart < neckSearchEnd {
                for index in scanStart..<neckSearchEnd {
                    maxAfterNeck = max(maxAfterNeck, widths[index])
                }
            }
            hadShoulders = maxAfterNeck > max(neckWidth * 1.25, neckWidth + 30)
        }

        if hadShoulders {
            headRange = trimTop..<neckIndex
        } else {
            let fallbackEnd = min(trimTop + slabCount * 55 / 100, slabCount - 1)
            headRange = trimTop..<max(fallbackEnd, trimTop + 4)
        }

        var headWidth = 0.0
        var headDepth = 0.0
        for index in headRange {
            headWidth = max(headWidth, widths[index])
            headDepth = max(headDepth, depths[index])
        }
        guard headWidth > 20, headDepth > 20 else { throw AnalysisError.orientationFailed }

        let headHeight = Double(headRange.count) * slabHeight * scale
        let circumference = ellipsePerimeter(a: headWidth / 2, b: headDepth / 2)

        var notes: [String] = []
        if scale != 1 {
            notes.append("模型单位为米，已换算为毫米（×1000）")
        }
        notes.append("扫描含头套/头发厚度（约 2–5mm），头围为椭圆估算，误差约 ±1–2cm")
        if hadShoulders {
            notes.append("已通过颈部收窄/肩部特征自动截取头部区域")
        } else {
            notes.append("未检测到明显肩部，按模型上部 55% 估算头部区域")
        }
        notes.append(String(format: "头顶到颈部高度约 %.0f mm", headHeight))

        return HeadScanAnalysis(
            name: name,
            unitScaleApplied: scale,
            upAxisLabel: axisLabels[upAxis] + (bestUpPositive ? "+" : "-"),
            headWidth: headWidth,
            headDepth: headDepth,
            headHeightApprox: headHeight,
            estimatedCircumference: circumference,
            hadShoulders: hadShoulders,
            notes: notes
        )
    }

    private static func ellipsePerimeter(a: Double, b: Double) -> Double {
        Double.pi * (3 * (a + b) - ((3 * a + b) * (a + 3 * b)).squareRoot())
    }
}
