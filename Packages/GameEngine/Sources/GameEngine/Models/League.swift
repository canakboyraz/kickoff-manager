import Foundation

public enum MatchEventKind: String, Codable, Hashable, Sendable {
    case goal
    case injury
}

public struct MatchEvent: Codable, Hashable, Sendable {
    public var minute: Int
    public var kind: MatchEventKind
    public var clubID: UUID
    public var playerID: UUID
    public var assistID: UUID?
}

public struct PlayerRating: Codable, Hashable, Sendable {
    public var playerID: UUID
    public var clubID: UUID
    public var rating: Double
}

public struct MatchResult: Codable, Hashable, Sendable {
    public var homeGoals: Int
    public var awayGoals: Int
    public var events: [MatchEvent]
    public var ratings: [PlayerRating]
    public var attendance: Int
    /// Expected goals used by the simulation, handy for match reports.
    public var homeExpectedGoals: Double
    public var awayExpectedGoals: Double
}

public struct Fixture: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var matchday: Int
    public var homeID: UUID
    public var awayID: UUID
    public var result: MatchResult?

    public func involves(_ clubID: UUID) -> Bool {
        homeID == clubID || awayID == clubID
    }
}

public struct TableRow: Hashable, Identifiable, Sendable {
    public var id: UUID { clubID }
    public var clubID: UUID
    public var played = 0
    public var won = 0
    public var drawn = 0
    public var lost = 0
    public var goalsFor = 0
    public var goalsAgainst = 0
    public var goalDifference: Int { goalsFor - goalsAgainst }
    public var points: Int { won * 3 + drawn }
}

public struct League: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var countryCode: String
    /// Relative strength of the league (1.0 = strongest). Affects reputation and prize money.
    public var strength: Double
    public var clubIDs: [UUID]
    public var fixtures: [Fixture]

    public var matchdayCount: Int {
        fixtures.map(\.matchday).max() ?? 0
    }

    public func fixtures(on matchday: Int) -> [Fixture] {
        fixtures.filter { $0.matchday == matchday }
    }

    public func table() -> [TableRow] {
        var rows = Dictionary(uniqueKeysWithValues: clubIDs.map { ($0, TableRow(clubID: $0)) })
        for fixture in fixtures {
            guard let result = fixture.result else { continue }
            rows[fixture.homeID]?.apply(scored: result.homeGoals, conceded: result.awayGoals)
            rows[fixture.awayID]?.apply(scored: result.awayGoals, conceded: result.homeGoals)
        }
        return rows.values.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
            if $0.goalsFor != $1.goalsFor { return $0.goalsFor > $1.goalsFor }
            return $0.clubID.uuidString < $1.clubID.uuidString
        }
    }

    public func position(of clubID: UUID) -> Int? {
        table().firstIndex { $0.clubID == clubID }.map { $0 + 1 }
    }
}

extension TableRow {
    mutating func apply(scored: Int, conceded: Int) {
        played += 1
        goalsFor += scored
        goalsAgainst += conceded
        if scored > conceded { won += 1 } else if scored == conceded { drawn += 1 } else { lost += 1 }
    }
}
