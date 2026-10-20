import Foundation

public struct UpgradeQuote: Hashable, Sendable {
    public var kind: FacilityKind
    public var cost: Int
    public var weeks: Int
    /// Current level (for stadium: current capacity).
    public var currentValue: Int
    /// Level or capacity after the upgrade.
    public var nextValue: Int
    public var isMaxed: Bool
    public var inProgress: FacilityUpgrade?
}

public enum UpgradeOutcome: Equatable, Sendable {
    case started
    case insufficientFunds
    case alreadyInProgress
    case maxLevel
}

extension Career {
    public static let stadiumExpansionSeats = 5_000
    public static let maxStadiumCapacity = 85_000

    public func upgradeQuote(_ kind: FacilityKind) -> UpgradeQuote {
        let club = userClub
        let inProgress = club.upgrades.first { $0.kind == kind }
        switch kind {
        case .stadium:
            let capacity = club.stadium.capacity
            return UpgradeQuote(
                kind: kind,
                cost: 8_000_000 + capacity * 120,
                weeks: 16,
                currentValue: capacity,
                nextValue: min(Career.maxStadiumCapacity, capacity + Career.stadiumExpansionSeats),
                isMaxed: capacity >= Career.maxStadiumCapacity,
                inProgress: inProgress
            )
        case .training, .youth, .medical:
            let level = club.facilities.level(kind)
            let base: Double = kind == .training ? 1_500_000 : (kind == .youth ? 1_200_000 : 1_000_000)
            let cost = Career.roundTo(base * pow(1.45, Double(level - 1)), step: 50_000)
            return UpgradeQuote(
                kind: kind,
                cost: cost,
                weeks: 4 + level,
                currentValue: level,
                nextValue: min(Facilities.maxLevel, level + 1),
                isMaxed: level >= Facilities.maxLevel,
                inProgress: inProgress
            )
        }
    }

    /// Upgrades are paid from the bank balance, not from the transfer budget.
    public mutating func startUpgrade(_ kind: FacilityKind) -> UpgradeOutcome {
        let quote = upgradeQuote(kind)
        guard quote.inProgress == nil else { return .alreadyInProgress }
        guard !quote.isMaxed else { return .maxLevel }
        guard userClub.finances.balance >= quote.cost else { return .insufficientFunds }
        clubs[userClubID]?.finances.balance -= quote.cost
        clubs[userClubID]?.finances.seasonExpenses += quote.cost
        clubs[userClubID]?.upgrades.append(FacilityUpgrade(id: UUID(), kind: kind, weeksRemaining: quote.weeks, totalWeeks: quote.weeks))
        return .started
    }

    public var userFairTicketPrice: Int { Career.fairTicketPrice(reputation: userClub.reputation) }

    public mutating func setTicketPrice(_ price: Int) {
        clubs[userClubID]?.stadium.ticketPrice = price.clamped(to: 5...200)
    }
}
