import Foundation

public struct TeamStrength: Hashable, Sendable {
    public var attack: Double
    public var defence: Double
    public var overall: Double
}

public enum MatchEngine {
    public static func strength(of sheet: TeamSheet) -> TeamStrength {
        let lineup = sheet.starters
        func average(_ lines: [Position.Line]) -> Double {
            let values = lineup.filter { lines.contains($0.slot.line) }.map(\.effectiveRating)
            return values.isEmpty ? 30 : values.reduce(0, +) / Double(values.count)
        }
        let keeper = average([.goalkeeper])
        let defence = average([.defence])
        let midfield = average([.midfield])
        let attack = average([.attack])
        let missing = Double(max(0, sheet.formation.slots.count - lineup.count)) * 6

        let attackRating = 0.55 * attack + 0.35 * midfield + 0.10 * defence - missing + sheet.formation.attackModifier
        let defenceRating = 0.45 * defence + 0.25 * keeper + 0.30 * midfield - missing + sheet.formation.defenceModifier
        let overall = lineup.isEmpty ? 0 : lineup.map(\.effectiveRating).reduce(0, +) / Double(lineup.count)
        return TeamStrength(attack: attackRating, defence: defenceRating, overall: overall)
    }

    struct Appearance {
        var playerID: UUID
        var clubID: UUID
        var minutes: Int
        var rating: Double
        var goals: Int
        var assists: Int
    }

    struct Booking {
        var playerID: UUID
        var clubID: UUID
        var isRed: Bool
        /// Red card for a second yellow (one-match ban, no accumulation).
        var isSecondYellow: Bool
    }

    struct Outcome {
        var result: MatchResult
        var injuries: [(playerID: UUID, weeks: Int)]
        var appearances: [Appearance]
        var bookings: [Booking]
    }

    /// A spell on the pitch: starters play from 0, substitutes from the minute they come on.
    private struct Stint {
        var slot: Position
        var player: Player
        var rating: Double
        var from: Int
        var to: Int

        var minutes: Int { to - from }

        func isOnPitch(at minute: Int) -> Bool { from < minute && minute <= to }
    }

    static func play(
        home: Club,
        away: Club,
        homeSheet: TeamSheet,
        awaySheet: TeamSheet,
        neutral: Bool = false,
        attendanceBoost: Double = 0,
        rng: inout SeededRandom
    ) -> Outcome {
        let homeStrength = strength(of: homeSheet)
        let awayStrength = strength(of: awaySheet)
        let homeBase = neutral ? 1.17 : 1.32
        let awayBase = neutral ? 1.17 : 1.02
        var homeXG = homeBase * exp((homeStrength.attack - awayStrength.defence) / 14)
        var awayXG = awayBase * exp((awayStrength.attack - homeStrength.defence) / 14)

        // Cards come first: a sending-off leaves a team with ten men for the rest of the game.
        var events: [MatchEvent] = []
        var bookings: [Booking] = []
        let homeSentOff = rollCards(homeSheet, clubID: home.id, events: &events, bookings: &bookings, rng: &rng)
        let awaySentOff = rollCards(awaySheet, clubID: away.id, events: &events, bookings: &bookings, rng: &rng)
        for minute in homeSentOff.values {
            let remaining = Double(90 - minute) / 90
            homeXG *= 1 - 0.3 * remaining
            awayXG *= 1 + 0.35 * remaining
        }
        for minute in awaySentOff.values {
            let remaining = Double(90 - minute) / 90
            awayXG *= 1 - 0.3 * remaining
            homeXG *= 1 + 0.35 * remaining
        }
        homeXG = homeXG.clamped(to: 0.15...4.0)
        awayXG = awayXG.clamped(to: 0.15...4.0)
        let homeGoals = rng.poisson(homeXG)
        let awayGoals = rng.poisson(awayXG)

        let homeStints = makeStints(homeSheet, clubID: home.id, sentOff: homeSentOff, events: &events, rng: &rng)
        let awayStints = makeStints(awaySheet, clubID: away.id, sentOff: awaySentOff, events: &events, rng: &rng)

        var goalsBy: [UUID: Int] = [:]
        var assistsBy: [UUID: Int] = [:]
        addGoals(homeGoals, stints: homeStints, clubID: home.id, events: &events, goals: &goalsBy, assists: &assistsBy, rng: &rng)
        addGoals(awayGoals, stints: awayStints, clubID: away.id, events: &events, goals: &goalsBy, assists: &assistsBy, rng: &rng)

        var injuries: [(playerID: UUID, weeks: Int)] = []
        rollInjuries(homeStints, club: home, events: &events, injuries: &injuries, rng: &rng)
        rollInjuries(awayStints, club: away, events: &events, injuries: &injuries, rng: &rng)
        events.sort { $0.minute < $1.minute }

        var ratings: [PlayerRating] = []
        var appearances: [Appearance] = []
        var discipline: [UUID: Double] = [:]
        for booking in bookings {
            discipline[booking.playerID, default: 0] -= booking.isRed ? 1.2 : 0.2
        }
        rate(homeStints, clubID: home.id, scored: homeGoals, conceded: awayGoals, goals: goalsBy, assists: assistsBy,
             discipline: discipline, ratings: &ratings, appearances: &appearances, rng: &rng)
        rate(awayStints, clubID: away.id, scored: awayGoals, conceded: homeGoals, goals: goalsBy, assists: assistsBy,
             discipline: discipline, ratings: &ratings, appearances: &appearances, rng: &rng)

        // Ticket prices above what fans think is fair keep some of them away.
        let fairPrice = 12 + Double(home.reputation) * 0.45
        let pricePenalty = max(-0.1, (Double(home.stadium.ticketPrice) - fairPrice) / fairPrice * 0.35)
        let fill = (0.4 + Double(home.reputation) / 130 - pricePenalty + attendanceBoost + rng.double(-0.05...0.05))
            .clamped(to: 0.2...1.0)
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
        return Outcome(result: result, injuries: injuries, appearances: appearances, bookings: bookings)
    }

    /// Yellow and red cards for the starters. Returns sent-off players as slot index → minute.
    private static func rollCards(
        _ sheet: TeamSheet,
        clubID: UUID,
        events: inout [MatchEvent],
        bookings: inout [Booking],
        rng: inout SeededRandom
    ) -> [Int: Int] {
        var sentOff: [Int: Int] = [:]
        for (index, entry) in sheet.starters.enumerated() {
            let yellowChance: Double
            switch entry.slot {
            case .goalkeeper: yellowChance = 0.03
            case .centreBack, .fullBack: yellowChance = 0.15
            case .defensiveMid: yellowChance = 0.18
            case .centralMid: yellowChance = 0.12
            case .attackingMid, .winger, .striker: yellowChance = 0.08
            }
            let playerID = entry.player.id
            if rng.chance(0.006) {
                let minute = rng.int(10...89)
                events.append(MatchEvent(minute: minute, kind: .redCard, clubID: clubID, playerID: playerID, assistID: nil))
                bookings.append(Booking(playerID: playerID, clubID: clubID, isRed: true, isSecondYellow: false))
                sentOff[index] = minute
            } else if rng.chance(yellowChance) {
                let minute = rng.int(5...85)
                events.append(MatchEvent(minute: minute, kind: .yellowCard, clubID: clubID, playerID: playerID, assistID: nil))
                if rng.chance(0.05) {
                    let second = rng.int((minute + 1)...89)
                    events.append(MatchEvent(minute: second, kind: .redCard, clubID: clubID, playerID: playerID, assistID: nil))
                    bookings.append(Booking(playerID: playerID, clubID: clubID, isRed: true, isSecondYellow: true))
                    sentOff[index] = second
                } else {
                    bookings.append(Booking(playerID: playerID, clubID: clubID, isRed: false, isSecondYellow: false))
                }
            }
        }
        return sentOff
    }

    /// Starters plus 2–3 substitutions between minutes 55 and 85. The most tired outfield
    /// players come off for the best fitting substitute.
    private static func makeStints(
        _ sheet: TeamSheet,
        clubID: UUID,
        sentOff: [Int: Int],
        events: inout [MatchEvent],
        rng: inout SeededRandom
    ) -> [Stint] {
        // Sent-off players leave the pitch and aren't replaced.
        var stints = sheet.starters.enumerated().map { index, entry in
            Stint(slot: entry.slot, player: entry.player, rating: entry.effectiveRating, from: 0, to: sentOff[index] ?? 90)
        }
        var bench = sheet.bench.filter { $0.position != .goalkeeper && $0.isAvailable }
        guard !bench.isEmpty, !stints.isEmpty else { return stints }

        let count = min(bench.count, rng.int(2...3))
        var minutes: [Int] = []
        for _ in 0..<count { minutes.append(rng.int(55...85)) }
        minutes.sort()

        for minute in minutes {
            var outIndex: Int?
            var lowest = Double.infinity
            for index in stints.indices where stints[index].from == 0 && stints[index].to == 90 && stints[index].slot != .goalkeeper {
                let score = Double(stints[index].player.fitness) + rng.double(0...30)
                if score < lowest {
                    lowest = score
                    outIndex = index
                }
            }
            guard let outIndex else { break }
            let slot = stints[outIndex].slot
            guard let incoming = bench.max(by: { Selection.rating(of: $0, in: slot) < Selection.rating(of: $1, in: slot) }) else { break }
            stints[outIndex].to = minute
            stints.append(Stint(slot: slot, player: incoming, rating: Selection.rating(of: incoming, in: slot), from: minute, to: 90))
            bench.removeAll { $0.id == incoming.id }
            events.append(MatchEvent(minute: minute, kind: .substitution, clubID: clubID,
                                     playerID: stints[outIndex].player.id, assistID: nil, subInID: incoming.id))
        }
        return stints
    }

    private static func addGoals(
        _ count: Int,
        stints: [Stint],
        clubID: UUID,
        events: inout [MatchEvent],
        goals: inout [UUID: Int],
        assists: inout [UUID: Int],
        rng: inout SeededRandom
    ) {
        guard !stints.isEmpty else { return }
        for _ in 0..<count {
            let minute = rng.int(1...90)
            let onPitch = stints.filter { $0.isOnPitch(at: minute) }
            guard !onPitch.isEmpty else { continue }
            let scorerWeights = onPitch.map { $0.slot.scoringWeight * pow(Double($0.player.attributes.shooting) / 65, 2.5) }
            guard let scorerIndex = rng.weightedIndex(scorerWeights) else { continue }
            let scorer = onPitch[scorerIndex].player
            var assistID: UUID?
            if rng.chance(0.75) {
                var weights: [Double] = []
                for (index, stint) in onPitch.enumerated() {
                    let weight = stint.slot.assistWeight * pow(Double(stint.player.attributes.passing) / 65, 2)
                    weights.append(index == scorerIndex ? 0 : weight)
                }
                if let assistIndex = rng.weightedIndex(weights) {
                    assistID = onPitch[assistIndex].player.id
                }
            }
            goals[scorer.id, default: 0] += 1
            if let assistID { assists[assistID, default: 0] += 1 }
            events.append(MatchEvent(minute: minute, kind: .goal, clubID: clubID, playerID: scorer.id, assistID: assistID))
        }
    }

    /// Tired players and clubs with a poor medical centre get hurt more often.
    private static func rollInjuries(
        _ stints: [Stint],
        club: Club,
        events: inout [MatchEvent],
        injuries: inout [(playerID: UUID, weeks: Int)],
        rng: inout SeededRandom
    ) {
        let medical = Double(club.facilities.medical)
        for stint in stints where stint.minutes > 0 {
            let tiredness = 1 + Double(max(0, 80 - stint.player.fitness)) / 25
            let chance = 0.012 * (1.25 - medical * 0.05) * tiredness * Double(stint.minutes) / 90
            guard rng.chance(chance) else { continue }
            var weeks = rng.chance(0.1) ? rng.int(8...16) : rng.int(1...6)
            weeks = max(1, Int((Double(weeks) * (1.1 - medical * 0.04)).rounded()))
            injuries.append((playerID: stint.player.id, weeks: weeks))
            events.append(MatchEvent(minute: rng.int((stint.from + 1)...stint.to), kind: .injury, clubID: club.id,
                                     playerID: stint.player.id, assistID: nil))
        }
    }

    private static func rate(
        _ stints: [Stint],
        clubID: UUID,
        scored: Int,
        conceded: Int,
        goals: [UUID: Int],
        assists: [UUID: Int],
        discipline: [UUID: Double],
        ratings: inout [PlayerRating],
        appearances: inout [Appearance],
        rng: inout SeededRandom
    ) {
        guard !stints.isEmpty else { return }
        let teamAverage = stints.map(\.rating).reduce(0, +) / Double(stints.count)
        for stint in stints where stint.minutes > 0 {
            // Short cameos stay close to an average 6.4.
            let share = min(1, Double(stint.minutes) / 70)
            var swing = rng.normal(sd: 0.45)
            if scored > conceded { swing += 0.4 } else if scored < conceded { swing -= 0.35 }
            swing += (stint.rating - teamAverage) / 25
            switch stint.slot.line {
            case .goalkeeper:
                swing += conceded == 0 ? 0.6 : -0.25 * Double(conceded)
            case .defence:
                swing += conceded == 0 ? 0.5 : -0.18 * Double(conceded)
            case .midfield where stint.slot == .defensiveMid:
                swing += conceded == 0 ? 0.3 : -0.1 * Double(conceded)
            default:
                break
            }
            let playerGoals = goals[stint.player.id] ?? 0
            let playerAssists = assists[stint.player.id] ?? 0
            var rating = 6.4 + swing * share + Double(playerGoals) * 1.0 + Double(playerAssists) * 0.6
                + (discipline[stint.player.id] ?? 0)
            rating = ((rating * 10).rounded() / 10).clamped(to: 3.5...10)
            ratings.append(PlayerRating(playerID: stint.player.id, clubID: clubID, rating: rating, minutes: stint.minutes))
            appearances.append(Appearance(playerID: stint.player.id, clubID: clubID, minutes: stint.minutes,
                                          rating: rating, goals: playerGoals, assists: playerAssists))
        }
    }
}
