import SwiftUI
import GameEngine

/// Move money between the transfer budget and the weekly wage budget.
struct BudgetSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var toWages = true
    @State private var weekly: Double = 0
    @State private var feedback: Feedback?

    var body: some View {
        NavigationStack {
            ScrollView {
                if let career = store.career {
                    content(career).padding(20)
                }
            }
            .gameBackground()
            .navigationTitle(L("budget.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
    }

    private func content(_ career: Career) -> some View {
        let finances = career.userClub.finances
        let wageBill = career.wageBill(of: career.userClubID)
        let maxWeekly = toWages ? career.maxTransferToWage : career.maxWageToTransfer
        let step = 500.0
        let upper = Double(maxWeekly / 500 * 500)
        let amount = min(Int(weekly), maxWeekly)
        let transferChange = Career.transferEquivalent(ofWeekly: amount) * (toWages ? -1 : 1)
        let wageChange = amount * (toWages ? 1 : -1)

        return VStack(spacing: 16) {
            Picker("", selection: $toWages) {
                Text(L("budget.toWages")).tag(true)
                Text(L("budget.toTransfers")).tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: toWages) { _, _ in weekly = 0 }

            if let feedback {
                FeedbackBanner(feedback: feedback)
            }

            VStack(spacing: 8) {
                InfoRow(title: L("transfers.budget"),
                        value: "\(Fmt.money(finances.transferBudget)) → \(Fmt.money(finances.transferBudget + transferChange))")
                InfoRow(title: L("budget.wageBudget"),
                        value: "\(Fmt.wage(finances.wageBudget)) → \(Fmt.wage(finances.wageBudget + wageChange))")
                InfoRow(title: L("budget.wageBill"), value: Fmt.wage(wageBill))
                InfoRow(title: L("transfers.wageRoom"),
                        value: Fmt.wage(finances.wageBudget + wageChange - wageBill),
                        color: Theme.goldLight)
            }
            .gameCard()

            VStack(spacing: 6) {
                Text(Fmt.wage(amount))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldLight)
                    .contentTransition(.numericText())
                Text(L("budget.equals", Fmt.money(Career.transferEquivalent(ofWeekly: amount))))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                if upper >= step {
                    Slider(value: $weekly, in: 0...upper, step: step)
                        .tint(Theme.gold)
                } else {
                    Text(toWages ? L("budget.noTransferMoney") : L("budget.noWageRoom"))
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                }
            }

            Text(L("budget.rateHint", Fmt.money(Career.budgetConversionRate)))
                .font(.caption)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)

            Button(L("budget.apply")) {
                let result = store.update { $0.moveBudget(weekly: toWages ? amount : -amount) }
                withAnimation(.snappy) {
                    switch result {
                    case .moved?:
                        feedback = Feedback(tone: .good, text: L("budget.done"))
                        weekly = 0
                    case .notEnough?:
                        feedback = Feedback(tone: .bad, text: L("budget.noTransferMoney"))
                    case .belowWageBill?:
                        feedback = Feedback(tone: .bad, text: L("budget.noWageRoom"))
                    default:
                        break
                    }
                }
            }
            .buttonStyle(GoldButtonStyle())
            .disabled(amount <= 0)
        }
    }
}
