import Foundation
import simd

nonisolated enum MeasurementEngine {
    static func measurements(from capture: ScanCaptureResult) -> [MeasurementValue] {
        let vertices = capture.averagedVertices
        guard vertices.count > 100 else { return [] }

        let ys = vertices.map { Double($0.y) }
        guard let yMin = ys.min(), let yMax = ys.max(), yMax > yMin else { return [] }
        let height = yMax - yMin

        func inBand(_ lower: Double, _ upper: Double) -> [SIMD3<Float>] {
            vertices.filter {
                let u = (Double($0.y) - yMin) / height
                return u >= lower && u <= upper
            }
        }

        func widthMM(_ points: [SIMD3<Float>]) -> Double? {
            guard points.count > 4 else { return nil }
            let xs = points.map { Double($0.x) }
            guard let minX = xs.min(), let maxX = xs.max() else { return nil }
            return (maxX - minX) * 1000
        }

        var values: [MeasurementValue] = []

        let ipd = Double(simd_distance(capture.leftEye, capture.rightEye)) * 1000
        if ipd > 40 && ipd < 90 {
            values.append(MeasurementValue(key: .interpupillaryDistance, valueMM: ipd, source: .scan, confidence: 0.9))
        }

        if let chin = widthMM(inBand(0.10, 0.22)) {
            values.append(MeasurementValue(key: .chinWidth, valueMM: chin, source: .scan, confidence: 0.75))
        }
        if let mouth = widthMM(inBand(0.24, 0.36)) {
            values.append(MeasurementValue(key: .mouthWidth, valueMM: mouth, source: .scan, confidence: 0.6))
        }
        if let cheek = widthMM(inBand(0.48, 0.62)) {
            values.append(MeasurementValue(key: .bizygomaticWidth, valueMM: cheek, source: .scan, confidence: 0.75))
        }
        if let temple = widthMM(inBand(0.66, 0.80)) {
            values.append(MeasurementValue(key: .templeWidth, valueMM: temple, source: .scan, confidence: 0.7))
            values.append(MeasurementValue(key: .headWidth, valueMM: temple + 10, source: .estimated, confidence: 0.45))
        }

        let midline = vertices.filter { abs($0.x) < 0.012 }
        let forwardSign = noseForwardSign(midline: midline, yMin: yMin, height: height)

        if let lip = midline
            .filter({
                let u = (Double($0.y) - yMin) / height
                return u >= 0.20 && u <= 0.38
            })
            .max(by: { Double($0.z) * forwardSign < Double($1.z) * forwardSign }) {
            let chinToMouth = (Double(lip.y) - yMin) * 1000
            if chinToMouth > 5 {
                values.append(MeasurementValue(key: .chinToMouth, valueMM: chinToMouth, source: .scan, confidence: 0.6))
            }
        }

        let eyeY = (Double(capture.leftEye.y) + Double(capture.rightEye.y)) / 2
        let eyeToChin = (eyeY - yMin) * 1000
        if eyeToChin > 50 && eyeToChin < 200 {
            values.append(MeasurementValue(key: .eyeToChin, valueMM: eyeToChin, source: .scan, confidence: 0.8))
        }

        if let nose = midline
            .filter({
                let u = (Double($0.y) - yMin) / height
                return u >= 0.35 && u <= 0.60
            })
            .max(by: { Double($0.z) * forwardSign < Double($1.z) * forwardSign }) {
            let cheekBand = inBand(0.48, 0.62)
            let cheekForwards = cheekBand.map { Double($0.z) * forwardSign }.sorted()
            if !cheekForwards.isEmpty {
                let cheekPlane = cheekForwards[cheekForwards.count / 2]
                let noseDepth = (Double(nose.z) * forwardSign - cheekPlane) * 1000
                if noseDepth > 0 && noseDepth < 60 {
                    values.append(MeasurementValue(key: .noseDepth, valueMM: noseDepth, source: .scan, confidence: 0.6))
                }
            }
        }

        let faceLength = height * 1000
        values.append(MeasurementValue(key: .faceLength, valueMM: faceLength, source: .scan, confidence: 0.65))

        return values.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    private static func noseForwardSign(midline: [SIMD3<Float>], yMin: Double, height: Double) -> Double {
        let candidates = midline.filter {
            let u = (Double($0.y) - yMin) / height
            return u >= 0.35 && u <= 0.60
        }
        guard let extreme = candidates.max(by: { abs(Double($0.z)) < abs(Double($1.z)) }) else { return 1 }
        return extreme.z >= 0 ? 1 : -1
    }
}
