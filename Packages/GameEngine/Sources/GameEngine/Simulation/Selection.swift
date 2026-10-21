import Foundation

public struct LineupSlot: Hashable, Sendable {
    public var slot: Position
    public var player: Player
    /// Rating in this slot after position, morale and fitness effects.
    public var effectiveRating: Double
}

/// Who plays in a match.
public struct TeamSheet: Hashable, Sendable {
    public var formation: Formation
    /// Starters in formation slot order.
    public var starters: [LineupSlot]
    public var bench: [Player]
}

public enum Selection {
    /// How well a player performs in a slot right now.
    public static func rating(of player: Player, in slot: Position) -> Double {
        var value = Double(player.attributes.overall(for: slot))
        if player.position != slot {
            value -= player.position.line == slot.line ? 2 : 6
        }
        value += Double(player.morale - 60) / 20
        value -= Double(max(0, 85 - player.fitness)) * 0.22
        return value
    }

    /// Scarce positions are filled first so the best keeper/striker aren't used elsewhere.
    static let fillPriority: [Position] = [
        .goalkeeper, .striker, .defensiveMid, .attackingMid, .fullBack, .winger, .centreBack, .centralMid
    ]

    /// Fills the nil entries of `preset` (one per slot) with the best players left in `pool`.
    public static func fill(slots: [Position], preset: [Player?], pool: [Player]) -> [Player?] {
        var result = Array(preset.prefix(slots.count))
        if result.count < slots.count {
            result += Array(repeating: nil, count: slots.count - result.count)
        }
        let used = Set(result.compactMap { $0?.id })
        var available = pool.filter { !used.contains($0.id) }
        let order = slots.indices.sorted { lhs, rhs in
            let left = fillPriority.firstIndex(of: slots[lhs]) ?? fillPriority.count
            let right = fillPriority.firstIndex(of: slots[rhs]) ?? fillPriority.count
            return left != right ? left < right : lhs < rhs
        }
        for index in order where result[index] == nil {
            let slot = slots[index]
            guard let best = available.max(by: { rating(of: $0, in: slot) < rating(of: $1, in: slot) }) else { break }
            result[index] = best
            available.removeAll { $0.id == best.id }
        }
        return result
    }

    /// A bench with a spare keeper first, then the best remaining fit players.
    public static func bench(from pool: [Player], excluding: Set<UUID>, size: Int = Tactics.benchSize) -> [Player] {
        guard size > 0 else { return [] }
        let available = pool.filter { !excluding.contains($0.id) && $0.isAvailable }
        var bench: [Player] = []
        if let keeper = available.filter({ $0.position == .goalkeeper }).max(by: { $0.overall < $1.overall }) {
            bench.append(keeper)
        }
        let rest = available
            .filter { player in !bench.contains { $0.id == player.id } && player.position != .goalkeeper }
            .sorted { ($0.overall, $0.fitness) > ($1.overall, $1.fitness) }
        bench += rest.prefix(max(0, size - bench.count))
        return bench
    }

    static func lineupSlots(slots: [Position], players: [Player?]) -> [LineupSlot] {
        var result: [LineupSlot] = []
        for (index, slot) in slots.enumerated() where index < players.count {
            guard let player = players[index] else { continue }
            result.append(LineupSlot(slot: slot, player: player, effectiveRating: rating(of: player, in: slot)))
        }
        return result
    }

    /// Best available eleven and bench (used by AI clubs every match).
    public static func autoSheet(squad: [Player], formation: Formation) -> TeamSheet {
        let fit = squad.filter { $0.isAvailable }
        let slots = formation.slots
        let picked = fill(slots: slots, preset: [], pool: fit)
        let starters = lineupSlots(slots: slots, players: picked)
        let bench = bench(from: fit, excluding: Set(starters.map(\.player.id)))
        return TeamSheet(formation: formation, starters: starters, bench: bench)
    }
}
