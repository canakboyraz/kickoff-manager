import SwiftUI
import GameEngine

extension BoardExpectation {
    var label: String { L("board.expect.\(rawValue)") }
}

enum ConfidenceStyle {
    static func color(_ value: Int) -> Color {
        value >= 60 ? Theme.positive : (value >= 35 ? Theme.warning : Theme.negative)
    }

    static func label(_ value: Int) -> String {
        switch value {
        case 75...: return L("board.mood.delighted")
        case 55..<75: return L("board.mood.happy")
        case 35..<55: return L("board.mood.ok")
        case 20..<35: return L("board.mood.concerned")
        default: return L("board.mood.angry")
        }
    }
}

/// Manager reputation, the board's target and its confidence.
struct ManagerCard: View {
    let career: Career

    var body: some View {
        let manager = career.manager
        let confidence = manager.boardConfidence
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(L("manager.title"), systemImage: "person.crop.square.filled.and.at.rectangle")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                ReputationStars(reputation: manager.reputation)
            }
            HStack(spacing: 8) {
                StatTile(title: L("manager.reputation"), value: "\(manager.reputation)")
                StatTile(title: L("manager.target"), value: career.boardExpectation.label)
                StatTile(title: L("manager.trophies"), value: "\(manager.trophies)")
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(L("manager.confidence"))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(ConfidenceStyle.label(confidence))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ConfidenceStyle.color(confidence))
                }
                ValueBar(value: confidence, maxValue: 100, color: ConfidenceStyle.color(confidence), height: 8)
                    .accessibilityLabel(L("manager.confidence"))
                    .accessibilityValue("\(confidence)")
                if confidence <= 32 {
                    Text(L("manager.danger"))
                        .font(.caption2)
                        .foregroundStyle(Theme.negative)
                }
            }
        }
        .gameCard(highlight: confidence <= 20 ? Theme.negative.opacity(0.7) : nil)
    }
}

/// One job offer with accept/decline buttons.
struct JobOfferCard: View {
    let offer: JobOffer
    let career: Career
    var allowsDecline = true
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        if let club = career.club(offer.clubID) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    CrestView(club: club, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(club.name)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(career.league(club.leagueID).map { "\(Flags.emoji($0.countryCode)) \($0.name)" } ?? "")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 6) {
                            ReputationStars(reputation: club.reputation)
                            Text(Fmt.money(club.finances.transferBudget))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.goldLight)
                            if let position = career.league(club.leagueID)?.position(of: club.id), career.week > 0 {
                                Text(L("format.rank", String(position)))
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    if allowsDecline {
                        Button(L("job.decline"), action: onDecline)
                            .buttonStyle(OutlineButtonStyle(color: Theme.textSecondary))
                    }
                    Button(L("job.accept"), action: onAccept)
                        .buttonStyle(OutlineButtonStyle(color: Theme.positive))
                }
            }
            .gameCard(highlight: Theme.gold.opacity(0.5))
        }
    }
}

/// Shown after the board sacks the manager: pick a new club or start over.
struct SackedView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let career = store.career {
                    VStack(spacing: 16) {
                        Image(systemName: "door.left.hand.open")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.negative)
                            .padding(.top, 24)
                        Text(L("sacked.title"))
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text(L("sacked.body", career.userClub.name))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                        HStack(spacing: 8) {
                            StatTile(title: L("manager.reputation"), value: "\(career.manager.reputation)")
                            StatTile(title: L("manager.trophies"), value: "\(career.manager.trophies)")
                            StatTile(title: L("manager.seasons"), value: "\(career.manager.seasonsManaged)")
                        }
                        SectionTitle(text: L("sacked.offers"))
                        ForEach(career.jobOffers) { offer in
                            JobOfferCard(offer: offer, career: career, allowsDecline: career.jobOffers.count > 1) {
                                withAnimation { store.update { $0.acceptJob(offer.id) } }
                            } onDecline: {
                                store.update { $0.declineJob(offer.id) }
                            }
                        }
                        Button(L("club.newCareer"), role: .destructive) { confirmReset = true }
                            .buttonStyle(OutlineButtonStyle(color: Theme.negative))
                            .padding(.top, 8)
                    }
                    .padding(16)
                }
            }
            .gameBackground()
            .confirmationDialog(L("club.newCareer.confirm"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(L("club.newCareer"), role: .destructive) { store.abandonCareer() }
            }
        }
    }
}
