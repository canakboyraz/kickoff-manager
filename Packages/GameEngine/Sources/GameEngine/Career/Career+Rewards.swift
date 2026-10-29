import Foundation

/// Why the manager earned Kickoff Points (spent on packs and cosmetics in the app).
public enum RewardReason: String, Codable, Hashable, Sendable {
    case matchWin, matchDraw, leagueTitle, seasonFinish, beatExpectations, cupProgress, cupWin, playerSale
}

public struct RewardEvent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var reason: RewardReason
    public var points: Int
    public var season: Int
    public var week: Int
}

/// Quality band of a player card pulled from a pack, relative to the user's club.
public enum PackPlayerTier: String, Codable, CaseIterable, Hashable, Sendable {
    /// Teenager with high potential.
    case prospect
    /// A useful squad player at the club's level.
    case solid
    /// Clearly better than the current squad.
    case star
    /// Rare: one of the best players the club could dream of.
    case legend
}

extension Career {
    /// Points from one season's events, kept for the profile screen.
    static let rewardLogLimit = 40

    mutating func award(_ points: Int, _ reason: RewardReason) {
        guard points > 0, !isUnemployed else { return }
        pendingRewardPoints += points
        lifetimeRewardPoints += points
        rewardLog.append(RewardEvent(id: UUID(), reason: reason, points: points, season: season, week: week))
        if rewardLog.count > Career.rewardLogLimit {
            rewardLog.removeFirst(rewardLog.count - Career.rewardLogLimit)
        }
    }

    /// Hands the points earned since the last call over to the app's wallet.
    public mutating func claimRewardPoints() -> Int {
        let points = pendingRewardPoints
        pendingRewardPoints = 0
        return points
    }

    // MARK: - Hooks

    mutating func rewardMatch(scored: Int, conceded: Int) {
        if scored > conceded {
            award(20 + min(3, scored - conceded) * 5, .matchWin)
        } else if scored == conceded {
            award(8, .matchDraw)
        }
    }

    mutating func rewardSeason(expected: Int, position: Int) {
        switch position {
        case 1: award(1_500, .leagueTitle)
        case 2...3: award(500, .seasonFinish)
        case 4...6: award(250, .seasonFinish)
        default: award(100, .seasonFinish)
        }
        if expected > position {
            award((expected - position) * 40, .beatExpectations)
        }
    }

    mutating func rewardCup(_ kind: CompetitionKind, won: Bool) {
        if won {
            award(kind == .eliteCup ? 2_500 : 1_200, .cupWin)
        } else {
            award(kind == .eliteCup ? 200 : 120, .cupProgress)
        }
    }

    mutating func rewardSale(fee: Int) {
        award(max(10, fee / 250_000), .playerSale)
    }

    // MARK: - Pack players

    /// Creates a player for a pack and adds him to the user's squad on a cheap three-year deal.
    /// Returns nil when the squad is full (the app refunds points instead).
    public mutating func addPackPlayer(tier: PackPlayerTier, position: Position? = nil) -> Player? {
        guard !isUnemployed, userClub.playerIDs.count < Career.maxSquadSize else { return nil }
        let average = Career.averageOverall(reputation: userClub.reputation)
        let target: Int
        let age: Int
        switch tier {
        case .prospect:
            target = Int(average) - rng.int(6...10)
            age = rng.int(17...19)
        case .solid:
            target = Int(average) + rng.int(-2...2)
            age = rng.int(22...28)
        case .star:
            target = Int(average) + rng.int(4...8)
            age = rng.int(23...29)
        case .legend:
            target = min(92, Int(average) + rng.int(10...14))
            age = rng.int(25...30)
        }
        let template = PlayerGenerator.squadTemplate
        let chosen = position ?? template[rng.weightedIndex(template.map { Double($0.count) }) ?? 0].position
        let nationality = NamePools.randomNationality(domestic: userClub.countryCode, domesticShare: 0.4, rng: &rng)
        var player = PlayerGenerator.make(
            position: chosen,
            targetOverall: target,
            age: age,
            nationality: nationality,
            season: season,
            clubID: userClubID,
            rng: &rng
        )
        if tier == .prospect {
            player.potential = min(95, max(player.potential, Int(average) + rng.int(6...14)))
        }
        player.contract = Contract(
            weeklyWage: Career.roundTo(Double(player.expectedWage(season: season)) * 0.6, step: 500),
            expiresSeason: season + 3
        )
        player.morale = 85
        players[player.id] = player
        clubs[userClubID]?.playerIDs.append(player.id)
        post(.signingCompleted(playerID: player.id, fee: 0))
        normalizeUserTactics()
        return player
    }
}
