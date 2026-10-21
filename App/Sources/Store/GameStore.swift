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

    private let saveURL: URL = {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("career.json")
    }()

    init() {
        load()
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
        presentedReport = PresentedReport(report: report)
        save()
    }

    /// Applies a change to the career and saves it. Returns whatever the change returns.
    @discardableResult
    func update<T>(_ change: (inout Career) -> T) -> T? {
        guard var working = career else { return nil }
        let result = change(&working)
        career = working
        save()
        return result
    }
}

/// Wraps a week report with a stable identity so it can drive `.sheet(item:)`.
struct PresentedReport: Identifiable {
    let id = UUID()
    let report: WeekReport
}

enum AppTab: Hashable {
    case home, squad, transfers, club, league
}
