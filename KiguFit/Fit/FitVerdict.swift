import Foundation

nonisolated struct FitVerdict: Codable, Hashable, Sendable {
    enum Level: String, Codable, CaseIterable, Hashable, Sendable {
        case good
        case tight
        case loose
        case unfit

        var displayName: String {
            switch self {
            case .good: return "适配"
            case .tight: return "偏紧"
            case .loose: return "偏松"
            case .unfit: return "不适配"
            }
        }
    }

    struct Check: Codable, Hashable, Sendable {
        enum Status: String, Codable, Hashable, Sendable {
            case ok
            case warn
            case fail

            var displayName: String {
                switch self {
                case .ok: return "正常"
                case .warn: return "注意"
                case .fail: return "超限"
                }
            }
        }

        var title: String
        var shellValueMM: Double?
        var measuredMM: Double?
        var marginMM: Double?
        var status: Status
        var detail: String
    }

    struct Suggestion: Codable, Hashable, Sendable {
        enum Kind: String, Codable, Hashable, Sendable {
            case padding
            case scale
            case note
        }

        var kind: Kind
        var detail: String
        var valueMM: Double?
        var scalePercent: Double?
    }

    var level: Level
    var summary: String
    var checks: [Check]
    var suggestions: [Suggestion]
}
