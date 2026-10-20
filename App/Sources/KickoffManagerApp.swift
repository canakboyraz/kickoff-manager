import SwiftUI
import UIKit

@main
struct KickoffManagerApp: App {
    @State private var store = GameStore()

    init() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(Theme.backgroundDeep)
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let navBar = UINavigationBarAppearance()
        navBar.configureWithTransparentBackground()
        navBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        navBar.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navBar
        UINavigationBar.appearance().scrollEdgeAppearance = navBar
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        Group {
            if store.career != nil {
                MainTabView()
            } else {
                NewCareerView()
            }
        }
        .animation(.easeInOut, value: store.career == nil)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label(L("tab.home"), systemImage: "house.fill") }
            NavigationStack { SquadView() }
                .tabItem { Label(L("tab.squad"), systemImage: "tshirt.fill") }
            NavigationStack { TransfersView() }
                .tabItem { Label(L("tab.transfers"), systemImage: "arrow.left.arrow.right") }
            NavigationStack { ClubView() }
                .tabItem { Label(L("tab.club"), systemImage: "building.columns.fill") }
            NavigationStack { LeagueView() }
                .tabItem { Label(L("tab.league"), systemImage: "list.number") }
        }
    }
}

/// Navigation values shared by every tab.
struct PlayerLink: Hashable { let id: UUID }
struct MatchLink: Hashable { let fixtureID: UUID }
struct InboxLink: Hashable {}

extension View {
    func gameDestinations() -> some View {
        navigationDestination(for: PlayerLink.self) { PlayerDetailView(playerID: $0.id) }
            .navigationDestination(for: MatchLink.self) { MatchReportView(fixtureID: $0.fixtureID) }
            .navigationDestination(for: InboxLink.self) { _ in InboxView() }
    }
}
