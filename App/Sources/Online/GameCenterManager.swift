import GameKit
import Observation
import SwiftUI

/// One row of the online manager ranking.
struct OnlineManager: Identifiable, Hashable {
    let id: String
    let name: String
    let rank: Int
    let points: Int
    let look: ProfileLook
    let isMe: Bool
}

/// Game Center sign-in, the world ranking (lifetime Kickoff Points) and achievements.
/// Each score carries the player's equipped cosmetics in its context, so everyone sees
/// each other's profile cards without a server of our own.
@MainActor
@Observable
final class GameCenterManager {
    static let shared = GameCenterManager()

    static let pointsLeaderboard = "kickoff.lifetime_points"

    enum Achievement: String, CaseIterable {
        case firstWin = "kickoff.first_win"
        case leagueTitle = "kickoff.league_title"
        case europeWinner = "kickoff.europe_winner"
        case bigSale = "kickoff.big_sale"
        case firstPack = "kickoff.first_pack"
        case legendPull = "kickoff.legend_pull"
        case collector = "kickoff.collector"
    }

    private(set) var isAuthenticated = false
    private(set) var playerName = ""
    private(set) var ranking: [OnlineManager] = []
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private var photos: [String: UIImage] = [:]
    private var reported = Set<String>()
    private var started = false

    func authenticate() {
        guard !started, !GameStore.isScreenshotMode else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            Task { @MainActor in
                if let viewController, let root = Self.topViewController() {
                    root.present(viewController, animated: true)
                }
                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.playerName = GKLocalPlayer.local.isAuthenticated ? GKLocalPlayer.local.displayName : ""
            }
        }
    }

    /// Opens Game Center's own sign-in / dashboard.
    func showDashboard() {
        if !isAuthenticated {
            started = false
            authenticate()
            return
        }
        GKAccessPoint.shared.trigger(state: .dashboard) {}
    }

    // MARK: Scores

    func submit(profile: ProfileStore) {
        guard isAuthenticated else { return }
        let score = min(profile.lifetimePoints, Int(Int32.max))
        let context = profile.look.context
        GKLeaderboard.submitScore(score, context: context, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.pointsLeaderboard]) { _ in }
    }

    func loadRanking() async {
        guard isAuthenticated else { return }
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let boards = try await GKLeaderboard.loadLeaderboards(IDs: [Self.pointsLeaderboard])
            guard let board = boards.first else { loadFailed = true; return }
            let (local, entries, _) = try await board.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 50))
            var rows = entries.map { entry in
                OnlineManager(id: entry.player.gamePlayerID, name: entry.player.displayName, rank: entry.rank,
                              points: entry.score, look: ProfileLook(context: entry.context),
                              isMe: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID)
            }
            if let local, !rows.contains(where: \.isMe) {
                rows.append(OnlineManager(id: local.player.gamePlayerID, name: local.player.displayName, rank: local.rank,
                                          points: local.score, look: ProfileLook(context: local.context), isMe: true))
            }
            ranking = rows
            for entry in entries.prefix(20) where photos[entry.player.gamePlayerID] == nil {
                if let image = try? await entry.player.loadPhoto(for: .small) {
                    photos[entry.player.gamePlayerID] = image
                }
            }
        } catch {
            loadFailed = true
        }
    }

    func photo(for id: String) -> UIImage? { photos[id] }

    // MARK: Achievements

    func unlock(_ achievement: Achievement) {
        guard isAuthenticated, !reported.contains(achievement.rawValue) else { return }
        reported.insert(achievement.rawValue)
        let item = GKAchievement(identifier: achievement.rawValue)
        item.percentComplete = 100
        item.showsCompletionBanner = true
        GKAchievement.report([item]) { _ in }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
