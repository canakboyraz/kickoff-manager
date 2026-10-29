import SwiftUI

/// How rare a cosmetic is. Sets its price, glow colour and pack odds.
enum Rarity: Int, Codable, CaseIterable, Comparable {
    case common, rare, epic, legendary

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String { L("rarity.\(self)") }

    var color: Color {
        switch self {
        case .common: return Color(hex: "A9B4C2")
        case .rare: return Color(hex: "4FA3FF")
        case .epic: return Color(hex: "B27BFF")
        case .legendary: return Color(hex: "FFC94D")
        }
    }

    /// Price in the shop (Kickoff Points).
    var price: Int {
        switch self {
        case .common: return 300
        case .rare: return 900
        case .epic: return 2_500
        case .legendary: return 7_000
        }
    }

    /// Points given back when a pack drops something you already own.
    var duplicateRefund: Int { price / 4 }
}

enum CosmeticKind: String, Codable, CaseIterable {
    case frame, background, badge, title

    var label: String { L("cosmetic.kind.\(rawValue)") }
}

/// A profile decoration. `code` is a small stable number so the equipped set fits in a
/// Game Center leaderboard context and other players can see it.
struct Cosmetic: Identifiable, Hashable {
    let id: String
    let code: UInt8
    let kind: CosmeticKind
    let rarity: Rarity
    /// Colours for frames and backgrounds (first to last stop).
    var colors: [String] = []
    /// SF Symbol for badges.
    var symbol: String = ""

    var name: String { L("cos.\(id)") }

    var gradient: LinearGradient {
        LinearGradient(colors: colors.map(Color.init(hex:)), startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var isDefault: Bool { code == 0 }
}

enum CosmeticCatalog {
    static let all: [Cosmetic] = frames + backgrounds + badges + titles

    static let frames: [Cosmetic] = [
        Cosmetic(id: "frame.standard", code: 0, kind: .frame, rarity: .common, colors: ["5B6B82", "2E4566"]),
        Cosmetic(id: "frame.bronze", code: 1, kind: .frame, rarity: .common, colors: ["F0B98A", "8C5A2B"]),
        Cosmetic(id: "frame.silver", code: 2, kind: .frame, rarity: .common, colors: ["FFFFFF", "8E959E"]),
        Cosmetic(id: "frame.gold", code: 3, kind: .frame, rarity: .rare, colors: ["FFE29A", "EF9F27", "8A5200"]),
        Cosmetic(id: "frame.emerald", code: 4, kind: .frame, rarity: .rare, colors: ["8CFFC9", "0E8F5B"]),
        Cosmetic(id: "frame.sapphire", code: 5, kind: .frame, rarity: .epic, colors: ["9FD4FF", "1F5BFF", "0A1E66"]),
        Cosmetic(id: "frame.ruby", code: 6, kind: .frame, rarity: .epic, colors: ["FF9AA8", "D3123A", "5C0016"]),
        Cosmetic(id: "frame.midnight", code: 7, kind: .frame, rarity: .epic, colors: ["B9A6FF", "3C2A9E", "0B0730"]),
        Cosmetic(id: "frame.champion", code: 8, kind: .frame, rarity: .legendary, colors: ["FFF4C2", "FFC94D", "E07B00", "FFF4C2"]),
        Cosmetic(id: "frame.legend", code: 9, kind: .frame, rarity: .legendary,
                 colors: ["FF5E7E", "FFC94D", "5DFFB0", "4FA3FF", "B27BFF", "FF5E7E"])
    ]

    static let backgrounds: [Cosmetic] = [
        Cosmetic(id: "bg.navy", code: 0, kind: .background, rarity: .common, colors: ["1D2E45", "0E1A2B"]),
        Cosmetic(id: "bg.pitch", code: 1, kind: .background, rarity: .common, colors: ["2E8B57", "14532D"]),
        Cosmetic(id: "bg.stadium", code: 2, kind: .background, rarity: .rare, colors: ["0E1E3A", "2B4C7E", "F2C230"]),
        Cosmetic(id: "bg.sunset", code: 3, kind: .background, rarity: .rare, colors: ["FF8A5B", "C2185B", "311B92"]),
        Cosmetic(id: "bg.forest", code: 4, kind: .background, rarity: .epic, colors: ["0B3D2E", "1B7F5B", "A7F3D0"]),
        Cosmetic(id: "bg.crimson", code: 5, kind: .background, rarity: .epic, colors: ["2B0A12", "8B0F2B", "FF4D6D"]),
        Cosmetic(id: "bg.golden", code: 6, kind: .background, rarity: .legendary, colors: ["3A2400", "B37400", "FFE29A"]),
        Cosmetic(id: "bg.aurora", code: 7, kind: .background, rarity: .legendary, colors: ["071A2B", "1DE9B6", "7C4DFF", "071A2B"])
    ]

    static let badges: [Cosmetic] = [
        Cosmetic(id: "badge.star", code: 0, kind: .badge, rarity: .common, colors: ["FAC775"], symbol: "star.fill"),
        Cosmetic(id: "badge.ball", code: 1, kind: .badge, rarity: .common, colors: ["FFFFFF"], symbol: "soccerball"),
        Cosmetic(id: "badge.shield", code: 2, kind: .badge, rarity: .common, colors: ["85B7EB"], symbol: "shield.lefthalf.filled"),
        Cosmetic(id: "badge.flame", code: 3, kind: .badge, rarity: .rare, colors: ["FF7A3D"], symbol: "flame.fill"),
        Cosmetic(id: "badge.bolt", code: 4, kind: .badge, rarity: .rare, colors: ["FFE14D"], symbol: "bolt.fill"),
        Cosmetic(id: "badge.eagle", code: 5, kind: .badge, rarity: .rare, colors: ["E8E2D0"], symbol: "bird.fill"),
        Cosmetic(id: "badge.trophy", code: 6, kind: .badge, rarity: .epic, colors: ["FFC94D"], symbol: "trophy.fill"),
        Cosmetic(id: "badge.crown", code: 7, kind: .badge, rarity: .epic, colors: ["FFD86B"], symbol: "crown.fill"),
        Cosmetic(id: "badge.diamond", code: 8, kind: .badge, rarity: .legendary, colors: ["9FF3FF"], symbol: "diamond.fill"),
        Cosmetic(id: "badge.laurel", code: 9, kind: .badge, rarity: .legendary, colors: ["FFE29A"], symbol: "laurel.leading")
    ]

    static let titles: [Cosmetic] = [
        Cosmetic(id: "title.rookie", code: 0, kind: .title, rarity: .common),
        Cosmetic(id: "title.dealmaker", code: 1, kind: .title, rarity: .common),
        Cosmetic(id: "title.fanfavourite", code: 2, kind: .title, rarity: .common),
        Cosmetic(id: "title.tactician", code: 3, kind: .title, rarity: .rare),
        Cosmetic(id: "title.wolf", code: 4, kind: .title, rarity: .rare),
        Cosmetic(id: "title.talentscout", code: 5, kind: .title, rarity: .rare),
        Cosmetic(id: "title.ultra", code: 6, kind: .title, rarity: .epic),
        Cosmetic(id: "title.cupmonster", code: 7, kind: .title, rarity: .epic),
        Cosmetic(id: "title.conqueror", code: 8, kind: .title, rarity: .epic),
        Cosmetic(id: "title.legend", code: 9, kind: .title, rarity: .legendary)
    ]

    static func item(_ id: String) -> Cosmetic? { all.first { $0.id == id } }

    static func item(kind: CosmeticKind, code: UInt8) -> Cosmetic {
        all.first { $0.kind == kind && $0.code == code } ?? defaultItem(kind)
    }

    static func defaultItem(_ kind: CosmeticKind) -> Cosmetic {
        all.first { $0.kind == kind && $0.code == 0 }!
    }

    static func items(_ kind: CosmeticKind) -> [Cosmetic] { all.filter { $0.kind == kind } }

    static var defaultIDs: Set<String> { Set(all.filter(\.isDefault).map(\.id)) }

    /// Six items on sale today. Changes every day, the same for everyone.
    static func dailyOffers(on date: Date = Date()) -> [Cosmetic] {
        let day = Int(date.timeIntervalSince1970 / 86_400)
        let pool = all.filter { !$0.isDefault }
        var picks: [Cosmetic] = []
        var seed = UInt64(day) &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        while picks.count < 6 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let item = pool[Int((seed >> 33) % UInt64(pool.count))]
            if !picks.contains(item) { picks.append(item) }
        }
        return picks.sorted { $0.rarity > $1.rarity }
    }
}

/// What other players see of a profile: the equipped look and a few stats, packed into
/// a Game Center leaderboard context (64 bits).
struct ProfileLook: Hashable {
    var frame: UInt8 = 0
    var background: UInt8 = 0
    var badge: UInt8 = 0
    var title: UInt8 = 0
    var trophies: UInt16 = 0
    var seasons: UInt16 = 0

    var context: Int {
        let value = UInt64(frame) | UInt64(background) << 8 | UInt64(badge) << 16 | UInt64(title) << 24
            | UInt64(trophies) << 32 | UInt64(seasons) << 48
        return Int(bitPattern: UInt(value & 0x7FFF_FFFF_FFFF_FFFF))
    }

    init() {}

    init(context: Int) {
        let value = UInt64(UInt(bitPattern: context))
        frame = UInt8(value & 0xFF)
        background = UInt8((value >> 8) & 0xFF)
        badge = UInt8((value >> 16) & 0xFF)
        title = UInt8((value >> 24) & 0xFF)
        trophies = UInt16((value >> 32) & 0xFFFF)
        seasons = UInt16((value >> 48) & 0x7FFF)
    }

    func item(_ kind: CosmeticKind) -> Cosmetic {
        switch kind {
        case .frame: return CosmeticCatalog.item(kind: .frame, code: frame)
        case .background: return CosmeticCatalog.item(kind: .background, code: background)
        case .badge: return CosmeticCatalog.item(kind: .badge, code: badge)
        case .title: return CosmeticCatalog.item(kind: .title, code: title)
        }
    }
}
