import Foundation
import Observation
import GameEngine

/// Owns the current career, runs the simulation off the main thread and saves after every change.
@MainActor
@Observable
final class GameStore {
    private(set) var career: Career?
    private(set) var isSimulating = false
    /// True when an old save from an earlier version couldn't be loaded.
    private(set) var didResetSave = false
    /// Set after a week is played so the UI can show the match report.
    var presentedReport: PresentedReport?
    /// Selected tab, so screens can send the user somewhere (e.g. to fix the team sheet).
    var selectedTab: AppTab = .home
    /// Kickoff Points wallet and cosmetics (shared by every career).
    let profile = ProfileStore()
    private var seenRewardIDs = Set<UUID>()
    /// Which part of the profile tab is showing (lets Home jump straight to the store).
    var profileSection: ProfileSection = .profile

    private let saveURL: URL = {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("career.json")
    }()

    init() {
        load()
        if Self.isScreenshotMode { setUpScreenshotCareer() }
        seenRewardIDs = Set(career?.rewardLog.map(\.id) ?? [])
    }

    // MARK: - App Store screenshots

    /// Launched with `-demoCareer` by the screenshot workflow: a fixed career a few weeks in.
    nonisolated static let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("-demoCareer")

    /// Value after a launch argument, e.g. `-screenshotTab squad`.
    nonisolated static func launchValue(_ key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: key), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    private func setUpScreenshotCareer() {
        var world = Career.generate(seed: 2026)
        world.chooseClub(world.leagues[0].clubIDs[0])
        _ = world.startScoutMission(ScoutBrief(maxAge: 23, minPotential: 75))
        for _ in 0..<9 { world.advanceWeek() }
        career = world
        if let tab = Self.launchValue("-screenshotTab").flatMap(AppTab.init(rawValue:)) {
            selectedTab = tab
        }
        if let section = Self.launchValue("-profileSection").flatMap(ProfileSection.init(rawValue:)) {
            profileSection = section
        }
        // Something to show off in the store and profile screenshots.
        profile.earn(12_500)
        for id in ["frame.champion", "bg.stadium", "badge.crown", "title.tactician", "frame.gold", "badge.flame"] {
            if let item = CosmeticCatalog.item(id) { profile.unlock(item); profile.equip(item) }
        }
    }

    // MARK: - Lifecycle

    func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        if let decoded = try? JSONDecoder().decode(Career.self, from: data),
           decoded.version == Career.currentVersion {
            career = decoded
        } else {
            // Saves from older versions use a different format; start fresh.
            didResetSave = true
            try? FileManager.default.removeItem(at: saveURL)
        }
    }

    func save() {
        guard let career else { return }
        let url = saveURL
        Task.detached(priority: .utility) {
            do {
                let data = try JSONEncoder().encode(career)
                try data.write(to: url, options: .atomic)
            } catch {
                print("Save failed: \(error)")
            }
        }
    }

    /// Builds a new world off the main thread (a few thousand players).
    func generateWorld() async -> Career {
        await Task.detached(priority: .userInitiated) {
            Career.generate(seed: UInt64.random(in: 1...UInt64.max))
        }.value
    }

    func startCareer(world: Career, clubID: UUID) {
        var newCareer = world
        newCareer.chooseClub(clubID)
        career = newCareer
        save()
    }

    func abandonCareer() {
        career = nil
        presentedReport = nil
        try? FileManager.default.removeItem(at: saveURL)
    }

    // MARK: - Simulation

    func playWeek() async {
        // Unavailable starters must be replaced by the manager before kick-off.
        guard let snapshot = career, !isSimulating, !snapshot.needsLineupChanges else { return }
        isSimulating = true
        let (updated, report) = await Task.detached(priority: .userInitiated) { () -> (Career, WeekReport) in
            var working = snapshot
            let report = working.advanceWeek()
            return (working, report)
        }.value
        career = updated
        isSimulating = false
        profile.lastEarned = collectRewards()
        presentedReport = PresentedReport(report: report)
        AdManager.shared.recordPlayedWeek()
        save()
    }

    /// Moves points the career earned into the profile wallet and unlocks matching achievements.
    @discardableResult
    private func collectRewards() -> Int {
        guard var working = career else { return 0 }
        let points = working.claimRewardPoints()
        let fresh = working.rewardLog.filter { !seenRewardIDs.contains($0.id) }
        seenRewardIDs.formUnion(fresh.map(\.id))
        career = working
        profile.earn(points)
        profile.update(trophies: working.manager.trophies, seasons: working.manager.seasonsManaged)
        let center = GameCenterManager.shared
        for event in fresh {
            switch event.reason {
            case .matchWin: center.unlock(.firstWin)
            case .leagueTitle: center.unlock(.leagueTitle)
            case .cupWin: center.unlock(.europeWinner)
            case .playerSale where event.points >= 200: center.unlock(.bigSale)
            default: break
            }
        }
        return points
    }

    /// Applies a change to the career and saves it. Returns whatever the change returns.
    @discardableResult
    func update<T>(_ change: (inout Career) -> T) -> T? {
        guard var working = career else { return nil }
        let result = change(&working)
        career = working
        _ = collectRewards()
        save()
        return result
    }
}

/// Wraps a week report with a stable identity so it can drive `.sheet(item:)`.
struct PresentedReport: Identifiable {
    let id = UUID()
    let report: WeekReport
}

enum ProfileSection: String, CaseIterable, Hashable {
    case profile, store, ranking
}

enum AppTab: String, Hashable {
    case home, squad, transfers, league, profile
}
