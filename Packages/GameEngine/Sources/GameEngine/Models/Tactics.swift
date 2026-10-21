import Foundation

public enum Formation: String, Codable, CaseIterable, Hashable, Sendable {
    case f433 = "4-3-3"
    case f442 = "4-4-2"
    case f4231 = "4-2-3-1"
    case f352 = "3-5-2"
    case f532 = "5-3-2"
    case f4141 = "4-1-4-1"
    case f4312 = "4-3-1-2"
    case f4321 = "4-3-2-1"
    case f343 = "3-4-3"
    case f451 = "4-5-1"

    /// Rows from the goalkeeper forward, each row listed left to right.
    public var rows: [[Position]] {
        switch self {
        case .f433:
            return [[.goalkeeper], [.fullBack, .centreBack, .centreBack, .fullBack],
                    [.centralMid, .defensiveMid, .centralMid], [.winger, .striker, .winger]]
        case .f442:
            return [[.goalkeeper], [.fullBack, .centreBack, .centreBack, .fullBack],
                    [.winger, .centralMid, .centralMid, .winger], [.striker, .striker]]
        case .f4231:
            return [[.goalkeeper], [.fullBack, .centreBack, .centreBack, .fullBack],
                    [.defensiveMid, .defensiveMid], [.winger, .attackingMid, .winger], [.striker]]
        case .f352:
            return [[.goalkeeper], [.centreBack, .centreBack, .centreBack],
                    [.fullBack, .centralMid, .defensiveMid, .centralMid, .fullBack], [.striker, .striker]]
        case .f532:
            return [[.goalkeeper], [.fullBack, .centreBack, .centreBack, .centreBack, .fullBack],
                    [.centralMid, .defensiveMid, .centralMid], [.striker, .striker]]
        case .f4141:
            return [[.goalkeeper], [.fullBack, .centreBack, .centreBack, .fullBack],
                    [.defensiveMid], [.winger, .centralMid, .centralMid, .winger], [.striker]]
        case .f4312:
            return [[.goalkeeper], [.fullBack, .centreBack, .centreBack, .fullBack],
                    [.centralMid, .defensiveMid, .centralMid], [.attackingMid], [.striker, .striker]]
        case .f4321:
            return [[.goalkeeper], [.fullBack, .centreBack, .centreBack, .fullBack],
                    [.centralMid, .defensiveMid, .centralMid], [.attackingMid, .attackingMid], [.striker]]
        case .f343:
            return [[.goalkeeper], [.centreBack, .centreBack, .centreBack],
                    [.fullBack, .centralMid, .centralMid, .fullBack], [.winger, .striker, .winger]]
        case .f451:
            return [[.goalkeeper], [.fullBack, .centreBack, .centreBack, .fullBack],
                    [.winger, .centralMid, .defensiveMid, .centralMid, .winger], [.striker]]
        }
    }

    /// The eleven slots in the order used by `Tactics.starters`.
    public var slots: [Position] { rows.flatMap { $0 } }

    /// Small style bonus: attacking shapes score more and concede more.
    var attackModifier: Double {
        switch self {
        case .f433: return 1
        case .f442: return 0
        case .f4231: return -0.5
        case .f352: return 1.5
        case .f532: return -1.5
        case .f4141: return -0.5
        case .f4312: return 0.5
        case .f4321: return 0.5
        case .f343: return 2
        case .f451: return -1
        }
    }

    var defenceModifier: Double { -attackModifier }
}

/// The user's team selection. AI clubs pick automatically every match.
public struct Tactics: Codable, Hashable, Sendable {
    public static let benchSize = 7

    public var formation: Formation
    /// One entry per formation slot (nil = empty, filled automatically at kick-off).
    public var starters: [UUID?]
    /// Substitutes, in the order the user arranged them.
    public var bench: [UUID]
}

/// A place on the team sheet screen. Reserves are everyone not starting or on the bench.
public enum LineupRef: Hashable, Sendable {
    case starter(Int)
    case bench(Int)
    case reserve(UUID)
}
