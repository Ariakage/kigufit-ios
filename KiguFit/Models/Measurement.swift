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

    var guide: MeasurementGuide? {
        switch self {
        case .headCircumference:
            return MeasurementGuide(
                method: [
                    "用软尺从眉弓上方、耳朵上方出发，水平绕头一周",
                    "在额头上方约 1cm 处让软尺交叉，读取交叉点数值",
                    "重复测量两次取平均值，两次差值不超过 5mm"
                ],
                location: "经过前额最凸点与后脑最凸点，高于耳朵上缘",
                details: [
                    "软尺贴住皮肤但不勒紧，发厚时可略压平头发",
                    "保持软尺水平，不要斜着从前额绕到后颈",
                    "读数时视线与软尺垂直，避免斜视读偏"
                ]
            )
        case .headHeight:
            return MeasurementGuide(
                method: [
                    "贴墙站立，下巴自然闭合（不要仰头或低头）",
                    "用直尺或书本水平压住头顶最高点，标记墙面",
                    "测量地面（或椅面）到标记点的垂直距离"
                ],
                location: "下巴尖最低点到头顶最高点的垂直距离",
                details: [
                    "头发蓬松时压平再量；不要用力压头",
                    "下颌自然放松，牙齿轻咬合",
                    "建议请他人协助读取，减少误差"
                ]
            )
        case .headWidth:
            return MeasurementGuide(
                method: [
                    "用两把直尺或两本书夹住头部两侧最宽处",
                    "保持两尺平行，取出后测量两尺间距"
                ],
                location: "耳朵上方、头部最宽处（约眉上 3–5cm 水平）",
                details: [
                    "夹持力度以贴住头发不压陷为准",
                    "此值用于与头壳内腔宽度对照，务必量至最宽处",
                    "可与扫描的头宽估算值交叉验证"
                ]
            )
        case .headDepth:
            return MeasurementGuide(
                method: [
                    "用两把直尺分别贴住额头最凸点和后脑最凸点",
                    "保持两尺平行，取出后测量间距"
                ],
                location: "眉间额头最凸点 → 后脑最凸点，水平直线距离",
                details: [
                    "不要沿弧线量（那是额-顶-后脑弧）",
                    "头发厚的位置以头皮为准"
                ]
            )
        case .earToEarOverTop:
            return MeasurementGuide(
                method: [
                    "软尺一端放于一侧耳根上缘",
                    "沿头顶正中越过，拉到另一侧耳根上缘",
                    "读取弧线长度"
                ],
                location: "左耳根上缘 → 头顶正中 → 右耳根上缘",
                details: [
                    "软尺要贴头皮、走头顶正中线",
                    "头发厚时可略压平"
                ]
            )
        case .foreheadToOcciputOverTop:
            return MeasurementGuide(
                method: [
                    "软尺一端放于眉上额头正中（发际线附近）",
                    "沿头顶正中越过后脑最凸点",
                    "读取弧线长度"
                ],
                location: "额头正中（眉上） → 头顶正中 → 后脑最凸点",
                details: [
                    "与头长（直线）不同，这是贴合头皮的弧长",
                    "用于估算头壳前后方向的内腔余量"
                ]
            )
        case .neckCircumference:
            return MeasurementGuide(
                method: [
                    "软尺绕喉结下方最细处一周",
                    "保持水平，读数即可"
                ],
                location: "喉结下方、颈部最细处",
                details: [
                    "不要勒紧，留一指余量",
                    "此值用于评估头壳底部开口与颈部活动空间"
                ]
            )
        default:
            return nil
        }
    }
}

nonisolated struct MeasurementGuide: Hashable, Sendable {
    var method: [String]
    var location: String
    var details: [String]
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
