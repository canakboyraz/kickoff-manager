import Foundation

/// The two European cups. Names are fictional.
public enum CompetitionKind: String, Codable, CaseIterable, Hashable, Sendable {
    /// Top places of each league (top 3, top 4 in the strongest league).
    case eliteCup
    /// The next places (4th–6th, 5th–7th in the strongest league).
    case continentalLeague
}

public enum CupStage: Int, Codable, CaseIterable, Comparable, Hashable, Sendable {
    case group = 0
    case quarterFinal
    case semiFinal
    case final
    case winner

    public static func < (lhs: CupStage, rhs: CupStage) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct CupFixture: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    /// League matchday whose midweek this game is played in.
    public var week: Int
    public var stage: CupStage
    /// Group index (0...3) for group games.
    public var group: Int?
    /// Tie index within a knockout stage.
    public var tie: Int?
    /// Group matchday (1...6), or leg (1/2) in knockout ties.
    public var leg: Int
    public var homeID: UUID
    public var awayID: UUID
    /// The final is played at a neutral ground.
    public var isNeutral: Bool
    public var result: MatchResult?
    /// Set when a knockout tie finished level and was decided on penalties.
    public var shootoutWinnerID: UUID?

    public func involves(_ clubID: UUID) -> Bool {
        homeID == clubID || awayID == clubID
    }

    static func knockout(stage: CupStage, tie: Int, leg: Int, week: Int, home: UUID, away: UUID, neutral: Bool = false) -> CupFixture {
        CupFixture(id: UUID(), week: week, stage: stage, group: nil, tie: tie, leg: leg,
                   homeID: home, awayID: away, isNeutral: neutral, result: nil, shootoutWinnerID: nil)
    }
}

/// One season of a European cup: 4 groups of 4 (home and away), two-legged quarter- and
/// semi-finals, and a one-off final at a neutral ground. Games are played midweek.
public struct Cup: Codable, Identifiable, Hashable, Sendable {
    public static let groupWeeks = [3, 5, 7, 9, 11, 13]
    public static let quarterFinalWeeks = [17, 19]
    public static let semiFinalWeeks = [23, 25]
    public static let finalWeek = 30

    public let id: UUID
    public var kind: CompetitionKind
    public var season: Int
    public var clubIDs: [UUID]
    public var groups: [[UUID]]
    public var fixtures: [CupFixture]
    public var winnerID: UUID?

    public func fixtures(in stage: CupStage) -> [CupFixture] {
        fixtures.filter { $0.stage == stage }
    }

    public func fixtures(for clubID: UUID) -> [CupFixture] {
        fixtures.filter { $0.involves(clubID) }.sorted { $0.week < $1.week }
    }

    public func groupTable(_ index: Int) -> [TableRow] {
        guard groups.indices.contains(index) else { return [] }
        let results = fixtures.compactMap { fixture -> (homeID: UUID, awayID: UUID, result: MatchResult)? in
            guard fixture.stage == .group, fixture.group == index, let result = fixture.result else { return nil }
            return (homeID: fixture.homeID, awayID: fixture.awayID, result: result)
        }
        return Standings.table(clubIDs: groups[index], results: results)
    }

    /// Clubs taking part in a stage.
    public func participants(in stage: CupStage) -> [UUID] {
        var seen: [UUID] = []
        for fixture in fixtures(in: stage) {
            for id in [fixture.homeID, fixture.awayID] where !seen.contains(id) { seen.append(id) }
        }
        return seen
    }

    public func tieIndices(in stage: CupStage) -> [Int] {
        Array(Set(fixtures(in: stage).compactMap(\.tie))).sorted()
    }

    public func legs(stage: CupStage, tie: Int) -> [CupFixture] {
        fixtures.filter { $0.stage == stage && $0.tie == tie }.sorted { $0.leg < $1.leg }
    }

    /// Aggregate score of a tie, from the point of view of the first leg's home side.
    public func aggregate(stage: CupStage, tie: Int) -> (first: UUID, firstGoals: Int, second: UUID, secondGoals: Int)? {
        let legs = legs(stage: stage, tie: tie)
        guard let opener = legs.first else { return nil }
        var firstGoals = 0
        var secondGoals = 0
        for leg in legs {
            guard let result = leg.result else { continue }
            if leg.homeID == opener.homeID {
                firstGoals += result.homeGoals
                secondGoals += result.awayGoals
            } else {
                firstGoals += result.awayGoals
                secondGoals += result.homeGoals
            }
        }
        return (opener.homeID, firstGoals, opener.awayID, secondGoals)
    }

    /// Winner of a knockout tie once every leg has been played.
    public func tieWinner(stage: CupStage, tie: Int) -> UUID? {
        let legs = legs(stage: stage, tie: tie)
        guard !legs.isEmpty, legs.allSatisfy({ $0.result != nil }),
              let score = aggregate(stage: stage, tie: tie) else { return nil }
        if score.firstGoals != score.secondGoals {
            return score.firstGoals > score.secondGoals ? score.first : score.second
        }
        return legs.last?.shootoutWinnerID
    }

    /// Furthest stage a club has reached (nil when it isn't in this cup).
    public func stageReached(by clubID: UUID) -> CupStage? {
        guard clubIDs.contains(clubID) else { return nil }
        if winnerID == clubID { return .winner }
        return fixtures.filter { $0.involves(clubID) }.map(\.stage).max() ?? .group
    }

    /// Whether a club can still win the cup.
    public func isAlive(_ clubID: UUID) -> Bool {
        guard clubIDs.contains(clubID), winnerID == nil else { return false }
        for stage in [CupStage.final, .semiFinal, .quarterFinal] where !fixtures(in: stage).isEmpty {
            guard let fixture = fixtures(in: stage).first(where: { $0.involves(clubID) }),
                  let tie = fixture.tie else { return false }
            if let winner = tieWinner(stage: stage, tie: tie) { return winner == clubID }
            return true
        }
        return true
    }
}
