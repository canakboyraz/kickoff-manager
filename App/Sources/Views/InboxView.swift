import SwiftUI
import GameEngine

struct InboxView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        ScrollView {
            if let career = store.career {
                LazyVStack(spacing: 10) {
                    if career.inbox.isEmpty {
                        Text(L("inbox.empty"))
                            .foregroundStyle(Theme.textMuted)
                            .padding(.top, 40)
                    }
                    ForEach(career.inbox.reversed()) { message in
                        MessageRow(message: message, career: career)
                            .gameCard(padding: 12, highlight: message.isRead ? nil : Theme.gold.opacity(0.6))
                    }
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("home.inbox"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { store.update { $0.markAllRead() } }
    }
}

/// Turns a structured inbox message into localized text.
struct MessageRow: View {
    let message: InboxMessage
    let career: Career

    var body: some View {
        let content = MessageText.make(message, career: career)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: content.icon)
                .font(.title3)
                .foregroundStyle(content.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(content.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(content.body)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

enum MessageText {
    struct Content {
        var icon: String
        var color: Color
        var title: String
        var body: String
    }

    static func make(_ message: InboxMessage, career: Career) -> Content {
        func playerName(_ id: UUID) -> String { career.player(id)?.fullName ?? "?" }
        func clubName(_ id: UUID?) -> String { id.flatMap { career.club($0)?.name } ?? "?" }

        switch message.kind {
        case .boardWelcome:
            return Content(
                icon: "briefcase.fill", color: Theme.goldLight,
                title: L("msg.welcome.title"),
                body: L("msg.welcome.body", career.userClub.name, career.userLeague.name, Fmt.money(career.userClub.finances.transferBudget))
            )
        case .transferOffer(let offerID):
            guard let offer = career.offer(offerID) else {
                return Content(icon: "envelope", color: Theme.textMuted, title: L("msg.offer.title"), body: "")
            }
            return Content(
                icon: "arrow.left.arrow.right.circle.fill", color: Theme.goldLight,
                title: L("msg.offer.title"),
                body: L("msg.offer.body", clubName(offer.fromClubID), playerName(offer.playerID), Fmt.money(offer.fee))
            )
        case .signingCompleted(let playerID, let fee):
            return Content(
                icon: "signature", color: Theme.positive,
                title: L("msg.signed.title"),
                body: L("msg.signed.body", playerName(playerID), Fmt.money(fee))
            )
        case .playerLeft(let playerID, let toClubID, let fee):
            if let toClubID {
                return Content(
                    icon: "figure.walk.departure", color: Theme.textSecondary,
                    title: L("msg.sold.title"),
                    body: L("msg.sold.body", playerName(playerID), clubName(toClubID), Fmt.money(fee))
                )
            }
            return Content(
                icon: "figure.walk.departure", color: Theme.textSecondary,
                title: L("msg.left.title"),
                body: L("msg.left.body", playerName(playerID))
            )
        case .injury(let playerID, let weeks):
            return Content(
                icon: "cross.case.fill", color: Theme.negative,
                title: L("msg.injury.title"),
                body: L("msg.injury.body", playerName(playerID), String(weeks))
            )
        case .upgradeCompleted(let kind):
            return Content(
                icon: kind.icon, color: Theme.positive,
                title: L("msg.upgrade.title"),
                body: L("msg.upgrade.body", kind.label)
            )
        case .youthIntake(let playerIDs):
            let names = playerIDs.compactMap { career.player($0)?.shortName }.joined(separator: ", ")
            return Content(
                icon: "graduationcap.fill", color: Theme.goldLight,
                title: L("msg.youth.title"),
                body: L("msg.youth.body", String(playerIDs.count), names)
            )
        case .contractExpiring(let playerID):
            return Content(
                icon: "doc.text.fill", color: Theme.warning,
                title: L("msg.contract.title"),
                body: L("msg.contract.body", playerName(playerID))
            )
        case .seasonEnded(let season, let position, let prize):
            return Content(
                icon: "trophy.fill", color: Theme.goldLight,
                title: L("msg.season.title", Fmt.seasonLabel(season)),
                body: L("msg.season.body", String(position), Fmt.money(prize))
            )
        }
    }
}
