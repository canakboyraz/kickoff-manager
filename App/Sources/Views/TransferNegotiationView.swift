import SwiftUI
import GameEngine

struct Feedback: Equatable {
    enum Tone { case good, neutral, bad }

    var tone: Tone
    var text: String

    var color: Color {
        switch tone {
        case .good: return Theme.positive
        case .neutral: return Theme.goldLight
        case .bad: return Theme.negative
        }
    }

    var icon: String {
        switch tone {
        case .good: return "checkmark.circle.fill"
        case .neutral: return "bubble.left.and.bubble.right.fill"
        case .bad: return "xmark.octagon.fill"
        }
    }
}

struct FeedbackBanner: View {
    let feedback: Feedback

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: feedback.icon).foregroundStyle(feedback.color)
            Text(feedback.text)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .gameCard(padding: 12, highlight: feedback.color.opacity(0.6))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct PatienceDots: View {
    let value: Int
    var maxValue = 3

    var body: some View {
        HStack(spacing: 4) {
            Text(L("talks.patience"))
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
            Spacer()
            ForEach(0..<maxValue, id: \.self) { index in
                Circle()
                    .fill(index < value ? Theme.gold : Theme.backgroundDeep)
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("talks.patience"))
        .accessibilityValue("\(value)/\(maxValue)")
    }
}

struct StepBadge: View {
    enum Phase { case active, done, upcoming }

    let number: Int
    let title: String
    let phase: Phase

    private var fill: Color {
        switch phase {
        case .active: return Theme.gold
        case .done: return Theme.positive
        case .upcoming: return Theme.surface
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(fill).frame(width: 22, height: 22)
                if phase == .done {
                    Image(systemName: "checkmark").font(.caption2.weight(.heavy))
                } else {
                    Text("\(number)").font(.caption.weight(.heavy))
                }
            }
            .foregroundStyle(phase == .upcoming ? Theme.textMuted : Theme.goldDark)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(phase == .upcoming ? Theme.textMuted : Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Two-step transfer talks: agree a fee with the club, then personal terms with the player.
struct NegotiationSheet: View {
    let playerID: UUID
    let onFinish: (String) -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var fee: Double = 0
    @State private var wage: Double = 0
    @State private var years = 3
    @State private var feedback: Feedback?
    @State private var prepared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let career = store.career, let player = career.player(playerID) {
                    content(career, player: player)
                        .padding(20)
                }
            }
            .gameBackground()
            .navigationTitle(L("talks.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
        .onAppear(perform: prepare)
    }

    private func prepare() {
        guard !prepared, let career = store.career else { return }
        prepared = true
        let talk = career.negotiation(for: playerID)
        let asking = career.askingPrice(for: playerID)
        // Start a little below the asking price so there's room to negotiate.
        let opening = Double((asking * 4 / 5) / 50_000 * 50_000)
        fee = Double(talk?.lastCounter ?? Int(max(opening, 50_000)))
        wage = Double(talk?.lastWageCounter ?? career.wageDemand(for: playerID))
    }

    @ViewBuilder
    private func content(_ career: Career, player: Player) -> some View {
        let talk = career.negotiation(for: playerID)
        VStack(spacing: 16) {
            header(player, career: career)
            if let feedback {
                FeedbackBanner(feedback: feedback)
            }
            if !career.isInterestedInJoining(playerID) && talk?.isClosed != true {
                FeedbackBanner(feedback: Feedback(tone: .bad, text: L("talks.notInterestedHint")))
            }
            if talk?.isClosed == true {
                Text(L("talks.closed"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            } else if let agreed = talk?.agreedFee {
                contractStage(career, player: player, fee: agreed, talk: talk)
            } else if player.isFreeAgent {
                // Free agents: no fee, straight to personal terms.
                contractStage(career, player: player, fee: 0, talk: talk)
            } else {
                feeStage(career, player: player, talk: talk)
            }
        }
    }

    private func header(_ player: Player, career: Career) -> some View {
        HStack(spacing: 12) {
            PlayerAvatar(player: player, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(player.fullName)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(player.position.longLabel) · \(L("format.age", String(player.age(in: career.season))))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if let clubID = player.clubID, let club = career.club(clubID) {
                    HStack(spacing: 6) {
                        CrestView(club: club, size: 16)
                        Text(club.name).font(.caption).foregroundStyle(Theme.textMuted)
                    }
                } else if player.isFreeAgent {
                    Chip(text: L("freeAgent.badge"), icon: "figure.walk", color: Theme.positive)
                }
            }
            Spacer()
            Text("\(player.overall)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.tierColor(player.overall))
        }
        .gameCard()
    }

    // MARK: Step 1 – fee

    private func feeStage(_ career: Career, player: Player, talk: TransferTalks?) -> some View {
        let asking = career.askingPrice(for: playerID)
        let funds = career.availableTransferFunds
        let upper = Double(max(asking * 3 / 2, 100_000))
        return VStack(spacing: 14) {
            HStack {
                StepBadge(number: 1, title: L("talks.step.fee"), phase: .active)
                StepBadge(number: 2, title: L("talks.step.contract"), phase: .upcoming)
            }
            VStack(spacing: 8) {
                InfoRow(title: L("talks.value"), value: Fmt.money(player.marketValue(season: career.season)))
                InfoRow(title: L("talks.asking"), value: Fmt.money(asking))
                if let counter = talk?.lastCounter {
                    InfoRow(title: L("talks.lastCounter"), value: Fmt.money(counter), color: Theme.goldLight)
                }
                InfoRow(title: L("talks.funds"), value: Fmt.money(funds), color: funds < Int(fee) ? Theme.negative : Theme.textPrimary)
                PatienceDots(value: talk?.patience ?? Career.talkPatience, maxValue: Career.talkPatience)
            }
            .gameCard()
            VStack(spacing: 6) {
                Text(Fmt.money(Int(fee)))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Int(fee) > funds ? Theme.negative : Theme.goldLight)
                    .contentTransition(.numericText())
                Slider(value: $fee, in: 0...upper, step: 50_000)
                    .tint(Theme.gold)
            }
            if !career.isTransferWindowOpen {
                Text(L("bid.windowClosed"))
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
            Button(L("talks.sendFee")) { submitFee(Int(fee)) }
                .buttonStyle(GoldButtonStyle())
            if let counter = talk?.lastCounter {
                Button(L("talks.acceptCounter", Fmt.money(counter))) {
                    fee = Double(counter)
                    submitFee(counter)
                }
                .buttonStyle(OutlineButtonStyle(color: Theme.goldLight))
            }
        }
    }

    private func submitFee(_ amount: Int) {
        guard let response = store.update({ $0.negotiateFee(playerID: playerID, fee: amount) }) else { return }
        withAnimation(.snappy) {
            switch response {
            case .agreed(let agreed):
                feedback = Feedback(tone: .good, text: L("talks.feeAgreed", Fmt.money(agreed)))
                if let career = store.career { wage = Double(career.wageDemand(for: playerID)) }
            case .counter(let counter, let insulted):
                feedback = Feedback(tone: insulted ? .bad : .neutral,
                                    text: L(insulted ? "talks.insulted" : "talks.counter", Fmt.money(counter)))
            case .walkedAway:
                feedback = Feedback(tone: .bad, text: L("talks.walkedAway"))
            case .windowClosed:
                feedback = Feedback(tone: .bad, text: L("bid.result.windowClosed"))
            case .insufficientBudget:
                feedback = Feedback(tone: .bad, text: L("bid.result.budget"))
            case .squadFull:
                feedback = Feedback(tone: .bad, text: L("bid.result.squadFull"))
            case .unavailable:
                feedback = Feedback(tone: .bad, text: L("bid.result.unavailable"))
            }
        }
    }

    // MARK: Step 2 – personal terms

    private func contractStage(_ career: Career, player: Player, fee: Int, talk: TransferTalks?) -> some View {
        let demand = career.wageDemand(for: playerID)
        let room = career.userClub.finances.wageBudget - career.wageBill(of: career.userClubID)
        let lower = Double(max(500, demand / 2 / 500 * 500))
        let upper = Double(max(demand * 2, 2_000))
        return VStack(spacing: 14) {
            if player.isFreeAgent {
                FeedbackBanner(feedback: Feedback(tone: .neutral, text: L("freeAgent.talksHint")))
            } else {
                HStack {
                    StepBadge(number: 1, title: L("talks.step.fee"), phase: .done)
                    StepBadge(number: 2, title: L("talks.step.contract"), phase: .active)
                }
            }
            VStack(spacing: 8) {
                InfoRow(title: L("talks.agreedFee"), value: player.isFreeAgent ? L("freeAgent.noFee") : Fmt.money(fee), color: Theme.positive)
                InfoRow(title: L("talks.currentWage"), value: Fmt.wage(player.contract.weeklyWage))
                if let counter = talk?.lastWageCounter {
                    InfoRow(title: L("talks.wageCounter"), value: Fmt.wage(counter), color: Theme.goldLight)
                }
                InfoRow(title: L("transfers.wageRoom"), value: Fmt.wage(room), color: room < Int(wage) ? Theme.negative : Theme.textPrimary)
                PatienceDots(value: talk?.contractPatience ?? Career.contractTalkPatience, maxValue: Career.contractTalkPatience)
            }
            .gameCard()
            VStack(spacing: 6) {
                Text(Fmt.wage(Int(wage)))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Int(wage) > room ? Theme.negative : Theme.goldLight)
                    .contentTransition(.numericText())
                Slider(value: $wage, in: lower...upper, step: 500)
                    .tint(Theme.gold)
            }
            Stepper(L("renew.years", String(years)), value: $years, in: 1...5)
                .foregroundStyle(Theme.textPrimary)
            Button(L("talks.sendContract")) { submitContract(Int(wage)) }
                .buttonStyle(GoldButtonStyle())
            if let counter = talk?.lastWageCounter {
                Button(L("talks.acceptWage", Fmt.wage(counter))) {
                    wage = Double(counter)
                    submitContract(counter)
                }
                .buttonStyle(OutlineButtonStyle(color: Theme.goldLight))
            }
        }
    }

    private func submitContract(_ amount: Int) {
        let name = store.career?.player(playerID)?.fullName ?? ""
        guard let response = store.update({ $0.offerContract(playerID: playerID, weeklyWage: amount, years: years) }) else { return }
        withAnimation(.snappy) {
            switch response {
            case .signed(let paid, _, _):
                dismiss()
                onFinish(paid == 0 ? L("talks.signedFree", name) : L("talks.signed", name, Fmt.money(paid)))
            case .counter(let demanded):
                feedback = Feedback(tone: .neutral, text: L("talks.wageCounterText", Fmt.wage(demanded)))
            case .walkedAway:
                feedback = Feedback(tone: .bad, text: L("talks.playerWalkedAway"))
            case .notInterested:
                feedback = Feedback(tone: .bad, text: L("talks.notInterested"))
            case .wageBudgetExceeded:
                feedback = Feedback(tone: .bad, text: L("bid.result.wages"))
            case .insufficientBudget:
                feedback = Feedback(tone: .bad, text: L("bid.result.budget"))
            case .noFeeAgreed:
                feedback = Feedback(tone: .bad, text: L("talks.noFee"))
            case .windowClosed:
                feedback = Feedback(tone: .bad, text: L("bid.result.windowClosed"))
            case .squadFull:
                feedback = Feedback(tone: .bad, text: L("bid.result.squadFull"))
            }
        }
    }
}

/// Answer a bid for one of the user's players by asking for more.
struct CounterOfferSheet: View {
    let offerID: UUID
    let onFinish: (String) -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var fee: Double = 0
    @State private var feedback: Feedback?
    @State private var prepared = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let career = store.career, let offer = career.offer(offerID),
                   let player = career.player(offer.playerID), let buyer = career.club(offer.fromClubID) {
                    content(career, offer: offer, player: player, buyer: buyer)
                        .padding(20)
                }
            }
            .gameBackground()
            .navigationTitle(L("counter.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
        .onAppear {
            guard !prepared, let offer = store.career?.offer(offerID) else { return }
            prepared = true
            fee = Double(offer.fee * 5 / 4 / 50_000 * 50_000)
        }
    }

    private func content(_ career: Career, offer: IncomingOffer, player: Player, buyer: Club) -> some View {
        let upper = Double(max(offer.fee * 3, offer.fee + 1_000_000))
        return VStack(spacing: 16) {
            HStack(spacing: 12) {
                PlayerAvatar(player: player, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.fullName).font(.headline).foregroundStyle(Theme.textPrimary)
                    Text(L("counter.subtitle", buyer.name)).font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                CrestView(club: buyer, size: 36)
            }
            .gameCard()
            if let feedback {
                FeedbackBanner(feedback: feedback)
            }
            VStack(spacing: 8) {
                InfoRow(title: L("talks.value"), value: Fmt.money(player.marketValue(season: career.season)))
                InfoRow(title: L("counter.current"), value: Fmt.money(offer.fee), color: Theme.goldLight)
            }
            .gameCard()
            if offer.status == .pending {
                VStack(spacing: 6) {
                    Text(Fmt.money(Int(fee)))
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.goldLight)
                        .contentTransition(.numericText())
                    Slider(value: $fee, in: Double(offer.fee)...upper, step: 50_000)
                        .tint(Theme.gold)
                }
                Button(L("counter.send")) { submit(Int(fee)) }
                    .buttonStyle(GoldButtonStyle())
                Button(L("counter.acceptCurrent", Fmt.money(offer.fee))) {
                    store.update { $0.respond(to: offerID, accept: true) }
                    dismiss()
                    onFinish(L("counter.result.sold", player.fullName, Fmt.money(offer.fee)))
                }
                .buttonStyle(OutlineButtonStyle(color: Theme.positive))
            }
        }
    }

    private func submit(_ amount: Int) {
        let name = store.career?.offer(offerID).flatMap { store.career?.player($0.playerID)?.fullName } ?? ""
        guard let response = store.update({ $0.counterOffer(offerID, fee: amount) }) else { return }
        withAnimation(.snappy) {
            switch response {
            case .accepted(let paid):
                dismiss()
                onFinish(L("counter.result.sold", name, Fmt.money(paid)))
            case .raised(let newFee):
                feedback = Feedback(tone: .neutral, text: L("counter.result.raised", Fmt.money(newFee)))
            case .withdrawn:
                dismiss()
                onFinish(L("counter.result.withdrawn"))
            case .unavailable:
                dismiss()
            }
        }
    }
}
