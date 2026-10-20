import Foundation

/// The user as a manager: how highly rated they are and how much the board trusts them.
public struct Manager: Codable, Hashable, Sendable {
    /// 1...100. Grows with success. Bigger clubs only offer jobs to reputable managers.
    public var reputation: Int
    /// 0...100. Falls with bad results; at `Career.sackingThreshold` or below the board sacks the manager.
    public var boardConfidence: Int
    public var trophies: Int
    public var timesSacked: Int
    public var seasonsManaged: Int
    /// Last board warning sent (0 none, 1 concerned, 2 final warning), so warnings aren't repeated.
    var warningLevel: Int

    static func starting(at club: Club) -> Manager {
        Manager(
            reputation: max(15, club.reputation - 10),
            boardConfidence: 60,
            trophies: 0,
            timesSacked: 0,
            seasonsManaged: 0,
            warningLevel: 0
        )
    }
}

/// What the board expects this season, from the club's standing in its league.
public enum BoardExpectation: String, Codable, Hashable, Sendable {
    case title
    case topThree
    case topHalf
    case midTable
    case survival
}

/// Another club wants the user as its manager.
public struct JobOffer: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var clubID: UUID
    public var expiresWeek: Int
}
