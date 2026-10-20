import Foundation

enum PlayerGenerator {
    /// Creates a player whose overall rating lands close to `targetOverall`.
    static func make(
        position: Position,
        targetOverall: Int,
        age: Int,
        nationality: String,
        season: Int,
        clubID: UUID?,
        rng: inout SeededRandom
    ) -> Player {
        let target = targetOverall.clamped(to: 30...94)
        let weights = Attributes.weights(for: position)

        var attributes = Attributes(pace: 0, shooting: 0, passing: 0, dribbling: 0, defending: 0, physical: 0, goalkeeping: 0)
        for kind in AttributeKind.allCases {
            let base: Double
            if position == .goalkeeper {
                base = kind == .goalkeeping ? Double(target) : Double(target) - 25
            } else if kind == .goalkeeping {
                base = Double(rng.int(8...20))
            } else if let weight = weights[kind] {
                base = Double(target) + weight * 10
            } else {
                base = Double(target) - 12
            }
            let spread = kind == .goalkeeping && position != .goalkeeper ? 0 : 5.0
            attributes[kind] = Int(rng.normal(mean: base, sd: spread).rounded())
        }

        // Nudge the key attributes until the overall matches the target.
        for _ in 0..<4 {
            let difference = target - attributes.overall(for: position)
            if difference == 0 { break }
            for (kind, _) in weights {
                attributes[kind] = attributes[kind] + difference
            }
        }

        let overall = attributes.overall(for: position)
        let potential = makePotential(overall: overall, age: age, rng: &rng)
        let name = NamePools.name(for: nationality, rng: &rng)

        var player = Player(
            id: UUID(),
            firstName: name.first,
            lastName: name.last,
            nationality: nationality,
            birthYear: season - age,
            position: position,
            attributes: attributes,
            potential: potential,
            morale: rng.int(60...80),
            recentRatings: [],
            clubID: clubID,
            contract: Contract(weeklyWage: 0, expiresSeason: season + rng.int(1...4)),
            injuryWeeks: 0,
            stats: SeasonStats(),
            careerGoals: 0,
            careerAppearances: 0,
            developmentProgress: 0,
            appearancesSinceTick: 0
        )
        player.contract.weeklyWage = player.expectedWage(season: season)
        return player
    }

    static func makePotential(overall: Int, age: Int, rng: inout SeededRandom) -> Int {
        let headroom: Double
        switch age {
        case ...18: headroom = rng.normal(mean: 18, sd: 7)
        case 19...21: headroom = rng.normal(mean: 12, sd: 6)
        case 22...24: headroom = rng.normal(mean: 6, sd: 4)
        case 25...27: headroom = rng.normal(mean: 2, sd: 2)
        default: headroom = 0
        }
        return max(overall, min(95, overall + max(0, Int(headroom.rounded()))))
    }

    /// Squad template: 24 players per club.
    static let squadTemplate: [(position: Position, count: Int)] = [
        (.goalkeeper, 3), (.centreBack, 4), (.fullBack, 4), (.defensiveMid, 2),
        (.centralMid, 4), (.attackingMid, 2), (.winger, 3), (.striker, 2)
    ]

    static func randomAge(rng: inout SeededRandom) -> Int {
        Int(rng.normal(mean: 26, sd: 4).rounded()).clamped(to: 17...36)
    }
}
