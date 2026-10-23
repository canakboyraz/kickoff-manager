import SwiftUI
import GameEngine

struct PlayerDetailView: View {
    let playerID: UUID
    @Environment(GameStore.self) private var store
    @State private var showBid = false
    @State private var showRenew = false
    @State private var notice: String?

    var body: some View {
        ScrollView {
            if let career = store.career, let player = career.player(playerID) {
                VStack(spacing: 14) {
                    header(player, career: career)
                    actions(player, career: career)
                    attributes(player)
                    details(player, career: career)
                }
                .padding(16)
                .sheet(isPresented: $showBid) {
                    NegotiationSheet(playerID: player.id) { message in notice = message }
                }
                .sheet(isPresented: $showRenew) {
                    RenewSheet(player: player) { message in notice = message }
                        .presentationDetents([.medium])
                }
            }
        }
        .gameBackground()
        .navigationTitle(store.career?.player(playerID)?.shortName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(L("common.ok")) {}
        }
    }

    private func header(_ player: Player, career: Career) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text("\(player.overall)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.tierColor(player.overall))
                Text(player.position.shortLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            PlayerAvatar(player: player, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.fullName)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("\(Flags.emoji(player.nationality)) \(Flags.countryName(player.nationality)) · \(L("format.age", String(player.age(in: career.season))))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if let report = career.scoutReport(for: player.id), player.clubID != career.userClubID {
                    Chip(text: L("scout.discountChip", String(Int((report.feeDiscount * 100).rounded()))),
                         icon: "binoculars.fill", color: Theme.positive)
                }
                if player.isFreeAgent {
                    Chip(text: L("freeAgent.badge"), icon: "figure.walk", color: Theme.positive)
                } else if player.isRetired {
                    Chip(text: L("player.retired"), icon: "moon.zzz.fill", color: Theme.textMuted)
                }
                if let clubID = player.clubID, let club = career.club(clubID) {
                    HStack(spacing: 6) {
                        CrestView(club: club, size: 18)
                        Text(club.name).font(.caption).foregroundStyle(Theme.textMuted)
                    }
                }
                HStack(spacing: 6) {
                    Chip(text: L("player.potential", String(player.potential)), icon: "arrow.up.right", color: Theme.positive)
                    if player.isInjured {
                        Chip(text: L("player.injured", String(player.injuryWeeks)), icon: "cross.case.fill", color: Theme.negative)
                    }
                    if player.isSuspended {
                        Chip(text: L("player.suspended", String(player.suspendedMatches)), icon: "rectangle.portrait.fill", color: Theme.negative)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .gameCard(highlight: Theme.tierColor(player.overall).opacity(0.7))
    }

    @ViewBuilder
    private func actions(_ player: Player, career: Career) -> some View {
        if player.clubID == career.userClubID {
            HStack(spacing: 8) {
                Button {
                    showRenew = true
                } label: {
                    Label(L("player.renew"), systemImage: "doc.text.fill")
                }
                .buttonStyle(OutlineButtonStyle())
                Button {
                    let listed = !player.isTransferListed
                    store.update { $0.setTransferListed(player.id, listed: listed) }
                    notice = listed ? L("player.listed.on", player.fullName) : L("player.listed.off", player.fullName)
                } label: {
                    Label(player.isTransferListed ? L("player.unlist") : L("player.list"),
                          systemImage: player.isTransferListed ? "tag.slash.fill" : "tag.fill")
                }
                .buttonStyle(OutlineButtonStyle(color: Theme.warning))
            }
            if career.isTransferWindowOpen {
                Button {
                    let bids = store.update { $0.offerToClubs(player.id) } ?? 0
                    notice = bids > 0 ? L("player.offered.bids", String(bids)) : L("player.offered.none")
                } label: {
                    Label(L("player.offerToClubs"), systemImage: "megaphone.fill")
                }
                .buttonStyle(OutlineButtonStyle(color: Theme.goldLight))
            }
            if player.isTransferListed {
                Text(L("player.listedHint"))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if player.isFreeAgent {
            Button {
                showBid = true
            } label: {
                Label(L("freeAgent.offerContract"), systemImage: "signature")
            }
            .buttonStyle(GoldButtonStyle())
            Text(L("freeAgent.detailHint", Fmt.wage(career.wageDemand(for: player.id))))
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if player.clubID != nil {
            let inTalks = career.negotiation(for: player.id) != nil
            Button {
                showBid = true
            } label: {
                Label(inTalks ? L("player.continueTalks") : L("player.makeBid"), systemImage: "banknote.fill")
            }
            .buttonStyle(GoldButtonStyle())
        }
    }

    private func attributes(_ player: Player) -> some View {
        let weights = Attributes.weights(for: player.position)
        let kinds = AttributeKind.allCases.filter { player.position == .goalkeeper || $0 != .goalkeeping }
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("player.attributes"))
            ForEach(kinds, id: \.self) { kind in
                let value = player.attributes[kind]
                HStack(spacing: 10) {
                    Text(kind.label)
                        .font(.subheadline.weight(weights[kind] != nil ? .semibold : .regular))
                        .foregroundStyle(weights[kind] != nil ? Theme.textPrimary : Theme.textMuted)
                        .frame(width: 110, alignment: .leading)
                    ValueBar(value: value, color: Theme.tierColor(value))
                    Text("\(value)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.tierColor(value))
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .gameCard()
    }

    private func details(_ player: Player, career: Career) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("player.details"))
            detailRow(L("player.value"), Fmt.money(player.marketValue(season: career.season)))
            detailRow(L("player.wage"), Fmt.wage(player.contract.weeklyWage))
            if !player.isFreeAgent {
                detailRow(L("player.contract"), Fmt.seasonLabel(player.contract.expiresSeason))
                if player.clubID == career.userClubID && player.contract.expiresSeason <= career.season {
                    Label(L("contracts.playerWarning"), systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                }
            }
            HStack(spacing: 10) {
                Text(L("player.fitness")).font(.subheadline).foregroundStyle(Theme.textSecondary)
                ValueBar(value: player.fitness, maxValue: 100, color: Theme.fitnessColor(player.fitness))
                Text("\(player.fitness)").font(.subheadline.weight(.bold)).foregroundStyle(Theme.fitnessColor(player.fitness))
            }
            HStack(spacing: 10) {
                Text(L("player.morale")).font(.subheadline).foregroundStyle(Theme.textSecondary)
                ValueBar(value: player.morale, maxValue: 100, color: Theme.moraleColor(player.morale))
                Text("\(player.morale)").font(.subheadline.weight(.bold)).foregroundStyle(Theme.moraleColor(player.morale))
            }
            Divider().overlay(Theme.stroke)
            detailRow(L("player.season"), L("player.seasonLine",
                                             String(player.stats.appearances),
                                             String(player.stats.goals),
                                             String(player.stats.assists),
                                             player.stats.appearances > 0 ? Fmt.rating(player.stats.averageRating) : "-"))
            detailRow(L("player.career"), L("player.careerLine", String(player.careerAppearances), String(player.careerGoals)))
            if let form = player.form {
                detailRow(L("player.form"), Fmt.rating(form))
            }
            detailRow(L("player.yellowCards"), "\(player.yellowCards)")
        }
        .gameCard()
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
        }
    }
}

struct RenewSheet: View {
    let player: Player
    let onResult: (String) -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var years = 3

    var body: some View {
        if let career = store.career {
            let wage = career.renewalWage(for: player.id)
            VStack(spacing: 16) {
                Text(player.fullName).font(.headline).foregroundStyle(Theme.textPrimary)
                Text(L("renew.current", Fmt.wage(player.contract.weeklyWage), Fmt.seasonLabel(player.contract.expiresSeason)))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(Fmt.wage(wage))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldLight)
                Stepper(L("renew.years", String(years)), value: $years, in: 1...5)
                    .foregroundStyle(Theme.textPrimary)
                Text(L("renew.wageRoom", Fmt.wage(career.userClub.finances.wageBudget - career.wageBill(of: career.userClubID))))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                Button(L("renew.submit")) {
                    let outcome = store.update { $0.renewContract(playerID: player.id, years: years) }
                    dismiss()
                    switch outcome {
                    case .renewed(_, let expires)?: onResult(L("renew.result.ok", Fmt.seasonLabel(expires)))
                    case .wageBudgetExceeded?: onResult(L("bid.result.wages"))
                    default: break
                    }
                }
                .buttonStyle(GoldButtonStyle())
            }
            .padding(20)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Theme.background)
        }
    }
}
