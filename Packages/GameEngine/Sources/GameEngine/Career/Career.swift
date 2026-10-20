import Foundation

public struct SeasonSummary: Codable, Hashable, Sendable {
    public var season: Int
    public var leagueName: String
    public var position: Int
    public var points: Int
    public var prizeMoney: Int
}

/// What happened when the user pressed "play week".
public struct WeekReport: Sendable {
    public var matchday: Int
    public var userFixture: Fixture?
    public var newMessages: [InboxMessage]
    /// Set when this week was the last matchday; the next season has already started.
    public var finishedSeason: SeasonSummary?
}

/// The whole save game. Value type: the app keeps one copy, mutates it and writes it to disk as JSON.
public struct Career: Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    /// Year the current season started in (e.g. 2026 for 2026/27).
    public internal(set) var season: Int
    /// Number of matchdays already played this season.
    public internal(set) var week: Int
    public internal(set) var userClubID: UUID
    public internal(set) var leagues: [League]
    public internal(set) var clubs: [UUID: Club]
    public internal(set) var players: [UUID: Player]
    public internal(set) var inbox: [InboxMessage]
    public internal(set) var offers: [IncomingOffer]
    public internal(set) var history: [SeasonSummary]
    var rng: SeededRandom
}

// MARK: - Read helpers used by the app

extension Career {
    public static var countries: [CountryInfo] { WorldData.countries }

    public var userClub: Club { clubs[userClubID]! }

    public var userLeague: League { league(userClub.leagueID)! }

    public func league(_ id: UUID) -> League? {
        leagues.first { $0.id == id }
    }

    public func club(_ id: UUID) -> Club? { clubs[id] }

    public func player(_ id: UUID) -> Player? { players[id] }

    public func clubs(in league: League) -> [Club] {
        league.clubIDs.compactMap { clubs[$0] }
    }

    /// Squad sorted goalkeeper → striker, best players first within a position.
    public func squad(of clubID: UUID) -> [Player] {
        (clubs[clubID]?.playerIDs ?? [])
            .compactMap { players[$0] }
            .sorted { ($0.position.sortIndex, -$0.overall) < ($1.position.sortIndex, -$1.overall) }
    }

    public var userSquad: [Player] { squad(of: userClubID) }

    public var userLineup: [LineupSlot] { MatchEngine.bestLineup(from: userSquad) }

    public func wageBill(of clubID: UUID) -> Int {
        (clubs[clubID]?.playerIDs ?? []).compactMap { players[$0]?.contract.weeklyWage }.reduce(0, +)
    }

    public var matchdayCount: Int { userLeague.matchdayCount }

    public var nextMatchday: Int { week + 1 }

    public var nextUserFixture: Fixture? {
        userLeague.fixtures.first { $0.matchday == nextMatchday && $0.involves(userClubID) }
    }

    public var lastUserFixture: Fixture? {
        userLeague.fixtures
            .filter { $0.involves(userClubID) && $0.result != nil }
            .max { $0.matchday < $1.matchday }
    }

    public var userFixtures: [Fixture] {
        userLeague.fixtures.filter { $0.involves(userClubID) }.sorted { $0.matchday < $1.matchday }
    }

    /// Summer window: first 4 matchdays. Winter window: 3 matchdays from the halfway point.
    public var isTransferWindowOpen: Bool {
        let half = matchdayCount / 2
        return week < 4 || (week >= half && week < half + 3)
    }

    public var unreadCount: Int { inbox.filter { !$0.isRead }.count }

    public var pendingOffers: [IncomingOffer] {
        offers.filter { $0.status == .pending }
    }

    public func offer(_ id: UUID) -> IncomingOffer? {
        offers.first { $0.id == id }
    }

    public var userLeaguePosition: Int? { userLeague.position(of: userClubID) }
}

// MARK: - Inbox

extension Career {
    mutating func post(_ kind: InboxKind) {
        inbox.append(InboxMessage(id: UUID(), season: season, week: week, kind: kind, isRead: false))
        if inbox.count > 80 { inbox.removeFirst(inbox.count - 80) }
    }

    public mutating func markAllRead() {
        for index in inbox.indices { inbox[index].isRead = true }
    }

    public mutating func markRead(_ messageID: UUID) {
        if let index = inbox.firstIndex(where: { $0.id == messageID }) {
            inbox[index].isRead = true
        }
    }
}
