import SwiftUI
import GameEngine

/// First screen: generate a world, pick a country and a club.
struct NewCareerView: View {
    @Environment(GameStore.self) private var store
    @State private var world: Career?
    @State private var countryCode = "TR"
    @State private var selectedClub: Club?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if let world {
                        countryPicker
                        clubList(world: world)
                    } else {
                        ProgressView(L("new.generating"))
                            .tint(Theme.gold)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .gameBackground()
            .task {
                if world == nil { world = await store.generateWorld() }
            }
            .sheet(item: $selectedClub) { club in
                if let world {
                    ClubConfirmSheet(club: club, world: world) {
                        store.startCareer(world: world, clubID: club.id)
                    }
                    .presentationDetents([.medium])
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: "soccerball")
                .font(.system(size: 40))
                .foregroundStyle(Theme.gold)
            Text(L("app.name"))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(L("new.subtitle"))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var countryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Career.countries) { country in
                    Button {
                        withAnimation(.snappy) { countryCode = country.code }
                    } label: {
                        HStack(spacing: 6) {
                            Text(Flags.emoji(country.code))
                            Text(country.leagueName)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .foregroundStyle(countryCode == country.code ? Theme.goldDark : Theme.textPrimary)
                        .background(countryCode == country.code ? Theme.gold : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func clubList(world: Career) -> some View {
        let league = world.leagues.first { $0.countryCode == countryCode }
        let clubs = league.map { world.clubs(in: $0) }?.sorted { $0.reputation > $1.reputation } ?? []
        return VStack(spacing: 10) {
            ForEach(clubs) { club in
                Button {
                    selectedClub = club
                } label: {
                    HStack(spacing: 12) {
                        CrestView(club: club, size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(club.name)
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                            ReputationStars(reputation: club.reputation)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Fmt.money(club.finances.transferBudget))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.goldLight)
                            Text(L("new.budget"))
                                .font(.caption2)
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .gameCard(padding: 12)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ReputationStars: View {
    let reputation: Int

    var body: some View {
        let stars = Double(reputation) / 20
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                let value = stars - Double(index)
                Image(systemName: value >= 0.75 ? "star.fill" : (value >= 0.25 ? "star.leadinghalf.filled" : "star"))
                    .font(.caption2)
                    .foregroundStyle(Theme.goldLight)
            }
        }
        .accessibilityLabel(L("a11y.reputation", String(reputation)))
    }
}

private struct ClubConfirmSheet: View {
    let club: Club
    let world: Career
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let squad = world.squad(of: club.id)
        let best = squad.sorted { $0.overall > $1.overall }.prefix(3)
        VStack(spacing: 16) {
            CrestView(club: club, size: 72)
            Text(club.name)
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.textPrimary)
            HStack(spacing: 10) {
                Chip(text: Fmt.money(club.finances.transferBudget), icon: "banknote")
                Chip(text: L("format.capacity", Fmt.number(club.stadium.capacity)), icon: "person.3.fill", color: Theme.textSecondary)
            }
            VStack(spacing: 4) {
                SectionTitle(text: L("new.keyPlayers"))
                ForEach(Array(best)) { player in
                    PlayerRow(player: player, season: world.season)
                }
            }
            Button(L("new.manage")) {
                dismiss()
                onConfirm()
            }
            .buttonStyle(GoldButtonStyle())
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }
}
