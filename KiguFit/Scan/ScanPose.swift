import Foundation

nonisolated enum ScanPose: String, CaseIterable, Identifiable, Codable, Sendable {
    case front
    case left
    case right
    case up
    case down

    var id: String { rawValue }

    static var standardSequence: [ScanPose] { allCases }

    var title: String {
        switch self {
        case .front: return "正视"
        case .left: return "向左转头"
        case .right: return "向右转头"
        case .up: return "抬头"
        case .down: return "低头"
        }
    }

    var instruction: String {
        switch self {
        case .front: return "正视手机，平视镜头"
        case .left: return "头慢慢向左转，看向左前方"
        case .right: return "头慢慢向右转，看向右前方"
        case .up: return "慢慢抬头，下巴微微抬起"
        case .down: return "慢慢低头，让镜头看到头顶"
        }
    }

    var systemImage: String {
        switch self {
        case .front: return "face.smiling"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        }
    }

    var targetFrames: Int {
        switch self {
        case .front: return 30
        default: return 20
        }
    }

    private var yawRange: ClosedRange<Double> {
        switch self {
        case .front: return -12...12
        case .left: return 25...50
        case .right: return -50...(-25)
        case .up, .down: return -20...20
        }
    }

    private var pitchRange: ClosedRange<Double> {
        switch self {
        case .front: return -12...12
        case .up: return 18...45
        case .down: return -45...(-18)
        case .left, .right: return -20...20
        }
    }

    func matches(yaw: Double, pitch: Double) -> Bool {
        yawRange.contains(yaw) && pitchRange.contains(pitch)
    }

    func feedback(yaw: Double, pitch: Double) -> String {
        if matches(yaw: yaw, pitch: pitch) {
            return "保持不动"
        }
        switch self {
        case .front:
            if abs(yaw) > 12 { return "请正对手机（当前偏转 \(Int(yaw.rounded()))°）" }
            return "请平视镜头（当前俯仰 \(Int(pitch.rounded()))°）"
        case .left:
            if yaw < 25 { return "再向左转一点" }
            if yaw > 50 { return "转得太多，稍微回来一点" }
            return "保持头部水平"
        case .right:
            if yaw > -25 { return "再向右转一点" }
            if yaw < -50 { return "转得太多，稍微回来一点" }
            return "保持头部水平"
        case .up:
            if pitch < 18 { return "再抬高一点" }
            if pitch > 45 { return "抬得太多，稍微低一点" }
            return "保持正视（不要转头）"
        case .down:
            if pitch > -18 { return "再低一点" }
            if pitch < -45 { return "低得太多，稍微抬一点" }
            return "保持正视（不要转头）"
        }
    }
}
