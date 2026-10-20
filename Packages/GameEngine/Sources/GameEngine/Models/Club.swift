import Foundation

public struct ClubColors: Codable, Hashable, Sendable {
    /// Hex strings without '#', e.g. "185FA5".
    public var primary: String
    public var secondary: String
}

public struct Stadium: Codable, Hashable, Sendable {
    public var name: String
    public var capacity: Int
    /// Average ticket price in euros.
    public var ticketPrice: Int
}

public enum FacilityKind: String, Codable, CaseIterable, Hashable, Sendable {
    /// Faster player development.
    case training
    /// Better youth intake.
    case youth
    /// Fewer and shorter injuries.
    case medical
    /// Adds seats to the stadium.
    case stadium
}

public struct Facilities: Codable, Hashable, Sendable {
    public static let maxLevel = 10

    public var training: Int
    public var youth: Int
    public var medical: Int

    public func level(_ kind: FacilityKind) -> Int {
        switch kind {
        case .training: return training
        case .youth: return youth
        case .medical: return medical
        case .stadium: return 0
        }
    }

    mutating func raise(_ kind: FacilityKind) {
        switch kind {
        case .training: training = min(Facilities.maxLevel, training + 1)
        case .youth: youth = min(Facilities.maxLevel, youth + 1)
        case .medical: medical = min(Facilities.maxLevel, medical + 1)
        case .stadium: break
        }
    }
}

public struct FacilityUpgrade: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var kind: FacilityKind
    public var weeksRemaining: Int
    public var totalWeeks: Int
}

public struct Finances: Codable, Hashable, Sendable {
    /// Cash in the bank, in euros. Transfers and upgrades are paid from here,
    /// limited by the transfer budget.
    public var balance: Int
    public var transferBudget: Int
    /// Maximum total weekly wage bill the board allows.
    public var wageBudget: Int

    /// Running totals for the current season (shown on the club screen).
    public var seasonIncome: Int = 0
    public var seasonExpenses: Int = 0
}

public struct Club: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var shortName: String
    public var countryCode: String
    public var leagueID: UUID
    /// 1...100. Drives attendance, sponsorship and how attractive the club is.
    public var reputation: Int
    public var colors: ClubColors
    public var stadium: Stadium
    public var facilities: Facilities
    public var finances: Finances
    public var playerIDs: [UUID]
    public var upgrades: [FacilityUpgrade]

    /// Weekly sponsorship and commercial income.
    public var weeklyCommercialIncome: Int {
        let rep = Double(reputation)
        return Int(rep * rep * 22 + 15_000)
    }
}
