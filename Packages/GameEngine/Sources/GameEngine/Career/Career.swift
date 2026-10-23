import Foundation

/// The whole save game. Value type: the app keeps one copy, mutates it and writes it to disk as JSON.
public struct Career: Codable, Sendable {
    /// Bumped whenever the save format changes.
    public static let currentVersion = 5
    /// Oldest save format that can still be loaded (missing fields get defaults).
    public static let minimumLoadableVersion = 2

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
    public internal(set) var userTactics: Tactics
    public internal(set) var talks: [UUID: TransferTalks]
    /// This season's European cups.
    public internal(set) var cups: [Cup]
    public internal(set) var manager: Manager
    /// Offers from other clubs to become their manager.
    public internal(set) var jobOffers: [JobOffer]
    /// Sacked and waiting to accept a new job.
    public internal(set) var isUnemployed: Bool
    /// Scouts currently searching, and the players they found.
    public internal(set) var scoutMissions: [ScoutMission] = []
    public internal(set) var scoutReports: [ScoutReport] = []
    var rng: SeededRandom
}

// MARK: - Loading older saves

extension Career {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = Career.currentVersion
        season = try container.decode(Int.self, forKey: .season)
        week = try container.decode(Int.self, forKey: .week)
        userClubID = try container.decode(UUID.self, forKey: .userClubID)
        leagues = try container.decode([League].self, forKey: .leagues)
        clubs = try container.decode([UUID: Club].self, forKey: .clubs)
        players = try container.decode([UUID: Player].self, forKey: .players)
        inbox = try container.decode([InboxMessage].self, forKey: .inbox)
        offers = try container.decode([IncomingOffer].self, forKey: .offers)
        history = try container.decode([SeasonSummary].self, forKey: .history)
        userTactics = try container.decode(Tactics.self, forKey: .userTactics)
        talks = try container.decode([UUID: TransferTalks].self, forKey: .talks)
        cups = try container.decode([Cup].self, forKey: .cups)
        rng = try container.decode(SeededRandom.self, forKey: .rng)
        // Added in version 3.
        if let saved = try container.decodeIfPresent(Manager.self, forKey: .manager) {
            manager = saved
        } else if let club = clubs[userClubID] {
            manager = Manager.starting(at: club)
            manager.seasonsManaged = history.count
        } else {
            manager = Manager(reputation: 40, boardConfidence: 60, trophies: 0, timesSacked: 0, seasonsManaged: 0, warningLevel: 0)
        }
        jobOffers = try container.decodeIfPresent([JobOffer].self, forKey: .jobOffers) ?? []
        isUnemployed = try container.decodeIfPresent(Bool.self, forKey: .isUnemployed) ?? false
        // Added in version 5.
        scoutMissions = try container.decodeIfPresent([ScoutMission].self, forKey: .scoutMissions) ?? []
        scoutReports = try container.decodeIfPresent([ScoutReport].self, forKey: .scoutReports) ?? []
        // Version 4 added free agents: give older saves a starting pool.
        let savedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 2
        if savedVersion < 4 && freeAgentCount < 40 {
            seedFreeAgents(count: 60 - freeAgentCount, season: season)
        }
    }
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

    /// Summer window: first 4 matchdays. Winter window: 4 matchdays from the halfway point.
    public var isTransferWindowOpen: Bool {
        transferWindowStatus.isOpen
    }

    public var unreadCount: Int { inbox.filter { !$0.isRead }.count }

    public var pendingOffers: [IncomingOffer] {
        offers.filter { $0.status == .pending }
    }

    public func offer(_ id: UUID) -> IncomingOffer? {
        offers.first { $0.id == id }
    }

    public var userLeaguePosition: Int? { userLeague.position(of: userClubID) }

    // MARK: Cups

    public func cup(_ kind: CompetitionKind) -> Cup? {
        cups.first { $0.kind == kind }
    }

    /// The cup the user's club plays in this season, if any.
    public var userCup: Cup? {
        cups.first { $0.clubIDs.contains(userClubID) }
    }

    public func cupMatch(_ fixtureID: UUID) -> (cup: Cup, fixture: CupFixture)? {
        for cup in cups {
            if let fixture = cup.fixtures.first(where: { $0.id == fixtureID }) {
                return (cup: cup, fixture: fixture)
            }
        }
        return nil
    }

    /// The user's midweek cup game in the coming week.
    public var nextUserCupMatch: (cup: Cup, fixture: CupFixture)? {
        for cup in cups {
            if let fixture = cup.fixtures.first(where: { $0.week == nextMatchday && $0.result == nil && $0.involves(userClubID) }) {
                return (cup: cup, fixture: fixture)
            }
        }
        return nil
    }

    public var lastUserCupMatch: (cup: Cup, fixture: CupFixture)? {
        var best: (cup: Cup, fixture: CupFixture)?
        for cup in cups {
            for fixture in cup.fixtures where fixture.result != nil && fixture.involves(userClubID) {
                if best == nil || fixture.week > best!.fixture.week {
                    best = (cup: cup, fixture: fixture)
                }
            }
        }
        return best
    }
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
