import SwiftUI
import GameEngine

/// What one card in a pack can be.
enum PackDrop: Hashable {
    case player(PackPlayerTier)
    case cosmetic(Rarity)
    case points(Int)

    var label: String {
        switch self {
        case .player(let tier): return L("pack.drop.player.\(tier.rawValue)")
        case .cosmetic(let rarity): return L("pack.drop.cosmetic", rarity.label)
        case .points(let amount): return L("pack.drop.points", Fmt.number(amount))
        }
    }
}

/// A pack type. Each slot is a weighted table; every card is rolled from its own slot.
struct PackType: Identifiable, Hashable {
    let id: String
    let cost: Int
    let colors: [String]
    let slots: [[(drop: PackDrop, weight: Double)]]

    static func == (lhs: PackType, rhs: PackType) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var name: String { L("pack.\(id)") }
    var cardCount: Int { slots.count }

    var gradient: LinearGradient {
        LinearGradient(colors: colors.map(Color.init(hex:)), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Odds per card, merged across identical slots, for the odds sheet.
    var oddsTables: [(cards: Int, rows: [(label: String, percent: Double)])] {
        var groups: [(cards: Int, rows: [(label: String, percent: Double)])] = []
        var index = 0
        while index < slots.count {
            let slot = slots[index]
            var count = 1
            while index + count < slots.count && slots[index + count].map({ $0.drop }) == slot.map({ $0.drop })
                    && slots[index + count].map({ $0.weight }) == slot.map({ $0.weight }) {
                count += 1
            }
            let total = slot.map({ $0.weight }).reduce(0, +)
            groups.append((count, slot.map { ($0.drop.label, $0.weight / total * 100) }))
            index += count
        }
        return groups
    }

    func roll() -> [PackDrop] {
        slots.map { slot in
            let total = slot.map({ $0.weight }).reduce(0, +)
            var pick = Double.random(in: 0..<total)
            for entry in slot {
                if pick < entry.weight { return entry.drop }
                pick -= entry.weight
            }
            return slot.last!.drop
        }
    }

    // MARK: Catalog

    private static let cosmeticSlot: [(drop: PackDrop, weight: Double)] = [
        (.cosmetic(.common), 55), (.cosmetic(.rare), 28), (.cosmetic(.epic), 9), (.cosmetic(.legendary), 2),
        (.points(150), 6)
    ]

    static let all: [PackType] = [
        PackType(id: "bronze", cost: 400, colors: ["F0B98A", "8C5A2B", "3B230E"], slots: [
            [(.player(.prospect), 12), (.player(.solid), 5), (.cosmetic(.common), 60), (.cosmetic(.rare), 18), (.points(100), 5)],
            cosmeticSlot, cosmeticSlot
        ]),
        PackType(id: "silver", cost: 1_200, colors: ["FFFFFF", "A7AFB9", "3A4250"], slots: [
            [(.player(.prospect), 30), (.player(.solid), 45), (.player(.star), 6), (.cosmetic(.rare), 19)],
            cosmeticSlot, cosmeticSlot, cosmeticSlot
        ]),
        PackType(id: "gold", cost: 3_500, colors: ["FFE29A", "EF9F27", "6B3B00"], slots: [
            [(.player(.solid), 55), (.player(.star), 38), (.player(.legend), 3), (.player(.prospect), 4)],
            [(.player(.prospect), 40), (.player(.solid), 25), (.cosmetic(.rare), 25), (.cosmetic(.epic), 10)],
            [(.cosmetic(.rare), 55), (.cosmetic(.epic), 35), (.cosmetic(.legendary), 10)],
            cosmeticSlot, cosmeticSlot
        ]),
        PackType(id: "elite", cost: 9_000, colors: ["B27BFF", "3C2A9E", "0B0730"], slots: [
            [(.player(.star), 85), (.player(.legend), 15)],
            [(.player(.solid), 45), (.player(.star), 35), (.player(.prospect), 20)],
            [(.cosmetic(.epic), 70), (.cosmetic(.legendary), 30)],
            [(.cosmetic(.rare), 50), (.cosmetic(.epic), 40), (.cosmetic(.legendary), 10)],
            cosmeticSlot
        ])
    ]
}

/// A card revealed from a pack, after the roll was applied to the career and profile.
enum PackReward: Hashable {
    case player(Player, PackPlayerTier)
    case cosmetic(Cosmetic, isNew: Bool)
    case points(Int, reason: String)

    /// Rarity used for the reveal glow.
    var rarity: Rarity {
        switch self {
        case .player(_, let tier):
            switch tier {
            case .prospect: return .rare
            case .solid: return .common
            case .star: return .epic
            case .legend: return .legendary
            }
        case .cosmetic(let item, _): return item.rarity
        case .points: return .common
        }
    }

    var isWalkout: Bool {
        if case .player(_, let tier) = self { return tier == .star || tier == .legend }
        return false
    }
}

/// One revealed card with a stable identity for the reveal screen.
struct RevealedCard: Identifiable {
    let id = UUID()
    let reward: PackReward
}

@MainActor
enum PackOpener {
    /// Pays for the pack, rolls it and applies the results. Nil when there aren't enough points.
    static func open(_ pack: PackType, store: GameStore) -> [RevealedCard]? {
        let profile = store.profile
        guard profile.spend(pack.cost) else { return nil }
        var rewards: [PackReward] = []
        var legends = 0
        for drop in pack.roll() {
            switch drop {
            case .player(let tier):
                let added: Player?? = store.update { $0.addPackPlayer(tier: tier) }
                if let player = added ?? nil {
                    rewards.append(.player(player, tier))
                    if tier == .legend { legends += 1 }
                } else {
                    // No career or a full squad: the card turns into points.
                    let refund = tier == .legend ? 3_000 : (tier == .star ? 1_200 : 300)
                    profile.earn(refund)
                    rewards.append(.points(refund, reason: L("pack.squadFull")))
                }
            case .cosmetic(let rarity):
                let pool = CosmeticCatalog.all.filter { $0.rarity == rarity && !$0.isDefault }
                let notOwned = pool.filter { !profile.owns($0) }
                // Unowned items are three times as likely, so collections fill up.
                let weighted = notOwned + notOwned + pool
                let item = weighted.randomElement() ?? CosmeticCatalog.defaultItem(.badge)
                if profile.unlock(item) {
                    rewards.append(.cosmetic(item, isNew: true))
                } else {
                    profile.earn(item.rarity.duplicateRefund)
                    rewards.append(.cosmetic(item, isNew: false))
                }
            case .points(let amount):
                profile.earn(amount)
                rewards.append(.points(amount, reason: L("pack.bonus")))
            }
        }
        profile.recordPack(legends: legends)
        // Best cards are revealed last, like the real thing.
        return rewards.sorted { $0.rarity < $1.rarity }.map(RevealedCard.init(reward:))
    }
}
