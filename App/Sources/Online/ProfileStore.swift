import Foundation
import Observation

/// The manager's profile across careers: Kickoff Points wallet, owned and equipped
/// cosmetics and a few lifetime stats. Saved on the device; shown to other players through
/// Game Center (see `GameCenterManager`).
@MainActor
@Observable
final class ProfileStore {
    struct Saved: Codable {
        var points = 0
        var lifetimePoints = 0
        var owned: Set<String> = CosmeticCatalog.defaultIDs
        var equipped: [String: String] = [:]
        var packsOpened = 0
        var legendsPulled = 0
        var bestTrophies = 0
        var bestSeasons = 0
    }

    private(set) var data: Saved
    /// Points added by the last played week (shown in the match report).
    var lastEarned = 0

    private let key = "profile.v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(Saved.self, from: raw) {
            data = saved
        } else {
            data = Saved()
        }
        data.owned.formUnion(CosmeticCatalog.defaultIDs)
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }

    // MARK: Points

    var points: Int { data.points }
    var lifetimePoints: Int { data.lifetimePoints }

    func earn(_ amount: Int) {
        guard amount > 0 else { return }
        data.points += amount
        data.lifetimePoints += amount
        save()
        GameCenterManager.shared.submit(profile: self)
    }

    func spend(_ amount: Int) -> Bool {
        guard amount >= 0, data.points >= amount else { return false }
        data.points -= amount
        save()
        return true
    }

    // MARK: Cosmetics

    func owns(_ item: Cosmetic) -> Bool { data.owned.contains(item.id) }

    /// Adds an item. Returns false when it was already owned.
    @discardableResult
    func unlock(_ item: Cosmetic) -> Bool {
        let isNew = data.owned.insert(item.id).inserted
        save()
        if data.owned.count >= 20 { GameCenterManager.shared.unlock(.collector) }
        return isNew
    }

    func buy(_ item: Cosmetic) -> Bool {
        guard !owns(item), spend(item.rarity.price) else { return false }
        unlock(item)
        equip(item)
        return true
    }

    func equipped(_ kind: CosmeticKind) -> Cosmetic {
        data.equipped[kind.rawValue].flatMap(CosmeticCatalog.item) ?? CosmeticCatalog.defaultItem(kind)
    }

    func equip(_ item: Cosmetic) {
        guard owns(item) else { return }
        data.equipped[item.kind.rawValue] = item.id
        save()
        GameCenterManager.shared.submit(profile: self)
    }

    var ownedCount: Int { data.owned.count }

    // MARK: Stats

    func recordPack(legends: Int) {
        data.packsOpened += 1
        data.legendsPulled += legends
        save()
        GameCenterManager.shared.unlock(.firstPack)
        if legends > 0 { GameCenterManager.shared.unlock(.legendPull) }
    }

    /// Keeps the best trophy count and seasons from any career (careers can be restarted).
    func update(trophies: Int, seasons: Int) {
        guard trophies > data.bestTrophies || seasons > data.bestSeasons else { return }
        data.bestTrophies = max(data.bestTrophies, trophies)
        data.bestSeasons = max(data.bestSeasons, seasons)
        save()
    }

    var look: ProfileLook {
        var look = ProfileLook()
        look.frame = equipped(.frame).code
        look.background = equipped(.background).code
        look.badge = equipped(.badge).code
        look.title = equipped(.title).code
        look.trophies = UInt16(min(data.bestTrophies, Int(UInt16.max)))
        look.seasons = UInt16(min(data.bestSeasons, 0x7FFF))
        return look
    }
}
