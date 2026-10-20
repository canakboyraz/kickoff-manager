import Foundation

public enum AttributeKind: String, Codable, CaseIterable, Sendable {
    case pace, shooting, passing, dribbling, defending, physical, goalkeeping
}

public struct Attributes: Codable, Hashable, Sendable {
    public var pace: Int
    public var shooting: Int
    public var passing: Int
    public var dribbling: Int
    public var defending: Int
    public var physical: Int
    public var goalkeeping: Int

    public static let range = 1...99

    public subscript(kind: AttributeKind) -> Int {
        get {
            switch kind {
            case .pace: return pace
            case .shooting: return shooting
            case .passing: return passing
            case .dribbling: return dribbling
            case .defending: return defending
            case .physical: return physical
            case .goalkeeping: return goalkeeping
            }
        }
        set {
            let value = newValue.clamped(to: Attributes.range)
            switch kind {
            case .pace: pace = value
            case .shooting: shooting = value
            case .passing: passing = value
            case .dribbling: dribbling = value
            case .defending: defending = value
            case .physical: physical = value
            case .goalkeeping: goalkeeping = value
            }
        }
    }

    /// Importance of each attribute for a position. Each row sums to 1.
    public static func weights(for position: Position) -> [AttributeKind: Double] {
        switch position {
        case .goalkeeper:
            return [.goalkeeping: 0.85, .physical: 0.08, .passing: 0.07]
        case .centreBack:
            return [.defending: 0.45, .physical: 0.30, .pace: 0.10, .passing: 0.15]
        case .fullBack:
            return [.pace: 0.30, .defending: 0.35, .passing: 0.20, .physical: 0.15]
        case .defensiveMid:
            return [.defending: 0.35, .passing: 0.35, .physical: 0.20, .dribbling: 0.10]
        case .centralMid:
            return [.passing: 0.40, .dribbling: 0.20, .defending: 0.15, .physical: 0.10, .shooting: 0.15]
        case .attackingMid:
            return [.passing: 0.30, .dribbling: 0.35, .shooting: 0.25, .pace: 0.10]
        case .winger:
            return [.pace: 0.35, .dribbling: 0.35, .shooting: 0.15, .passing: 0.15]
        case .striker:
            return [.shooting: 0.50, .pace: 0.20, .physical: 0.15, .dribbling: 0.15]
        }
    }

    public func overall(for position: Position) -> Int {
        let weights = Attributes.weights(for: position)
        // Sum in a fixed order: dictionary order varies between instances, and a different
        // order of floating-point additions can round a .5 total differently.
        var total = 0.0
        for kind in AttributeKind.allCases {
            if let weight = weights[kind] { total += Double(self[kind]) * weight }
        }
        return Int(total.rounded()).clamped(to: Attributes.range)
    }
}
