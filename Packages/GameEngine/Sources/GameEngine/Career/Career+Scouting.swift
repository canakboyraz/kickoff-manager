import Foundation

/// Scouts search for players that fit a brief. Players they find are cheaper to sign
/// this season: lower asking price and a smaller wage demand.
extension Career {
    public static let maxScoutMissions = 2

    /// Fee for sending a scout out (bigger clubs pay their scouts more).
    public var scoutCost: Int {
        Career.roundTo(Double(80_000 + userClub.reputation * 2_000), step: 10_000)
    }

    /// Weeks a mission takes: one league is quicker than the whole world.
    public static func scoutWeeks(for brief: ScoutBrief) -> Int {
        brief.countryCode == nil ? 3 : 2
    }

    public func scoutReport(for playerID: UUID) -> ScoutReport? {
        scoutReports.first { $0.playerID == playerID }
    }

    /// Found players that can still be signed, best verdict first.
    public var scoutedPlayers: [(report: ScoutReport, player: Player)] {
        scoutReports.compactMap { report in
            guard let player = players[report.playerID], player.clubID != userClubID, !player.isRetired else { return nil }
            return (report, player)
        }
        .sorted { ($0.report.stars, $0.player.potential) > ($1.report.stars, $1.player.potential) }
    }

    public mutating func startScoutMission(_ brief: ScoutBrief) -> ScoutResult {
        guard scoutMissions.count < Career.maxScoutMissions else { return .tooManyMissions }
        let cost = scoutCost
        guard userClub.finances.balance >= cost else { return .insufficientFunds }
        clubs[userClubID]?.finances.balance -= cost
        clubs[userClubID]?.finances.seasonExpenses += cost
        let weeks = Career.scoutWeeks(for: brief)
        scoutMissions.append(ScoutMission(id: UUID(), brief: brief, weeksLeft: weeks, cost: cost))
        return .started(weeks: weeks)
    }

    public mutating func cancelScoutMission(_ id: UUID) {
        scoutMissions.removeAll { $0.id == id }
    }

    /// Weekly: missions move on and finished ones report back.
    mutating func tickScouts() {
        guard !scoutMissions.isEmpty, !isUnemployed else { return }
        var finished: [ScoutMission] = []
        for index in scoutMissions.indices {
            scoutMissions[index].weeksLeft -= 1
            if scoutMissions[index].weeksLeft <= 0 { finished.append(scoutMissions[index]) }
        }
        scoutMissions.removeAll { $0.weeksLeft <= 0 }
        for mission in finished {
            let found = scout(mission.brief)
            scoutReports.append(contentsOf: found)
            post(.scoutReport(playerIDs: found.map(\.playerID)))
        }
    }

    /// Picks up to five players that fit the brief, favouring high potential and hidden gems.
    mutating func scout(_ brief: ScoutBrief) -> [ScoutReport] {
        let known = Set(scoutReports.map(\.playerID))
        var candidates = players.values.filter { player in
            guard !player.isRetired, player.clubID != userClubID, !known.contains(player.id) else { return false }
            if let code = brief.countryCode {
                guard let clubID = player.clubID, clubs[clubID]?.countryCode == code else { return false }
            }
            if let position = brief.position, player.position != position { return false }
            if let maxAge = brief.maxAge, player.age(in: season) > maxAge { return false }
            if let minPotential = brief.minPotential, player.potential < minPotential { return false }
            if let maxValue = brief.maxValue, player.marketValue(season: season) > maxValue { return false }
            return true
        }
        .sorted { $0.id.uuidString < $1.id.uuidString }

        var reports: [ScoutReport] = []
        while reports.count < 5 && !candidates.isEmpty {
            let weights = candidates.map { player -> Double in
                let potential = Double(max(1, player.potential - 50))
                let headroom = Double(max(0, player.potential - player.overall))
                return pow(potential, 1.6) + headroom * 6
            }
            guard let index = rng.weightedIndex(weights) else { break }
            let player = candidates.remove(at: index)
            reports.append(ScoutReport(
                playerID: player.id,
                season: season,
                feeDiscount: (rng.double(0.12...0.25) * 100).rounded() / 100,
                wageDiscount: (rng.double(0.05...0.12) * 100).rounded() / 100,
                stars: Career.scoutStars(potential: player.potential)
            ))
        }
        return reports
    }

    static func scoutStars(potential: Int) -> Int {
        switch potential {
        case 86...: return 5
        case 80..<86: return 4
        case 74..<80: return 3
        case 68..<74: return 2
        default: return 1
        }
    }

    /// New season: last season's reports go stale.
    mutating func expireScoutReports() {
        scoutReports.removeAll { $0.season < season }
    }
}
