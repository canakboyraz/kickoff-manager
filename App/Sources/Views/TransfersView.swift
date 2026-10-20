import SwiftUI
import GameEngine

struct TransfersView: View {
    @Environment(GameStore.self) private var store
    @State private var mode = Mode.market
    @State private var query = ""
    @State private var position: Position?
    @State private var maxAge = 40
    @State private var affordableOnly = true

    enum Mode: String, CaseIterable, Identifiable {
        case market, offers
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            if let career = store.career {
                VStack(spacing: 14) {
                    budgetHeader(career)
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode == .offers && !career.pendingOffers.isEmpty
                                 ? "\(L("transfers.mode.offers")) (\(career.pendingOffers.count))"
                                 : L("transfers.mode.\(mode.rawValue)"))
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch mode {
                    case .market: market(career)
                    case .offers: offers(career)
                    }
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("tab.transfers"))
        .navigationBarTitleDisplayMode(.inline)
        .gameDestinations()
    }

    private func budgetHeader(_ career: Career) -> some View {
        let club = career.userClub
        let wageRoom = club.finances.wageBudget - career.wageBill(of: club.id)
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                StatTile(title: L("transfers.budget"), value: Fmt.money(club.finances.transferBudget))
                StatTile(title: L("transfers.wageRoom"), value: Fmt.money(wageRoom))
            }
            HStack(spacing: 6) {
                Image(systemName: career.isTransferWindowOpen ? "lock.open.fill" : "lock.fill")
                Text(career.isTransferWindowOpen ? L("transfers.windowOpen") : L("transfers.windowClosed"))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(career.isTransferWindowOpen ? Theme.positive : Theme.warning)
        }
    }

    private func market(_ career: Career) -> some View {
        let budget = min(career.userClub.finances.transferBudget, max(0, career.userClub.finances.balance))
        let filter = TransferFilter(
            position: position,
            maxPrice: affordableOnly ? max(budget, 50_000) : nil,
            maxAge: maxAge < 40 ? maxAge : nil,
            query: query
        )
        let results = career.marketPlayers(filter: filter, limit: 60)
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
                TextField(L("transfers.search"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(10)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(L("transfers.all"), selected: position == nil) { position = nil }
                    ForEach(Position.allCases, id: \.self) { item in
                        filterChip(item.shortLabel, selected: position == item) { position = item }
                    }
                }
            }

            HStack {
                Toggle(L("transfers.affordable"), isOn: $affordableOnly)
                    .toggleStyle(.button)
                    .tint(Theme.gold)
                Spacer()
                Menu {
                    ForEach([21, 23, 25, 28, 31, 40], id: \.self) { age in
                        Button(age == 40 ? L("transfers.anyAge") : L("transfers.maxAge", String(age))) { maxAge = age }
                    }
                } label: {
                    Label(maxAge == 40 ? L("transfers.anyAge") : L("transfers.maxAge", String(maxAge)), systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                }
            }
            .font(.caption)

            if results.isEmpty {
                Text(L("transfers.noResults"))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 30)
            }
            LazyVStack(spacing: 0) {
                ForEach(results) { player in
                    NavigationLink(value: PlayerLink(id: player.id)) {
                        PlayerRow(
                            player: player,
                            season: career.season,
                            clubName: player.clubID.flatMap { career.club($0)?.shortName },
                            trailing: Fmt.money(player.marketValue(season: career.season))
                        )
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(Theme.stroke)
                }
            }
            .padding(.horizontal, 12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Theme.goldDark : Theme.textPrimary)
                .background(selected ? Theme.gold : Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func offers(_ career: Career) -> some View {
        VStack(spacing: 10) {
            if career.pendingOffers.isEmpty {
                Text(L("transfers.noOffers"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 30)
            }
            ForEach(career.pendingOffers) { offer in
                if let player = career.player(offer.playerID), let buyer = career.club(offer.fromClubID) {
                    VStack(spacing: 10) {
                        NavigationLink(value: PlayerLink(id: player.id)) {
                            PlayerRow(player: player, season: career.season, trailing: Fmt.money(player.marketValue(season: career.season)))
                        }
                        .buttonStyle(.plain)
                        HStack(spacing: 8) {
                            CrestView(club: buyer, size: 24)
                            Text(L("transfers.offerLine", buyer.name, Fmt.money(offer.fee)))
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            Button(L("transfers.reject")) {
                                store.update { $0.respond(to: offer.id, accept: false) }
                            }
                            .buttonStyle(OutlineButtonStyle(color: Theme.negative))
                            Button(L("transfers.accept")) {
                                store.update { $0.respond(to: offer.id, accept: true) }
                            }
                            .buttonStyle(OutlineButtonStyle(color: Theme.positive))
                        }
                    }
                    .gameCard()
                }
            }
        }
    }
}
