import SwiftUI
import GameEngine

/// Contracts that run out soon, so nobody leaves on a free by surprise.
struct ContractsView: View {
    @Environment(GameStore.self) private var store
    @State private var renewing: Player?
    @State private var notice: String?

    var body: some View {
        ScrollView {
            if let career = store.career {
                VStack(spacing: 14) {
                    Label(L("contracts.hint", String(career.weeksUntilContractsExpire)), systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .gameCard(padding: 10)
                    section(L("contracts.thisSeason"), players: career.expiringContracts, career: career, urgent: true)
                    section(L("contracts.nextSeason"), players: career.contractsEndingNextSeason, career: career, urgent: false)
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("contracts.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $renewing) { player in
            RenewSheet(player: player) { message in notice = message }
                .presentationDetents([.medium])
        }
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(L("common.ok")) {}
        }
    }

    @ViewBuilder
    private func section(_ title: String, players: [Player], career: Career, urgent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "\(title) (\(players.count))")
            if players.isEmpty {
                Text(L("contracts.none"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gameCard()
            }
            ForEach(players) { player in
                VStack(spacing: 8) {
                    NavigationLink(value: PlayerLink(id: player.id)) {
                        PlayerRow(player: player, season: career.season,
                                  clubName: Fmt.wage(player.contract.weeklyWage),
                                  trailing: Fmt.seasonLabel(player.contract.expiresSeason))
                    }
                    .buttonStyle(.plain)
                    HStack {
                        Text(L("contracts.newWage", Fmt.wage(career.renewalWage(for: player.id))))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button(L("player.renew")) { renewing = player }
                            .buttonStyle(OutlineButtonStyle(color: urgent ? Theme.warning : Theme.goldLight))
                            .frame(width: 130)
                    }
                }
                .gameCard(highlight: urgent ? Theme.warning.opacity(0.5) : nil)
            }
        }
    }
}
