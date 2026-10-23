import SwiftUI
import GameEngine

struct TransfersView: View {
    @Environment(GameStore.self) private var store
    @State private var mode = Mode.market
    @State private var query = ""
    @State private var position: Position?
    @State private var maxAge = 40
    @State private var affordableOnly = true
    @State private var counterTarget: OfferTarget?
    @State private var notice: String?
    @State private var showBudget = false

    enum Mode: String, CaseIterable, Identifiable {
        case market, free, offers, listed
        var id: String { rawValue }
    }

    struct OfferTarget: Identifiable {
        let id: UUID
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
                    case .free: freeAgents(career)
                    case .offers: offers(career)
                    case .listed: listed(career)
                    }
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("tab.transfers"))
        .navigationBarTitleDisplayMode(.inline)
        .gameDestinations()
        .sheet(isPresented: $showBudget) {
            BudgetSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $counterTarget) { target in
            CounterOfferSheet(offerID: target.id) { message in notice = message }
        }
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(L("common.ok")) {}
        }
    }

    private func budgetHeader(_ career: Career) -> some View {
        let club = career.userClub
        let wageRoom = club.finances.wageBudget - career.wageBill(of: club.id)
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                StatTile(title: L("transfers.budget"), value: Fmt.money(club.finances.transferBudget))
                StatTile(title: L("transfers.wageRoom"), value: Fmt.wage(wageRoom))
            }
            HStack(spacing: 8) {
                Button {
                    showBudget = true
                } label: {
                    Label(L("budget.adjust"), systemImage: "arrow.left.arrow.right.circle.fill")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(OutlineButtonStyle(color: Theme.goldLight))
                NavigationLink(value: ScoutLink()) {
                    Label(career.scoutedPlayers.isEmpty ? L("scout.title") : L("scout.titleCount", String(career.scoutedPlayers.count)),
                          systemImage: "binoculars.fill")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(OutlineButtonStyle(color: Theme.positive))
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
                            trailing: Fmt.money(player.marketValue(season: career.season)),
                            scouted: career.scoutReport(for: player.id) != nil
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

    private func freeAgents(_ career: Career) -> some View {
        let filter = TransferFilter(position: position, maxAge: maxAge < 40 ? maxAge : nil, query: query)
        let results = career.freeAgents(filter: filter, limit: 80)
        return VStack(spacing: 10) {
            Label(L("freeAgent.listHint"), systemImage: "figure.walk")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .gameCard(padding: 10, highlight: Theme.positive.opacity(0.5))
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
            if results.isEmpty {
                Text(L("freeAgent.none"))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 30)
            }
            LazyVStack(spacing: 0) {
                ForEach(results) { player in
                    NavigationLink(value: PlayerLink(id: player.id)) {
                        PlayerRow(
                            player: player,
                            season: career.season,
                            clubName: L("freeAgent.badge"),
                            trailing: Fmt.wage(career.wageDemand(for: player.id))
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
                            Button(L("transfers.negotiate")) {
                                counterTarget = OfferTarget(id: offer.id)
                            }
                            .buttonStyle(OutlineButtonStyle(color: Theme.goldLight))
                            Button(L("transfers.accept")) {
                                store.update { $0.respond(to: offer.id, accept: true) }
                                notice = L("counter.result.sold", player.fullName, Fmt.money(offer.fee))
                            }
                            .buttonStyle(OutlineButtonStyle(color: Theme.positive))
                        }
                        Text(L("transfers.expires", String(max(0, offer.expiresWeek - career.week + 1))))
                            .font(.caption2)
                            .foregroundStyle(Theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .gameCard()
                }
            }
        }
    }

    private func listed(_ career: Career) -> some View {
        let players = career.transferListedPlayers
        return VStack(spacing: 10) {
            Text(L("transfers.listedHint"))
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            if players.isEmpty {
                Text(L("transfers.noListed"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
            }
            ForEach(players) { player in
                VStack(spacing: 8) {
                    NavigationLink(value: PlayerLink(id: player.id)) {
                        PlayerRow(player: player, season: career.season, trailing: Fmt.money(player.marketValue(season: career.season)))
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 8) {
                        Button(L("player.unlist")) {
                            store.update { $0.setTransferListed(player.id, listed: false) }
                        }
                        .buttonStyle(OutlineButtonStyle(color: Theme.warning))
                        if career.isTransferWindowOpen {
                            Button(L("player.offerToClubs")) {
                                let bids = store.update { $0.offerToClubs(player.id) } ?? 0
                                notice = bids > 0 ? L("player.offered.bids", String(bids)) : L("player.offered.none")
                            }
                            .buttonStyle(OutlineButtonStyle(color: Theme.goldLight))
                        }
                    }
                }
                .gameCard()
            }
        }
    }
}
