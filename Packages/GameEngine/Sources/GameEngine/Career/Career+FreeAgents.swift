import Foundation

/// Free agents: players without a club. They join for no fee but ask for higher wages,
/// and they can sign at any time of the season (not only in transfer windows).
extension Career {
    /// Free agents ask this much more than their usual wage.
    public static let freeAgentWagePremium = 1.4
    /// The pool is trimmed to this size at the end of every season.
    static let maxFreeAgents = 160

    /// Free agents, best first.
    public func freeAgents(filter: TransferFilter = TransferFilter(), limit: Int = 200) -> [Player] {
        let query = filter.query.trimmingCharacters(in: .whitespaces).lowercased()
        let results = players.values.filter { player in
            guard player.isFreeAgent else { return false }
            if let position = filter.position, player.position != position { return false }
            if let minOverall = filter.minOverall, player.overall < minOverall { return false }
            if let maxAge = filter.maxAge, player.age(in: season) > maxAge { return false }
            if !query.isEmpty && !player.fullName.lowercased().contains(query) { return false }
            return true
        }
        return Array(results.sorted { ($0.overall, $0.potential, $0.id.uuidString) > ($1.overall, $1.potential, $1.id.uuidString) }.prefix(limit))
    }

    public var freeAgentCount: Int {
        players.values.filter(\.isFreeAgent).count
    }

    /// Releases a player from his club: he becomes a free agent.
    mutating func release(_ playerID: UUID) {
        guard let clubID = players[playerID]?.clubID else { return }
        clubs[clubID]?.playerIDs.removeAll { $0 == playerID }
        players[playerID]?.clubID = nil
        players[playerID]?.lastClubID = clubID
        players[playerID]?.isTransferListed = false
        players[playerID]?.morale = 55
        if clubID == userClubID {
            post(.playerLeft(playerID: playerID, toClubID: nil, fee: 0))
        }
    }

    /// Ends a player's career. The record is kept only if he ever played for the user's club,
    /// so old messages can still show his name.
    mutating func retire(_ playerID: UUID) {
        guard let player = players[playerID] else { return }
        if let clubID = player.clubID {
            clubs[clubID]?.playerIDs.removeAll { $0 == playerID }
            if clubID == userClubID {
                post(.playerLeft(playerID: playerID, toClubID: nil, fee: 0))
            }
        }
        if player.clubID == userClubID || player.lastClubID == userClubID {
            players[playerID]?.clubID = nil
            players[playerID]?.isRetired = true
        } else {
            players.removeValue(forKey: playerID)
        }
    }

    /// AI club signs a free agent on a normal contract.
    mutating func aiSign(_ playerID: UUID, clubID: UUID) {
        guard let player = players[playerID], player.isFreeAgent else { return }
        let wage = player.expectedWage(season: season)
        movePlayer(playerID, from: nil, to: clubID, wage: wage, years: rng.int(1...3))
        talks.removeValue(forKey: playerID)
    }

    /// Adds `count` new free agents, spread over all positions and levels.
    mutating func seedFreeAgents(count: Int, season targetSeason: Int) {
        let countries = WorldData.countries.map(\.code)
        let template = PlayerGenerator.squadTemplate
        for _ in 0..<count {
            let index = rng.weightedIndex(template.map { Double($0.count) }) ?? 0
            let home = rng.pick(countries)
            let nationality = NamePools.randomNationality(domestic: home, domesticShare: 0.5, rng: &rng)
            var player = PlayerGenerator.make(
                position: template[index].position,
                targetOverall: Int(rng.normal(mean: 63, sd: 7).rounded()).clamped(to: 48...80),
                age: rng.int(21...33),
                nationality: nationality,
                season: targetSeason,
                clubID: nil,
                rng: &rng
            )
            player.contract.expiresSeason = targetSeason - 1
            players[player.id] = player
        }
    }

    /// During the windows AI clubs pick up a few free agents, so the pool keeps moving.
    mutating func aiFreeAgentSignings() {
        guard isTransferWindowOpen else { return }
        let pool = freeAgents(limit: 300)
        guard !pool.isEmpty else { return }
        let signings = rng.int(0...2)
        var taken = Set<UUID>()
        for _ in 0..<signings {
            let candidates = pool.filter { !taken.contains($0.id) }
            guard !candidates.isEmpty else { return }
            let player = rng.pick(candidates)
            let clubsForHim = clubs.values
                .filter { club in
                    club.id != userClubID
                        && club.playerIDs.count < 28
                        && abs(Career.averageOverall(reputation: club.reputation) - Double(player.overall)) <= 4
                }
                .sorted { $0.name < $1.name }
            guard !clubsForHim.isEmpty else { continue }
            aiSign(player.id, clubID: rng.pick(clubsForHim).id)
            taken.insert(player.id)
        }
    }

    /// End of season: older free agents retire and the pool is kept to a sensible size.
    mutating func trimFreeAgents(nextSeason: Int) {
        for player in players.values where player.isFreeAgent && player.age(in: nextSeason) >= 34 {
            retire(player.id)
        }
        let pool = freeAgents(limit: Int.max)
        if pool.count > Career.maxFreeAgents {
            for player in pool.suffix(pool.count - Career.maxFreeAgents) {
                retire(player.id)
            }
        }
        // Keep the market interesting even after a quiet summer.
        let remaining = freeAgentCount
        if remaining < 40 {
            seedFreeAgents(count: 40 - remaining, season: nextSeason)
        }
    }
}
