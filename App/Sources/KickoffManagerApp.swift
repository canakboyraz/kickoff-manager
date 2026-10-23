import SwiftUI
import UIKit

@main
struct KickoffManagerApp: App {
    @State private var store = GameStore()
    @State private var purchases = PurchaseManager()

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
                .environment(purchases)
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        Group {
            if let career = store.career {
                if career.isUnemployed {
                    SackedView()
                } else {
                    MainTabView()
                }
            } else {
                NewCareerView()
            }
        }
        .animation(.easeInOut, value: store.career == nil)
        .animation(.easeInOut, value: store.career?.isUnemployed ?? false)
    }
}

struct MainTabView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let needsChanges = store.career?.needsLineupChanges ?? false
        let expiring = store.career?.expiringContracts.count ?? 0
        TabView(selection: Binding(get: { store.selectedTab }, set: { store.selectedTab = $0 })) {
            NavigationStack { HomeView() }
                .tabItem { Label(L("tab.home"), systemImage: "house.fill") }
                .tag(AppTab.home)
            NavigationStack { SquadView() }
                .tabItem { Label(L("tab.squad"), systemImage: "tshirt.fill") }
                .badge(needsChanges ? Text("!") : (expiring > 0 ? Text("\(expiring)") : nil))
                .tag(AppTab.squad)
            NavigationStack { TransfersView() }
                .tabItem { Label(L("tab.transfers"), systemImage: "arrow.left.arrow.right") }
                .badge(store.career?.pendingOffers.count ?? 0)
                .tag(AppTab.transfers)
            NavigationStack { ClubView() }
                .tabItem { Label(L("tab.club"), systemImage: "building.columns.fill") }
                .tag(AppTab.club)
            NavigationStack { LeagueView() }
                .tabItem { Label(L("tab.league"), systemImage: "list.number") }
                .tag(AppTab.league)
        }
        .task {
            // The tracking prompt only appears while the app is active, so wait a moment.
            try? await Task.sleep(for: .seconds(1.5))
            AdManager.shared.start()
        }
    }
}

/// Navigation values shared by every tab.
struct PlayerLink: Hashable { let id: UUID }
struct MatchLink: Hashable { let fixtureID: UUID }
struct InboxLink: Hashable {}
struct ContractsLink: Hashable {}

extension View {
    func gameDestinations() -> some View {
        navigationDestination(for: PlayerLink.self) { PlayerDetailView(playerID: $0.id) }
            .navigationDestination(for: MatchLink.self) { MatchReportView(fixtureID: $0.fixtureID) }
            .navigationDestination(for: InboxLink.self) { _ in InboxView() }
            .navigationDestination(for: ContractsLink.self) { _ in ContractsView() }
    }
}
