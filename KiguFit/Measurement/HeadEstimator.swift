import Foundation

nonisolated enum HeadEstimator {
    static func complete(_ measurements: [MeasurementValue]) -> [MeasurementValue] {
        var dict = Dictionary(uniqueKeysWithValues: measurements.map { ($0.key, $0) })

        func value(_ key: MeasurementKey) -> Double? {
            dict[key]?.valueMM
        }

        let circumference = value(.headCircumference)

        if dict[.headWidth] == nil, let circumference {
            dict[.headWidth] = MeasurementValue(key: .headWidth, valueMM: circumference * 0.264, source: .estimated, confidence: 0.4)
        }
        if dict[.headDepth] == nil, let circumference {
            dict[.headDepth] = MeasurementValue(key: .headDepth, valueMM: circumference * 0.35, source: .estimated, confidence: 0.4)
        }
        if dict[.neckCircumference] == nil, let circumference {
            dict[.neckCircumference] = MeasurementValue(key: .neckCircumference, valueMM: circumference * 0.65, source: .estimated, confidence: 0.35)
        }

        let headDepth = value(.headDepth)
        let headWidth = value(.headWidth)
        let headHeight = value(.headHeight)

        if dict[.foreheadToOcciputOverTop] == nil, let headDepth, let headHeight {
            let arc = halfEllipsePerimeter(a: headDepth / 2, b: headHeight / 2)
            dict[.foreheadToOcciputOverTop] = MeasurementValue(key: .foreheadToOcciputOverTop, valueMM: arc, source: .estimated, confidence: 0.4)
        }
        if dict[.earToEarOverTop] == nil, let headWidth, let headHeight {
            let arc = halfEllipsePerimeter(a: headWidth / 2, b: headHeight / 2)
            dict[.earToEarOverTop] = MeasurementValue(key: .earToEarOverTop, valueMM: arc, source: .estimated, confidence: 0.4)
        }

        return MeasurementKey.allCases.compactMap { dict[$0] }
    }

    static func halfEllipsePerimeter(a: Double, b: Double) -> Double {
        let full = Double.pi * (3 * (a + b) - ((3 * a + b) * (a + 3 * b)).squareRoot())
        return full / 2
    }
}
