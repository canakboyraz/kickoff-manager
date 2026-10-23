import SwiftUI
import GameEngine

struct ClubView: View {
    @Environment(GameStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @State private var notice: String?
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            if let career = store.career {
                VStack(spacing: 14) {
                    stadiumCard(career)
                    SectionTitle(text: L("club.facilities"))
                    ForEach([FacilityKind.training, .youth, .medical, .stadium], id: \.self) { kind in
                        FacilityRow(quote: career.upgradeQuote(kind), balance: career.userClub.finances.balance) {
                            let outcome = store.update { $0.startUpgrade(kind) }
                            switch outcome {
                            case .started?: notice = L("club.upgrade.started", kind.label)
                            case .insufficientFunds?: notice = L("club.upgrade.funds")
                            case .alreadyInProgress?: notice = L("club.upgrade.inProgress")
                            case .maxLevel?: notice = L("club.upgrade.max")
                            case nil: break
                            }
                        }
                    }
                    financesCard(career)
                    historyCard(career)
                    storeCard()
                    Button(L("club.newCareer"), role: .destructive) { confirmReset = true }
                        .buttonStyle(OutlineButtonStyle(color: Theme.negative))
                        .padding(.top, 10)
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("tab.club"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(L("common.ok")) {}
        }
        .confirmationDialog(L("club.newCareer.confirm"), isPresented: $confirmReset, titleVisibility: .visible) {
            Button(L("club.newCareer"), role: .destructive) { store.abandonCareer() }
        }
    }

    /// One-time purchase that switches the ads off for good.
    private func storeCard() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("store.title"))
            if purchases.adsRemoved {
                Label(L("store.owned"), systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.positive)
            } else {
                Text(L("store.pitch", String(AdConfig.weeksPerAd)))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button {
                    Task { await purchases.buyRemoveAds() }
                } label: {
                    Label(purchases.product.map { L("store.buyWithPrice", $0.displayPrice) } ?? L("store.buy"),
                          systemImage: "nosign")
                }
                .buttonStyle(GoldButtonStyle())
                .disabled(purchases.isWorking)
            }
            Button(L("store.restore")) {
                Task { await purchases.restore() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textMuted)
            .disabled(purchases.isWorking)
        }
        .gameCard()
        .alert(purchases.message ?? "", isPresented: Binding(
            get: { purchases.message != nil },
            set: { if !$0 { purchases.message = nil } }
        )) {
            Button(L("common.ok")) {}
        }
    }

    private func stadiumCard(_ career: Career) -> some View {
        let club = career.userClub
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CrestView(club: club, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(club.stadium.name)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(L("format.capacity", Fmt.number(club.stadium.capacity)))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                ReputationStars(reputation: club.reputation)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("club.ticketPrice"))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    Text(L("club.fairPrice", Fmt.money(career.userFairTicketPrice)))
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                Stepper(
                    Fmt.money(club.stadium.ticketPrice),
                    onIncrement: { store.update { $0.setTicketPrice(club.stadium.ticketPrice + 1) } },
                    onDecrement: { store.update { $0.setTicketPrice(club.stadium.ticketPrice - 1) } }
                )
                .fixedSize()
                .foregroundStyle(Theme.goldLight)
            }
        }
        .gameCard()
    }

    private func financesCard(_ career: Career) -> some View {
        let finances = career.userClub.finances
        let wages = career.wageBill(of: career.userClubID)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("club.finances"))
            row(L("club.balance"), Fmt.money(finances.balance), color: finances.balance < 0 ? Theme.negative : Theme.goldLight)
            row(L("transfers.budget"), Fmt.money(finances.transferBudget))
            row(L("club.wages"), "\(Fmt.wage(wages)) / \(Fmt.wage(finances.wageBudget))", color: wages > finances.wageBudget ? Theme.negative : Theme.textPrimary)
            row(L("club.commercial"), Fmt.wage(career.userClub.weeklyCommercialIncome))
            Divider().overlay(Theme.stroke)
            row(L("club.seasonIncome"), Fmt.money(finances.seasonIncome), color: Theme.positive)
            row(L("club.seasonExpenses"), Fmt.money(finances.seasonExpenses), color: Theme.negative)
            if finances.seasonEuropeIncome > 0 {
                row(L("club.europeIncome"), Fmt.money(finances.seasonEuropeIncome), color: Theme.elite)
            }
        }
        .gameCard()
    }

    @ViewBuilder
    private func historyCard(_ career: Career) -> some View {
        if !career.history.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: L("club.history"))
                ForEach(career.history.reversed(), id: \.season) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        row(Fmt.seasonLabel(entry.season), L("club.historyLine", String(entry.position), String(entry.points)))
                        if let kind = entry.europe, let stage = entry.europeStage {
                            Text("\(kind.label): \(stage.label)")
                                .font(.caption)
                                .foregroundStyle(kind.color)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            .gameCard()
        }
    }

    private func row(_ title: String, _ value: String, color: Color = Theme.textPrimary) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
    }
}

struct FacilityRow: View {
    let quote: UpgradeQuote
    let balance: Int
    let onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: quote.kind.icon)
                    .font(.title3)
                    .foregroundStyle(Theme.goldLight)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(quote.kind.label)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(quote.kind.detail)
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                if quote.kind == .stadium {
                    Text(Fmt.number(quote.currentValue))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if quote.kind != .stadium {
                HStack(spacing: 3) {
                    ForEach(1...Facilities.maxLevel, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level <= quote.currentValue ? Theme.gold : Theme.backgroundDeep)
                            .frame(height: 6)
                    }
                }
            }
            if let progress = quote.inProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(progress.totalWeeks - progress.weeksRemaining), total: Double(progress.totalWeeks))
                        .tint(Theme.positive)
                    Text(L("club.upgrade.weeksLeft", String(progress.weeksRemaining)))
                        .font(.caption2)
                        .foregroundStyle(Theme.positive)
                }
            } else if quote.isMaxed {
                Text(L("club.upgrade.max"))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            } else {
                Button(action: onUpgrade) {
                    HStack {
                        Text(quote.kind == .stadium
                             ? L("club.upgrade.stadium", Fmt.number(quote.nextValue))
                             : L("club.upgrade.level", String(quote.nextValue)))
                        Spacer()
                        Text("\(Fmt.money(quote.cost)) · \(L("club.upgrade.weeks", String(quote.weeks)))")
                    }
                    .padding(.horizontal, 12)
                }
                .buttonStyle(OutlineButtonStyle(color: balance >= quote.cost ? Theme.goldLight : Theme.textMuted))
            }
        }
        .gameCard()
    }
}
