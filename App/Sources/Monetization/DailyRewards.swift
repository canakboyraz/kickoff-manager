import Foundation

/// Cooldowns for the free bonuses. Stored on the device.
enum DailyRewards {
    /// Rewarded ad: once an hour.
    static let adReward = 2_000_000
    static let adCooldown: TimeInterval = 60 * 60
    /// Penalty challenge: once a day, paid only for a goal.
    static let penaltyReward = 5_000_000

    private static let adKey = "lastRewardedAd"
    private static let penaltyKey = "lastPenaltyDay"

    // MARK: Rewarded ad

    static func adAvailable(now: Date = Date()) -> Bool {
        adWaitSeconds(now: now) <= 0
    }

    /// Seconds until the next rewarded ad can be watched (0 when ready).
    static func adWaitSeconds(now: Date = Date()) -> TimeInterval {
        let last = UserDefaults.standard.double(forKey: adKey)
        guard last > 0 else { return 0 }
        return max(0, last + adCooldown - now.timeIntervalSince1970)
    }

    static func markAdWatched(now: Date = Date()) {
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: adKey)
    }

    // MARK: Penalty

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    static func penaltyAvailable(now: Date = Date()) -> Bool {
        UserDefaults.standard.string(forKey: penaltyKey) != dayKey(now)
    }

    static func markPenaltyTaken(now: Date = Date()) {
        UserDefaults.standard.set(dayKey(now), forKey: penaltyKey)
    }
}
