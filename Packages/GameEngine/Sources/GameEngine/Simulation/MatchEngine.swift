import Foundation

public struct LineupSlot: Hashable, Sendable {
    public var slot: Position
    public var player: Player
    /// Rating of the player in this slot, after out-of-position and morale effects.
    public var effectiveRating: Double
}

public struct TeamStrength: Hashable, Sendable {
    public var attack: Double
    public var defence: Double
    public var overall: Double
}

public enum MatchEngine {
    /// 4-3-3, filled scarcest slots first.
    public static let formation: [Position] = [
        .goalkeeper, .centreBack, .centreBack, .striker, .defensiveMid,
        .fullBack, .fullBack, .centralMid, .centralMid, .winger, .winger
    ]

    /// Display order for the 4-3-3 (back to front).
    public static let displayOrder: [Position] = [
        .goalkeeper, .fullBack, .centreBack, .centreBack, .fullBack,
        .centralMid, .defensiveMid, .centralMid, .winger, .striker, .winger
    ]

    static func rating(of player: Player, in slot: Position) -> Double {
        var value = Double(player.attributes.overall(for: slot))
        if player.position != slot {
            value -= player.position.line == slot.line ? 2 : 6
        }
        value += Double(player.morale - 60) / 20
        return value
    }

    /// Picks the best available eleven from a squad.
    public static func bestLineup(from squad: [Player]) -> [LineupSlot] {
        var available = squad.filter { !$0.isInjured }
        var lineup: [LineupSlot] = []
        for slot in formation {
            guard let best = available.max(by: { rating(of: $0, in: slot) < rating(of: $1, in: slot) }) else { break }
            lineup.append(LineupSlot(slot: slot, player: best, effectiveRating: rating(of: best, in: slot)))
            available.removeAll { $0.id == best.id }
        }
        return lineup
    }

    public static func strength(of lineup: [LineupSlot]) -> TeamStrength {
        func average(_ lines: [Position.Line]) -> Double {
            let values = lineup.filter { lines.contains($0.slot.line) }.map(\.effectiveRating)
            return values.isEmpty ? 30 : values.reduce(0, +) / Double(values.count)
        }
        let keeper = average([.goalkeeper])
        let defence = average([.defence])
        let midfield = average([.midfield])
        let attack = average([.attack])
        let missing = Double(max(0, formation.count - lineup.count)) * 6

        let attackRating = 0.55 * attack + 0.35 * midfield + 0.10 * defence - missing
        let defenceRating = 0.45 * defence + 0.25 * keeper + 0.30 * midfield - missing
        let overall = lineup.isEmpty ? 0 : lineup.map(\.effectiveRating).reduce(0, +) / Double(lineup.count)
        return TeamStrength(attack: attackRating, defence: defenceRating, overall: overall)
    }

    struct Outcome {
        var result: MatchResult
        var injuries: [(playerID: UUID, weeks: Int)]
        var homeLineup: [LineupSlot]
        var awayLineup: [LineupSlot]
    }

    static func play(
        home: Club,
        away: Club,
        homeSquad: [Player],
        awaySquad: [Player],
        rng: inout SeededRandom
    ) -> Outcome {
        let homeLineup = bestLineup(from: homeSquad)
        let awayLineup = bestLineup(from: awaySquad)
        let homeStrength = strength(of: homeLineup)
        let awayStrength = strength(of: awayLineup)

        let homeXG = (1.32 * exp((homeStrength.attack - awayStrength.defence) / 14)).clamped(to: 0.15...4.0)
        let awayXG = (1.02 * exp((awayStrength.attack - homeStrength.defence) / 14)).clamped(to: 0.15...4.0)
        let homeGoals = rng.poisson(homeXG)
        let awayGoals = rng.poisson(awayXG)

        var events: [MatchEvent] = []
        var goalsBy: [UUID: Int] = [:]
        var assistsBy: [UUID: Int] = [:]

        func addGoals(_ count: Int, lineup: [LineupSlot], clubID: UUID) {
            guard !lineup.isEmpty else { return }
            for _ in 0..<count {
                let scorerWeights = lineup.map { $0.slot.scoringWeight * pow(Double($0.player.attributes.shooting) / 65, 2.5) }
                guard let scorerIndex = rng.weightedIndex(scorerWeights) else { continue }
                let scorer = lineup[scorerIndex].player
                var assistID: UUID?
                if rng.chance(0.75) {
                    var assistWeights: [Double] = []
                    for (index, entry) in lineup.enumerated() {
                        let weight = entry.slot.assistWeight * pow(Double(entry.player.attributes.passing) / 65, 2)
                        assistWeights.append(index == scorerIndex ? 0 : weight)
                    }
                    if let assistIndex = rng.weightedIndex(assistWeights) {
                        assistID = lineup[assistIndex].player.id
                    }
                }
                goalsBy[scorer.id, default: 0] += 1
                if let assistID { assistsBy[assistID, default: 0] += 1 }
                events.append(MatchEvent(minute: rng.int(1...90), kind: .goal, clubID: clubID, playerID: scorer.id, assistID: assistID))
            }
        }
        addGoals(homeGoals, lineup: homeLineup, clubID: home.id)
        addGoals(awayGoals, lineup: awayLineup, clubID: away.id)

        var injuries: [(UUID, Int)] = []
        func rollInjuries(_ lineup: [LineupSlot], club: Club) {
            let medical = Double(club.facilities.medical)
            let chance = 0.012 * (1.25 - medical * 0.05)
            for entry in lineup where rng.chance(chance) {
                var weeks = rng.chance(0.1) ? rng.int(8...16) : rng.int(1...6)
                weeks = max(1, Int((Double(weeks) * (1.1 - medical * 0.04)).rounded()))
                injuries.append((entry.player.id, weeks))
                events.append(MatchEvent(minute: rng.int(1...90), kind: .injury, clubID: club.id, playerID: entry.player.id, assistID: nil))
            }
        }
        rollInjuries(homeLineup, club: home)
        rollInjuries(awayLineup, club: away)
        events.sort { $0.minute < $1.minute }

        var ratings: [PlayerRating] = []
        func rate(_ lineup: [LineupSlot], clubID: UUID, scored: Int, conceded: Int) {
            guard !lineup.isEmpty else { return }
            let teamAverage = lineup.map(\.effectiveRating).reduce(0, +) / Double(lineup.count)
            for entry in lineup {
                var rating = 6.4 + rng.normal(sd: 0.45)
                if scored > conceded { rating += 0.4 } else if scored < conceded { rating -= 0.35 }
                rating += Double(goalsBy[entry.player.id] ?? 0) * 1.0
                rating += Double(assistsBy[entry.player.id] ?? 0) * 0.6
                rating += (entry.effectiveRating - teamAverage) / 25
                switch entry.slot.line {
                case .goalkeeper:
                    rating += conceded == 0 ? 0.6 : -0.25 * Double(conceded)
                case .defence:
                    rating += conceded == 0 ? 0.5 : -0.18 * Double(conceded)
                case .midfield where entry.slot == .defensiveMid:
                    rating += conceded == 0 ? 0.3 : -0.1 * Double(conceded)
                default:
                    break
                }
                ratings.append(PlayerRating(playerID: entry.player.id, clubID: clubID, rating: (rating * 10).rounded() / 10))
            }
        }
        rate(homeLineup, clubID: home.id, scored: homeGoals, conceded: awayGoals)
        rate(awayLineup, clubID: away.id, scored: awayGoals, conceded: homeGoals)
        for index in ratings.indices {
            ratings[index].rating = ratings[index].rating.clamped(to: 3.5...10)
        }

        // Higher ticket prices than the "fair" price for this reputation keep fans away.
        let fairPrice = 12 + Double(home.reputation) * 0.45
        let pricePenalty = max(-0.1, (Double(home.stadium.ticketPrice) - fairPrice) / fairPrice * 0.35)
        let fill = (0.4 + Double(home.reputation) / 130 - pricePenalty + rng.double(-0.05...0.05)).clamped(to: 0.2...1.0)
        let attendance = Int(Double(home.stadium.capacity) * fill)

        let result = MatchResult(
            homeGoals: homeGoals,
            awayGoals: awayGoals,
            events: events,
            ratings: ratings,
            attendance: attendance,
            homeExpectedGoals: (homeXG * 100).rounded() / 100,
            awayExpectedGoals: (awayXG * 100).rounded() / 100
        )
        return Outcome(
            result: result,
            injuries: injuries.map { (playerID: $0.0, weeks: $0.1) },
            homeLineup: homeLineup,
            awayLineup: awayLineup
        )
    }
}
