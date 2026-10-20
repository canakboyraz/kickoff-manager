import Foundation

extension Career {
    // MARK: - Team sheets

    /// Who plays for a club in its next match. AI clubs pick the best fit eleven; the user's
    /// selection is used as set, with injured or missing starters replaced (bench first).
    public func teamSheet(for clubID: UUID) -> TeamSheet {
        let squad = self.squad(of: clubID)
        guard clubID == userClubID else {
            return Selection.autoSheet(squad: squad, formation: clubs[clubID]?.formation ?? .f433)
        }
        let formation = userTactics.formation
        let slots = formation.slots
        let byID = Dictionary(uniqueKeysWithValues: squad.map { ($0.id, $0) })
        var picked: [Player?] = slots.indices.map { index in
            guard index < userTactics.starters.count, let id = userTactics.starters[index],
                  let player = byID[id], !player.isInjured else { return nil }
            return player
        }
        let bench = userTactics.bench.compactMap { byID[$0] }.filter { !$0.isInjured }
        let fit = squad.filter { !$0.isInjured }
        picked = Selection.fill(slots: slots, preset: picked, pool: bench)
        picked = Selection.fill(slots: slots, preset: picked, pool: fit)

        let starters = Selection.lineupSlots(slots: slots, players: picked)
        let used = Set(starters.map(\.player.id))
        var finalBench = bench.filter { !used.contains($0.id) }
        if finalBench.count < Tactics.benchSize {
            let taken = used.union(finalBench.map(\.id))
            finalBench += Selection.bench(from: fit, excluding: taken, size: Tactics.benchSize - finalBench.count)
        }
        return TeamSheet(formation: formation, starters: starters, bench: Array(finalBench.prefix(Tactics.benchSize)))
    }

    // MARK: - The user's selection

    /// Starters aligned with `userTactics.formation.slots` (nil = empty slot).
    public var userStarters: [Player?] {
        userTactics.formation.slots.indices.map { index in
            guard index < userTactics.starters.count, let id = userTactics.starters[index],
                  let player = players[id], player.clubID == userClubID else { return nil }
            return player
        }
    }

    public var userBench: [Player] {
        userTactics.bench.compactMap { players[$0] }.filter { $0.clubID == userClubID }
    }

    /// Squad players who are neither starting nor on the bench.
    public var userReserves: [Player] {
        let used = Set(userTactics.starters.compactMap { $0 } + userTactics.bench)
        return userSquad.filter { !used.contains($0.id) }
    }

    public func lineupPlayer(_ ref: LineupRef) -> Player? {
        switch ref {
        case .starter(let index):
            guard index < userTactics.starters.count else { return nil }
            return userTactics.starters[index].flatMap { players[$0] }
        case .bench(let index):
            guard index < userTactics.bench.count else { return nil }
            return players[userTactics.bench[index]]
        case .reserve(let id):
            return players[id]
        }
    }

    /// Changes the shape and re-fits the current starters into the new slots.
    public mutating func setFormation(_ formation: Formation) {
        guard formation != userTactics.formation else { return }
        let current = userStarters.compactMap { $0 }
        let refit = Selection.fill(slots: formation.slots, preset: [], pool: current)
        userTactics.formation = formation
        userTactics.starters = refit.map { $0?.id }
        normalizeUserTactics()
    }

    /// Picks the best and freshest eleven and bench for the current formation.
    public mutating func autoPickLineup() {
        let fit = userSquad.filter { !$0.isInjured }
        let picked = Selection.fill(slots: userTactics.formation.slots, preset: [], pool: fit)
        userTactics.starters = picked.map { $0?.id }
        let used = Set(picked.compactMap { $0?.id })
        userTactics.bench = Selection.bench(from: fit, excluding: used).map(\.id)
    }

    /// Swaps the players in two places (starter ↔ starter, starter ↔ bench, bench ↔ reserve…).
    public mutating func swapLineup(_ first: LineupRef, _ second: LineupRef) {
        guard first != second else { return }
        let firstID = playerID(at: first)
        let secondID = playerID(at: second)
        guard firstID != nil || secondID != nil else { return }
        place(secondID, at: first)
        place(firstID, at: second)
        normalizeBench()
    }

    private func playerID(at ref: LineupRef) -> UUID? {
        switch ref {
        case .starter(let index):
            return index < userTactics.starters.count ? userTactics.starters[index] : nil
        case .bench(let index):
            return index < userTactics.bench.count ? userTactics.bench[index] : nil
        case .reserve(let id):
            return id
        }
    }

    private mutating func place(_ id: UUID?, at ref: LineupRef) {
        switch ref {
        case .starter(let index):
            guard index < userTactics.formation.slots.count else { return }
            while userTactics.starters.count <= index { userTactics.starters.append(nil) }
            userTactics.starters[index] = id
        case .bench(let index):
            if index < userTactics.bench.count {
                if let id {
                    userTactics.bench[index] = id
                } else {
                    // Mark for removal; normalizeBench drops it.
                    userTactics.bench[index] = Career.removedMarker
                }
            } else if let id {
                userTactics.bench.append(id)
            }
        case .reserve:
            break // Reserves are simply everyone not selected.
        }
    }

    private static let removedMarker = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    private mutating func normalizeBench() {
        var seen = Set(userTactics.starters.compactMap { $0 })
        userTactics.bench = userTactics.bench.filter { id in
            guard id != Career.removedMarker, !seen.contains(id) else { return false }
            seen.insert(id)
            return true
        }
        if userTactics.bench.count > Tactics.benchSize {
            userTactics.bench = Array(userTactics.bench.prefix(Tactics.benchSize))
        }
    }

    /// Drops players who left, fills empty starting slots and tops the bench up to seven.
    mutating func normalizeUserTactics() {
        let squad = userSquad
        let squadIDs = Set(squad.map(\.id))
        let slots = userTactics.formation.slots

        var seen = Set<UUID>()
        var starters: [UUID?] = slots.indices.map { index in
            guard index < userTactics.starters.count, let id = userTactics.starters[index],
                  squadIDs.contains(id), !seen.contains(id) else { return nil }
            seen.insert(id)
            return id
        }
        var bench: [UUID] = []
        for id in userTactics.bench where squadIDs.contains(id) && !seen.contains(id) && bench.count < Tactics.benchSize {
            seen.insert(id)
            bench.append(id)
        }

        if starters.contains(where: { $0 == nil }) {
            let byID = Dictionary(uniqueKeysWithValues: squad.map { ($0.id, $0) })
            let preset = starters.map { $0.flatMap { byID[$0] } }
            let pool = squad.filter { !$0.isInjured && !seen.contains($0.id) }
            starters = Selection.fill(slots: slots, preset: preset, pool: pool).map { $0?.id }
            seen.formUnion(starters.compactMap { $0 })
        }
        if bench.count < Tactics.benchSize {
            let extra = Selection.bench(from: squad, excluding: seen, size: Tactics.benchSize - bench.count)
            bench += extra.map(\.id)
        }
        userTactics.starters = starters
        userTactics.bench = bench
    }
}
