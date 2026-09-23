import Foundation

nonisolated enum MeasurementSource: String, Codable, CaseIterable, Hashable, Sendable {
    case scan
    case tape
    case estimated

    var displayName: String {
        switch self {
        case .scan: return "扫描"
        case .tape: return "软尺"
        case .estimated: return "估算"
        }
    }
}

nonisolated enum MeasurementKey: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case headCircumference
    case headHeight
    case headWidth
    case headDepth
    case earToEarOverTop
    case foreheadToOcciputOverTop
    case neckCircumference
    case interpupillaryDistance
    case templeWidth
    case bizygomaticWidth
    case chinWidth
    case eyeToChin
    case chinToMouth
    case mouthWidth
    case noseDepth
    case faceLength

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .headCircumference: return "头围"
        case .headHeight: return "头高（下巴-头顶）"
        case .headWidth: return "头宽（耳上最宽）"
        case .headDepth: return "头长（额-后脑）"
        case .earToEarOverTop: return "耳-耳过头顶弧"
        case .foreheadToOcciputOverTop: return "额-后脑过头顶弧"
        case .neckCircumference: return "脖围"
        case .interpupillaryDistance: return "瞳距"
        case .templeWidth: return "太阳穴宽"
        case .bizygomaticWidth: return "颧骨宽"
        case .chinWidth: return "下巴宽"
        case .eyeToChin: return "眼睛高度（瞳线-下巴）"
        case .chinToMouth: return "下巴高度（下巴-嘴缝）"
        case .mouthWidth: return "嘴部区宽（嘴线水平）"
        case .noseDepth: return "鼻深"
        case .faceLength: return "脸长（发际线-下巴）"
        }
    }

    var isTapeItem: Bool {
        switch self {
        case .headCircumference, .headHeight, .headWidth, .headDepth,
             .earToEarOverTop, .foreheadToOcciputOverTop, .neckCircumference:
            return true
        default:
            return false
        }
    }

    var isRequired: Bool {
        self == .headCircumference || self == .headHeight
    }

    var defaultSource: MeasurementSource {
        isTapeItem ? .tape : .scan
    }

    var tapeHint: String? {
        switch self {
        case .headCircumference:
            return "软尺经眉上、耳上，绕头一周（不压紧），读数取最宽处"
        case .headHeight:
            return "下巴尖到头顶最高点的垂直距离，可贴墙量"
        case .headWidth:
            return "耳上方头部最宽处，左右两侧直线距离"
        case .headDepth:
            return "额头最突出处到后脑最突出处的直线距离"
        case .earToEarOverTop:
            return "从一侧耳根经头顶到另一侧耳根的弧线长度"
        case .foreheadToOcciputOverTop:
            return "从额头（眉上）经头顶到后脑最突出处的弧线长度"
        case .neckCircumference:
            return "喉结下方，颈部最细处绕一周"
        default:
            return nil
        }
    }
}

nonisolated struct MeasurementValue: Codable, Hashable, Sendable, Identifiable {
    var key: MeasurementKey
    var valueMM: Double
    var source: MeasurementSource
    var confidence: Double

    var id: String { key.rawValue }

    init(key: MeasurementKey, valueMM: Double, source: MeasurementSource? = nil, confidence: Double? = nil) {
        self.key = key
        self.valueMM = valueMM
        self.source = source ?? key.defaultSource
        if let confidence {
            self.confidence = confidence
        } else {
            switch self.source {
            case .tape: self.confidence = 1.0
            case .scan: self.confidence = 0.85
            case .estimated: self.confidence = 0.5
            }
        }
    }
}

extension Array where Element == MeasurementValue {
    func value(for key: MeasurementKey) -> MeasurementValue? {
        first { $0.key == key }
    }
}
