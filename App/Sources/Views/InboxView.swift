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
                body: fee == 0 ? L("msg.signedFree.body", playerName(playerID)) : L("msg.signed.body", playerName(playerID), Fmt.money(fee))
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
        case .cupQualified(let kind, let season):
            return Content(
                icon: kind.icon, color: kind.color,
                title: L("msg.cupQualified.title", kind.label),
                body: L("msg.cupQualified.body", Fmt.seasonLabel(season), kind.label)
            )
        case .cupProgress(let kind, let stage, let prize):
            return Content(
                icon: kind.icon, color: kind.color,
                title: L("msg.cupProgress.title", kind.label, stage.label),
                body: L("msg.cupProgress.body", stage.label, Fmt.money(prize))
            )
        case .cupEliminated(let kind, let stage):
            return Content(
                icon: "xmark.shield.fill", color: Theme.textSecondary,
                title: L("msg.cupOut.title", kind.label),
                body: L("msg.cupOut.body", stage.label)
            )
        case .cupWon(let kind, let prize):
            return Content(
                icon: "trophy.fill", color: Theme.goldLight,
                title: L("msg.cupWon.title", kind.label),
                body: L("msg.cupWon.body", kind.label, Fmt.money(prize))
            )
        case .offerImproved(let offerID):
            guard let offer = career.offer(offerID) else {
                return Content(icon: "arrow.up.circle.fill", color: Theme.goldLight, title: L("msg.offerImproved.title"), body: "")
            }
            return Content(
                icon: "arrow.up.circle.fill", color: Theme.goldLight,
                title: L("msg.offerImproved.title"),
                body: L("msg.offerImproved.body", clubName(offer.fromClubID), playerName(offer.playerID), Fmt.money(offer.fee))
            )
        case .transferWindowOpened(let winter, let weeks):
            return Content(
                icon: "lock.open.fill", color: Theme.positive,
                title: winter ? L("msg.windowWinter.title") : L("msg.windowSummer.title"),
                body: L("msg.windowOpen.body", String(weeks))
            )
        case .transferWindowClosed:
            return Content(
                icon: "lock.fill", color: Theme.textSecondary,
                title: L("msg.windowClosed.title"),
                body: L("msg.windowClosed.body")
            )
        case .boardWarning(let level):
            return Content(
                icon: "exclamationmark.triangle.fill", color: level >= 2 ? Theme.negative : Theme.warning,
                title: level >= 2 ? L("msg.boardFinal.title") : L("msg.boardConcern.title"),
                body: level >= 2 ? L("msg.boardFinal.body") : L("msg.boardConcern.body")
            )
        case .sacked(let clubID):
            return Content(
                icon: "door.left.hand.open", color: Theme.negative,
                title: L("sacked.title"),
                body: L("sacked.body", clubName(clubID))
            )
        case .jobOffer(_, let clubID):
            return Content(
                icon: "briefcase.fill", color: Theme.goldLight,
                title: L("msg.jobOffer.title"),
                body: L("msg.jobOffer.body", clubName(clubID))
            )
        case .newJob(let clubID):
            return Content(
                icon: "hand.wave.fill", color: Theme.positive,
                title: L("msg.newJob.title"),
                body: L("msg.newJob.body", clubName(clubID))
            )
        case .contractsReminder(let playerIDs, let final):
            let names = playerIDs.compactMap { career.player($0)?.shortName }.joined(separator: ", ")
            return Content(
                icon: "doc.text.fill", color: final ? Theme.negative : Theme.warning,
                title: L(final ? "msg.contracts.finalTitle" : "msg.contracts.title", String(playerIDs.count)),
                body: L("msg.contracts.body", names)
            )
        case .scoutReport(let playerIDs):
            let names = playerIDs.compactMap { career.player($0)?.shortName }.joined(separator: ", ")
            return Content(
                icon: "binoculars.fill", color: Theme.goldLight,
                title: L("msg.scout.title"),
                body: playerIDs.isEmpty ? L("msg.scout.none") : L("msg.scout.body", String(playerIDs.count), names)
            )
        case .bonus(let amount, let source):
            return Content(
                icon: source == .penalty ? "soccerball" : "gift.fill", color: Theme.positive,
                title: L("msg.bonus.title"),
                body: L(source == .penalty ? "msg.bonus.penalty" : "msg.bonus.ad", Fmt.money(amount))
            )
        case .suspension(let playerID, let matches, let reason):
            return Content(
                icon: "rectangle.portrait.fill", color: Theme.negative,
                title: L("msg.suspension.title"),
                body: L("msg.suspension.\(reason.rawValue)", playerName(playerID), String(matches))
            )
        case .seasonReview(let expected, let position, let confidence):
            let tone: Color = position <= expected ? Theme.positive : (position - expected <= 3 ? Theme.warning : Theme.negative)
            return Content(
                icon: "person.3.sequence.fill", color: tone,
                title: L("msg.review.title"),
                body: L("msg.review.body", String(expected), String(position), ConfidenceStyle.label(confidence))
            )
        }
    }
}
