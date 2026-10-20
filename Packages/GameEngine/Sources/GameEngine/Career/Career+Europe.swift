import Foundation

struct CupPrizes {
    let participation: Int
    let win: Int
    let draw: Int
    let quarterFinal: Int
    let semiFinal: Int
    let final: Int
    let winner: Int
}

extension Career {
    // MARK: - Rules

    static func cupPrizes(_ kind: CompetitionKind) -> CupPrizes {
        switch kind {
        case .eliteCup:
            return CupPrizes(participation: 10_000_000, win: 2_000_000, draw: 700_000,
                             quarterFinal: 6_000_000, semiFinal: 9_000_000, final: 12_000_000, winner: 10_000_000)
        case .continentalLeague:
            return CupPrizes(participation: 3_000_000, win: 600_000, draw: 200_000,
                             quarterFinal: 2_000_000, semiFinal: 3_000_000, final: 4_000_000, winner: 4_000_000)
        }
    }

    /// European nights: fuller stadiums and pricier tickets.
    static func gateMultiplier(_ kind: CompetitionKind) -> Double {
        kind == .eliteCup ? 1.8 : 1.3
    }

    /// European places per league, strongest league first (16 clubs per cup).
    static let eliteQuota = [4, 3, 3, 3, 3]
    static let continentalQuota = [3, 4, 3, 3, 3]

    /// Turns final league orders into cup entrants: e.g. places 1–3 → Elite Cup, 4–6 → Continental League.
    static func europeanQualifiers(rankings: [(strength: Double, order: [UUID])]) -> [CompetitionKind: [UUID]] {
        let sorted = rankings.sorted { $0.strength > $1.strength }
        var elite: [UUID] = []
        var continental: [UUID] = []
        for (index, ranking) in sorted.enumerated() {
            let elitePlaces = index < eliteQuota.count ? eliteQuota[index] : 2
            let continentalPlaces = index < continentalQuota.count ? continentalQuota[index] : 2
            elite += ranking.order.prefix(elitePlaces)
            continental += ranking.order.dropFirst(elitePlaces).prefix(continentalPlaces)
        }
        return [.eliteCup: elite, .continentalLeague: continental]
    }

    /// European places a league earns: (Elite Cup, Continental League).
    public func europeanPlaces(in league: League) -> (elite: Int, continental: Int) {
        let order = leagues.sorted { $0.strength > $1.strength }.map(\.id)
        let index = order.firstIndex(of: league.id) ?? order.count
        let elite = index < Career.eliteQuota.count ? Career.eliteQuota[index] : 2
        let continental = index < Career.continentalQuota.count ? Career.continentalQuota[index] : 2
        return (elite, continental)
    }

    // MARK: - Setup

    mutating func setUpCups(qualifiers: [CompetitionKind: [UUID]]) {
        cups = []
        for kind in CompetitionKind.allCases {
            guard let entrants = qualifiers[kind], entrants.count == 16 else { continue }
            var generator = rng
            let cup = Career.makeCup(kind: kind, season: season, clubIDs: entrants, clubs: clubs, rng: &generator)
            rng = generator
            cups.append(cup)
            let prizes = Career.cupPrizes(kind)
            for id in entrants { awardCupPrize(prizes.participation, to: id) }
        }
    }

    /// Seeded draw: four pots by reputation, avoiding two clubs from one country in a group.
    static func makeCup(kind: CompetitionKind, season: Int, clubIDs: [UUID], clubs: [UUID: Club], rng: inout SeededRandom) -> Cup {
        let groupCount = 4
        let seeded = clubIDs.sorted { (clubs[$0]?.reputation ?? 0) > (clubs[$1]?.reputation ?? 0) }
        let potCount = seeded.count / groupCount
        var best: [[UUID]] = []
        var bestConflicts = Int.max
        for _ in 0..<80 {
            var groups = Array(repeating: [UUID](), count: groupCount)
            var conflicts = 0
            for pot in 0..<potCount {
                let teams = Array(seeded[(pot * groupCount)..<((pot + 1) * groupCount)]).shuffled(using: &rng)
                for (group, team) in teams.enumerated() {
                    let country = clubs[team]?.countryCode
                    if groups[group].contains(where: { clubs[$0]?.countryCode == country }) { conflicts += 1 }
                    groups[group].append(team)
                }
            }
            if conflicts < bestConflicts {
                best = groups
                bestConflicts = conflicts
            }
            if conflicts == 0 { break }
        }

        var fixtures: [CupFixture] = []
        for (groupIndex, group) in best.enumerated() {
            for fixture in Scheduler.doubleRoundRobin(clubIDs: group, rng: &rng) {
                let round = fixture.matchday
                guard round >= 1, round <= Cup.groupWeeks.count else { continue }
                fixtures.append(CupFixture(
                    id: UUID(), week: Cup.groupWeeks[round - 1], stage: .group, group: groupIndex, tie: nil,
                    leg: round, homeID: fixture.homeID, awayID: fixture.awayID, isNeutral: false,
                    result: nil, shootoutWinnerID: nil
                ))
            }
        }
        return Cup(id: UUID(), kind: kind, season: season, clubIDs: clubIDs, groups: best, fixtures: fixtures, winnerID: nil)
    }

    // MARK: - Money

    /// Prize money also lifts the transfer budget (the board passes on 40%).
    mutating func awardCupPrize(_ amount: Int, to clubID: UUID, raisesBudget: Bool = true) {
        guard amount > 0, clubs[clubID] != nil else { return }
        clubs[clubID]?.finances.balance += amount
        clubs[clubID]?.finances.seasonIncome += amount
        clubs[clubID]?.finances.seasonEuropeIncome += amount
        if raisesBudget {
            clubs[clubID]?.finances.transferBudget += amount * 2 / 5
        }
    }

    // MARK: - Playing

    mutating func playCupMatches(week matchday: Int) -> Set<UUID> {
        var injured = Set<UUID>()
        for cupIndex in cups.indices {
            let kind = cups[cupIndex].kind
            let prizes = Career.cupPrizes(kind)
            for fixtureIndex in cups[cupIndex].fixtures.indices {
                let fixture = cups[cupIndex].fixtures[fixtureIndex]
                guard fixture.week == matchday, fixture.result == nil,
                      let home = clubs[fixture.homeID], let away = clubs[fixture.awayID] else { continue }
                let homeSheet = teamSheet(for: home.id)
                let awaySheet = teamSheet(for: away.id)

                var generator = rng
                let outcome = MatchEngine.play(home: home, away: away, homeSheet: homeSheet, awaySheet: awaySheet,
                                               neutral: fixture.isNeutral, attendanceBoost: 0.25, rng: &generator)
                rng = generator
                let result = outcome.result
                cups[cupIndex].fixtures[fixtureIndex].result = result

                // A knockout tie still level after its last game goes to penalties.
                if fixture.stage != .group, let tie = fixture.tie,
                   fixture.stage == .final || fixture.leg == 2,
                   cups[cupIndex].tieWinner(stage: fixture.stage, tie: tie) == nil {
                    let edge = (MatchEngine.strength(of: homeSheet).overall - MatchEngine.strength(of: awaySheet).overall) / 100
                    let winner = rng.chance((0.5 + edge).clamped(to: 0.3...0.7)) ? home.id : away.id
                    cups[cupIndex].fixtures[fixtureIndex].shootoutWinnerID = winner
                }

                let gate = Int(Double(result.attendance * home.stadium.ticketPrice) * Career.gateMultiplier(kind))
                if fixture.isNeutral {
                    awardCupPrize(gate / 2, to: home.id, raisesBudget: false)
                    awardCupPrize(gate / 2, to: away.id, raisesBudget: false)
                } else {
                    awardCupPrize(gate, to: home.id, raisesBudget: false)
                }

                if fixture.stage == .group {
                    if result.homeGoals > result.awayGoals {
                        awardCupPrize(prizes.win, to: home.id)
                    } else if result.homeGoals < result.awayGoals {
                        awardCupPrize(prizes.win, to: away.id)
                    } else {
                        awardCupPrize(prizes.draw, to: home.id)
                        awardCupPrize(prizes.draw, to: away.id)
                    }
                }
                injured.formUnion(applyOutcome(outcome, homeID: home.id, awayID: away.id))
            }
        }
        return injured
    }

    /// Draws the next knockout round once the previous one is complete, and crowns the winner.
    mutating func updateCupBrackets() {
        for index in cups.indices {
            var cup = cups[index]
            let prizes = Career.cupPrizes(cup.kind)

            // Groups → quarter-finals: group winners meet runners-up, winners at home in the 2nd leg.
            let groupFixtures = cup.fixtures(in: .group)
            if cup.fixtures(in: .quarterFinal).isEmpty, cup.groups.count == 4, !groupFixtures.isEmpty,
               groupFixtures.allSatisfy({ $0.result != nil }) {
                let tables = (0..<4).map { cup.groupTable($0) }
                if tables.allSatisfy({ $0.count >= 2 }) {
                    let winners = tables.map { $0[0].clubID }
                    let runnersUp = tables.map { $0[1].clubID }
                    let pairs = [(winners[0], runnersUp[1]), (winners[1], runnersUp[0]),
                                 (winners[2], runnersUp[3]), (winners[3], runnersUp[2])]
                    for (tie, pair) in pairs.enumerated() {
                        cup.fixtures.append(.knockout(stage: .quarterFinal, tie: tie, leg: 1, week: Cup.quarterFinalWeeks[0], home: pair.1, away: pair.0))
                        cup.fixtures.append(.knockout(stage: .quarterFinal, tie: tie, leg: 2, week: Cup.quarterFinalWeeks[1], home: pair.0, away: pair.1))
                    }
                    advance(cup.kind, advancing: winners + runnersUp, previous: cup.clubIDs, to: .quarterFinal,
                            eliminatedAt: .group, prize: prizes.quarterFinal, reputation: 0)
                }
            }

            // Quarter-finals → semi-finals.
            if cup.fixtures(in: .semiFinal).isEmpty, !cup.fixtures(in: .quarterFinal).isEmpty {
                let winners = (0..<4).compactMap { cup.tieWinner(stage: .quarterFinal, tie: $0) }
                if winners.count == 4 {
                    for tie in 0..<2 {
                        var first = winners[tie * 2]
                        var second = winners[tie * 2 + 1]
                        if rng.chance(0.5) { Swift.swap(&first, &second) }
                        cup.fixtures.append(.knockout(stage: .semiFinal, tie: tie, leg: 1, week: Cup.semiFinalWeeks[0], home: first, away: second))
                        cup.fixtures.append(.knockout(stage: .semiFinal, tie: tie, leg: 2, week: Cup.semiFinalWeeks[1], home: second, away: first))
                    }
                    advance(cup.kind, advancing: winners, previous: cup.participants(in: .quarterFinal), to: .semiFinal,
                            eliminatedAt: .quarterFinal, prize: prizes.semiFinal, reputation: 1)
                }
            }

            // Semi-finals → final at a neutral ground.
            if cup.fixtures(in: .final).isEmpty, !cup.fixtures(in: .semiFinal).isEmpty {
                let winners = (0..<2).compactMap { cup.tieWinner(stage: .semiFinal, tie: $0) }
                if winners.count == 2 {
                    cup.fixtures.append(.knockout(stage: .final, tie: 0, leg: 1, week: Cup.finalWeek,
                                                  home: winners[0], away: winners[1], neutral: true))
                    advance(cup.kind, advancing: winners, previous: cup.participants(in: .semiFinal), to: .final,
                            eliminatedAt: .semiFinal, prize: prizes.final, reputation: 1)
                }
            }

            // Final played → winner.
            if cup.winnerID == nil, let final = cup.fixtures(in: .final).first, final.result != nil,
               let winner = cup.tieWinner(stage: .final, tie: 0) {
                cup.winnerID = winner
                awardCupPrize(prizes.winner, to: winner)
                if let reputation = clubs[winner]?.reputation {
                    clubs[winner]?.reputation = min(95, reputation + 2)
                }
                if winner == userClubID {
                    post(.cupWon(kind: cup.kind, prize: prizes.winner))
                } else if final.involves(userClubID) {
                    post(.cupEliminated(kind: cup.kind, stage: .final))
                }
            }
            cups[index] = cup
        }
    }

    private mutating func advance(
        _ kind: CompetitionKind,
        advancing: [UUID],
        previous: [UUID],
        to stage: CupStage,
        eliminatedAt: CupStage,
        prize: Int,
        reputation: Int
    ) {
        for id in advancing {
            awardCupPrize(prize, to: id)
            if reputation > 0, let current = clubs[id]?.reputation {
                clubs[id]?.reputation = min(95, current + reputation)
            }
        }
        if advancing.contains(userClubID) {
            post(.cupProgress(kind: kind, stage: stage, prize: prize))
        } else if previous.contains(userClubID) {
            post(.cupEliminated(kind: kind, stage: eliminatedAt))
        }
    }
}
