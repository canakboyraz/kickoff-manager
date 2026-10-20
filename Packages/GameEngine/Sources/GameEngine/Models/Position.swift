import Foundation

public enum Position: String, Codable, CaseIterable, Hashable, Sendable {
    case goalkeeper = "GK"
    case centreBack = "CB"
    case fullBack = "FB"
    case defensiveMid = "DM"
    case centralMid = "CM"
    case attackingMid = "AM"
    case winger = "W"
    case striker = "ST"

    public enum Line: String, Codable, CaseIterable, Sendable {
        case goalkeeper, defence, midfield, attack
    }

    public var line: Line {
        switch self {
        case .goalkeeper: return .goalkeeper
        case .centreBack, .fullBack: return .defence
        case .defensiveMid, .centralMid, .attackingMid: return .midfield
        case .winger, .striker: return .attack
        }
    }

    /// Sort order used for squad lists (goalkeeper first, striker last).
    public var sortIndex: Int {
        Position.allCases.firstIndex(of: self) ?? 0
    }

    /// How likely a player in this position is to score, before shooting skill.
    var scoringWeight: Double {
        switch self {
        case .goalkeeper: return 0
        case .centreBack: return 0.5
        case .fullBack: return 0.4
        case .defensiveMid: return 0.5
        case .centralMid: return 1.2
        case .attackingMid: return 3
        case .winger: return 3
        case .striker: return 5.5
        }
    }

    /// How likely a player in this position is to assist, before passing skill.
    var assistWeight: Double {
        switch self {
        case .goalkeeper: return 0.05
        case .centreBack: return 0.4
        case .fullBack: return 1.2
        case .defensiveMid: return 1
        case .centralMid: return 2
        case .attackingMid: return 3
        case .winger: return 3
        case .striker: return 1.5
        }
    }
}
