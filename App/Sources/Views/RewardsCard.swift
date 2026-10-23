import SwiftUI
import GameEngine

/// Free transfer money: a rewarded ad every hour and a penalty challenge once a day.
struct RewardsCard: View {
    @Environment(GameStore.self) private var store
    @State private var showPenalty = GameStore.launchValue("-showPenalty") == "1"
    @State private var notice: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let adWait = DailyRewards.adWaitSeconds(now: context.date)
            let penaltyReady = DailyRewards.penaltyAvailable(now: context.date)
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: L("rewards.title"))
                HStack(spacing: 8) {
                    rewardButton(
                        icon: "play.rectangle.fill",
                        title: L("rewards.ad", Fmt.money(DailyRewards.adReward)),
                        status: adWait <= 0 ? L("rewards.ready") : L("rewards.adWait", String(Int((adWait / 60).rounded(.up)))),
                        enabled: adWait <= 0,
                        action: watchAd
                    )
                    rewardButton(
                        icon: "soccerball",
                        title: L("rewards.penalty", Fmt.money(DailyRewards.penaltyReward)),
                        status: penaltyReady ? L("rewards.ready") : L("rewards.penaltyTomorrow"),
                        enabled: penaltyReady,
                        action: { showPenalty = true }
                    )
                }
            }
            .gameCard()
        }
        .fullScreenCover(isPresented: $showPenalty) {
            PenaltyGameView { scored in
                showPenalty = false
                if scored {
                    store.update { $0.receiveBonus(DailyRewards.penaltyReward, source: .penalty) }
                    notice = L("rewards.penaltyDone", Fmt.money(DailyRewards.penaltyReward))
                }
            }
        }
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(L("common.ok")) {}
        }
    }

    private func rewardButton(icon: String, title: String, status: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(enabled ? Theme.gold : Theme.textMuted)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(enabled ? Theme.positive : Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Theme.surfaceRaised.opacity(enabled ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(enabled ? Theme.gold.opacity(0.7) : Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func watchAd() {
        let shown = AdManager.shared.showRewarded {
            DailyRewards.markAdWatched()
            store.update { $0.receiveBonus(DailyRewards.adReward, source: .rewardedAd) }
        }
        if !shown { notice = L("rewards.adLoading") }
    }
}
