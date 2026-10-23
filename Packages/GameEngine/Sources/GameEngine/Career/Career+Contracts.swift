import Foundation

/// One line of a league's top scorer or assist chart.
public struct LeaderboardEntry: Hashable, Identifiable, Sendable {
    public var id: UUID { playerID }
    public var playerID: UUID
    /// The club he scored for (the latest one if he moved mid-season).
    public var clubID: UUID
    public var goals: Int
    public var assists: Int
    public var appearances: Int
}

public enum LeaderboardKind: String, CaseIterable, Sendable {
    case goals, assists
}

public enum BudgetMoveResult: Equatable, Sendable {
    case moved(transferBudget: Int, wageBudget: Int)
    case notEnough
    /// The wage budget can't drop below what the squad is already paid.
    case belowWageBill
    case invalid
}

// MARK: - Contracts

extension Career {
    /// User's players whose contracts end after this season (less than a year left), best first.
    public var expiringContracts: [Player] {
        userSquad
            .filter { $0.contract.expiresSeason <= season }
            .sorted { ($0.overall, $0.id.uuidString) > ($1.overall, $1.id.uuidString) }
    }

    /// Contracts that run out the season after (a year and a bit left).
    public var contractsEndingNextSeason: [Player] {
        userSquad
            .filter { $0.contract.expiresSeason == season + 1 }
            .sorted { ($0.overall, $0.id.uuidString) > ($1.overall, $1.id.uuidString) }
    }

    /// Matchdays left before expiring contracts run out.
    public var weeksUntilContractsExpire: Int { max(0, matchdayCount - week) }
}

// MARK: - Leaderboards

extension Career {
    /// Top scorers or assist leaders of a league this season, counted from league matches only.
    public func leaderboard(_ kind: LeaderboardKind, leagueID: UUID, limit: Int = 20) -> [LeaderboardEntry] {
        guard let league = league(leagueID) else { return [] }
        var entries: [UUID: LeaderboardEntry] = [:]
        for fixture in league.fixtures.sorted(by: { $0.matchday < $1.matchday }) {
            guard let result = fixture.result else { continue }
            for rating in result.ratings {
                var entry = entries[rating.playerID]
                    ?? LeaderboardEntry(playerID: rating.playerID, clubID: rating.clubID, goals: 0, assists: 0, appearances: 0)
                entry.appearances += 1
                entry.clubID = rating.clubID
                entries[rating.playerID] = entry
            }
            for event in result.events where event.kind == .goal {
                entries[event.playerID, default: LeaderboardEntry(playerID: event.playerID, clubID: event.clubID, goals: 0, assists: 0, appearances: 0)].goals += 1
                if let assistID = event.assistID {
                    entries[assistID, default: LeaderboardEntry(playerID: assistID, clubID: event.clubID, goals: 0, assists: 0, appearances: 0)].assists += 1
                }
            }
        }
        let ranked: [LeaderboardEntry]
        switch kind {
        case .goals:
            ranked = entries.values.filter { $0.goals > 0 }.sorted {
                if $0.goals != $1.goals { return $0.goals > $1.goals }
                if $0.appearances != $1.appearances { return $0.appearances < $1.appearances }
                if $0.assists != $1.assists { return $0.assists > $1.assists }
                return $0.playerID.uuidString < $1.playerID.uuidString
            }
        case .assists:
            ranked = entries.values.filter { $0.assists > 0 }.sorted {
                if $0.assists != $1.assists { return $0.assists > $1.assists }
                if $0.appearances != $1.appearances { return $0.appearances < $1.appearances }
                if $0.goals != $1.goals { return $0.goals > $1.goals }
                return $0.playerID.uuidString < $1.playerID.uuidString
            }
        }
        return Array(ranked.prefix(limit))
    }
}

// MARK: - Budgets

extension Career {
    /// €1 of weekly wage budget is worth this much transfer budget.
    public static let budgetConversionRate = 200

    /// Transfer budget that `weekly` euros of wage budget convert to (and back).
    public static func transferEquivalent(ofWeekly weekly: Int) -> Int { weekly * budgetConversionRate }

    /// Largest weekly amount that can move from the wage budget to the transfer budget.
    public var maxWageToTransfer: Int {
        max(0, userClub.finances.wageBudget - wageBill(of: userClubID))
    }

    /// Largest weekly amount the transfer budget can buy for the wage budget.
    public var maxTransferToWage: Int {
        max(0, userClub.finances.transferBudget / Career.budgetConversionRate)
    }

    /// Moves budget between transfers and wages. Positive `weekly` moves transfer money into
    /// the wage budget; negative moves wage budget back into transfers. Rate: `budgetConversionRate`.
    @discardableResult
    public mutating func moveBudget(weekly: Int) -> BudgetMoveResult {
        guard weekly != 0, !isUnemployed else { return .invalid }
        let amount = Career.transferEquivalent(ofWeekly: abs(weekly))
        if weekly > 0 {
            guard weekly <= maxTransferToWage else { return .notEnough }
            clubs[userClubID]?.finances.transferBudget -= amount
            clubs[userClubID]?.finances.wageBudget += weekly
        } else {
            guard -weekly <= maxWageToTransfer else { return .belowWageBill }
            clubs[userClubID]?.finances.wageBudget += weekly
            clubs[userClubID]?.finances.transferBudget += amount
        }
        return .moved(transferBudget: userClub.finances.transferBudget, wageBudget: userClub.finances.wageBudget)
    }
}

// MARK: - Bonuses

extension Career {
    /// Extra transfer money from the daily penalty challenge or a rewarded ad.
    public mutating func receiveBonus(_ amount: Int, source: BonusSource) {
        guard amount > 0, !isUnemployed else { return }
        clubs[userClubID]?.finances.balance += amount
        clubs[userClubID]?.finances.transferBudget += amount
        clubs[userClubID]?.finances.seasonIncome += amount
        post(.bonus(amount: amount, source: source))
    }
}
