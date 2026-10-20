import Foundation

public struct Contract: Codable, Hashable, Sendable {
    /// Weekly wage in euros.
    public var weeklyWage: Int
    /// Last season the contract covers (e.g. 2028 means it ends after the 2028 season).
    public var expiresSeason: Int
}

public struct SeasonStats: Codable, Hashable, Sendable {
    public var appearances: Int = 0
    public var goals: Int = 0
    public var assists: Int = 0
    public var ratingSum: Double = 0

    public var averageRating: Double {
        appearances == 0 ? 0 : ratingSum / Double(appearances)
    }
}

public struct Player: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var firstName: String
    public var lastName: String
    /// Country code from `NamePools` (e.g. "TR", "BR").
    public var nationality: String
    public var birthYear: Int
    public var position: Position
    public var attributes: Attributes
    public var potential: Int
    /// 0...100
    public var morale: Int
    /// 0...100. Drops after every match and recovers between matches.
    public var fitness: Int
    /// Last five match ratings, newest last.
    public var recentRatings: [Double]
    public var clubID: UUID?
    public var contract: Contract
    public var injuryWeeks: Int
    /// Put up for sale by the user; AI clubs bid for listed players more often.
    public var isTransferListed: Bool
    public var stats: SeasonStats
    public var careerGoals: Int
    public var careerAppearances: Int

    /// Fractional development accumulated between attribute changes.
    var developmentProgress: Double
    /// Appearances since the last development tick (playing-time factor).
    var appearancesSinceTick: Int

    public var fullName: String { "\(firstName) \(lastName)" }
    public var shortName: String { "\(firstName.prefix(1)). \(lastName)" }
    public var initials: String { "\(firstName.prefix(1))\(lastName.prefix(1))" }

    public var overall: Int { attributes.overall(for: position) }

    public var isInjured: Bool { injuryWeeks > 0 }

    public func age(in season: Int) -> Int { season - birthYear }

    /// Average of recent ratings, or nil when the player hasn't played yet.
    public var form: Double? {
        recentRatings.isEmpty ? nil : recentRatings.reduce(0, +) / Double(recentRatings.count)
    }

    /// The player's three best attributes, best first (goalkeeping only counts for keepers).
    public var topAttributes: [AttributeKind] {
        let kinds = AttributeKind.allCases.filter { position == .goalkeeper || $0 != .goalkeeping }
        let ranked = kinds.enumerated().sorted { lhs, rhs in
            let left = attributes[lhs.element]
            let right = attributes[rhs.element]
            return left != right ? left > right : lhs.offset < rhs.offset
        }
        return ranked.prefix(3).map(\.element)
    }

    /// Market value in euros.
    public func marketValue(season: Int) -> Int {
        let playerAge = self.age(in: season)
        var value = 1_000_000 * pow(1.175, Double(overall - 60))
        switch playerAge {
        case ...21:
            value *= 1.0 + Double(max(0, potential - overall)) * 0.045
        case 22...27:
            value *= 1.0 + Double(max(0, potential - overall)) * 0.02
        case 28...30:
            value *= 0.8
        case 31...33:
            value *= 0.5
        default:
            value *= 0.25
        }
        let yearsLeft = contract.expiresSeason - season
        if yearsLeft <= 0 { value *= 0.6 } else if yearsLeft == 1 { value *= 0.8 }
        let rounded = (value / 25_000).rounded() * 25_000
        return max(25_000, Int(rounded))
    }

    /// Wage a player of this quality would expect on a new contract.
    public func expectedWage(season: Int) -> Int {
        let raw = Double(marketValue(season: season)) * 0.0018 + 6_000
        return Int((raw / 500).rounded() * 500)
    }

    mutating func recordMatch(rating: Double, goals: Int, assists: Int) {
        stats.appearances += 1
        stats.goals += goals
        stats.assists += assists
        stats.ratingSum += rating
        careerAppearances += 1
        careerGoals += goals
        appearancesSinceTick += 1
        recentRatings.append(rating)
        if recentRatings.count > 5 { recentRatings.removeFirst(recentRatings.count - 5) }
    }
}
