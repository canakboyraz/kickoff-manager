import Foundation

/// What the user asks the scout to look for.
public struct ScoutBrief: Codable, Hashable, Sendable {
    public var position: Position?
    public var maxAge: Int?
    public var minPotential: Int?
    /// Country code of the league to search, or nil for every league (free agents included).
    public var countryCode: String?
    /// Highest market value worth reporting.
    public var maxValue: Int?

    public init(position: Position? = nil, maxAge: Int? = nil, minPotential: Int? = nil,
                countryCode: String? = nil, maxValue: Int? = nil) {
        self.position = position
        self.maxAge = maxAge
        self.minPotential = minPotential
        self.countryCode = countryCode
        self.maxValue = maxValue
    }
}

/// A scout out on the road. Reports back when `weeksLeft` reaches zero.
public struct ScoutMission: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var brief: ScoutBrief
    public var weeksLeft: Int
    public var cost: Int
}

/// A player the scouts found. Their contacts make the deal cheaper this season.
public struct ScoutReport: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { playerID }
    public var playerID: UUID
    public var season: Int
    /// Share knocked off the asking price (e.g. 0.18 = 18% cheaper).
    public var feeDiscount: Double
    /// Share knocked off his wage demand.
    public var wageDiscount: Double
    /// Scout's verdict, 1–5 stars, based on potential.
    public var stars: Int
}

public enum ScoutResult: Equatable, Sendable {
    case started(weeks: Int)
    case tooManyMissions
    case insufficientFunds
}
