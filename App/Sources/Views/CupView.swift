import SwiftUI
import GameEngine

/// One European cup: status, knockout ties, group tables and the user's games.
struct CupView: View {
    let cup: Cup
    let career: Career

    private static let groupNames = ["A", "B", "C", "D"]

    var body: some View {
        VStack(spacing: 14) {
            header
            knockout
            groups
            userGames
        }
    }

    // MARK: - Header

    private var header: some View {
        let user = career.userClubID
        let status: String
        if let stage = cup.stageReached(by: user) {
            if stage == .winner {
                status = L("cup.status.won")
            } else if cup.isAlive(user) {
                status = L("cup.status.alive", stage.label)
            } else {
                status = L("cup.status.out", stage.label)
            }
        } else {
            status = L("cup.status.notIn")
        }
        return HStack(spacing: 12) {
            Image(systemName: cup.kind.icon)
                .font(.title)
                .foregroundStyle(cup.kind.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(cup.kind.label)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(Fmt.seasonLabel(cup.season))
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(cup.kind.color)
                if let winnerID = cup.winnerID, let winner = career.club(winnerID) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill").foregroundStyle(Theme.goldLight)
                        CrestView(club: winner, size: 18)
                        Text(winner.name).font(.caption.weight(.bold)).foregroundStyle(Theme.goldLight)
                    }
                }
            }
            Spacer()
        }
        .gameCard(highlight: cup.kind.color.opacity(0.5))
    }

    // MARK: - Knockout

    @ViewBuilder
    private var knockout: some View {
        let stages = [CupStage.final, .semiFinal, .quarterFinal].filter { !cup.fixtures(in: $0).isEmpty }
        if !stages.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(stages, id: \.self) { stage in
                    SectionTitle(text: stage.label)
                    ForEach(cup.tieIndices(in: stage), id: \.self) { tie in
                        tieRow(stage: stage, tie: tie)
                    }
                }
            }
            .gameCard()
        }
    }

    private func tieRow(stage: CupStage, tie: Int) -> some View {
        let legs = cup.legs(stage: stage, tie: tie)
        let score = cup.aggregate(stage: stage, tie: tie)
        let winner = cup.tieWinner(stage: stage, tie: tie)
        let played = legs.contains { $0.result != nil }
        return VStack(spacing: 6) {
            if let score, let first = career.club(score.first), let second = career.club(score.second) {
                HStack(spacing: 8) {
                    teamLabel(first, isWinner: winner == first.id, alignment: .trailing)
                    Text(played ? "\(score.firstGoals) - \(score.secondGoals)" : "-")
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(played ? Theme.goldLight : Theme.textMuted)
                        .frame(width: 50)
                    teamLabel(second, isWinner: winner == second.id, alignment: .leading)
                }
            }
            HStack(spacing: 10) {
                ForEach(legs) { leg in
                    if leg.result != nil {
                        NavigationLink(value: MatchLink(fixtureID: leg.id)) {
                            legLabel(leg)
                        }
                        .buttonStyle(.plain)
                    } else {
                        legLabel(leg)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func teamLabel(_ club: Club, isWinner: Bool, alignment: Alignment) -> some View {
        HStack(spacing: 6) {
            if alignment == .leading { CrestView(club: club, size: 18) }
            Text(club.name)
                .font(.caption.weight(isWinner ? .heavy : .regular))
                .foregroundStyle(club.id == career.userClubID ? Theme.goldLight : Theme.textPrimary)
                .lineLimit(1)
            if alignment == .trailing { CrestView(club: club, size: 18) }
        }
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func legLabel(_ leg: CupFixture) -> some View {
        let text: String
        if let result = leg.result {
            text = "\(leg.stageCaption): \(result.homeGoals)-\(result.awayGoals)"
        } else {
            text = "\(leg.stageCaption) · \(L("league.matchday", String(leg.week)))"
        }
        return Text(text)
            .font(.caption2)
            .foregroundStyle(leg.result == nil ? Theme.textMuted : Theme.textSecondary)
    }

    // MARK: - Groups

    private var groups: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(cup.groups.indices, id: \.self) { index in
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Text(L("cup.group", CupView.groupNames[min(index, 3)]))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(L("league.played")).frame(width: 24)
                        Text(L("league.gd")).frame(width: 30)
                        Text(L("league.points")).frame(width: 28)
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.bottom, 6)
                    ForEach(Array(cup.groupTable(index).enumerated()), id: \.element.clubID) { position, row in
                        if let club = career.club(row.clubID) {
                            HStack(spacing: 6) {
                                Text("\(position + 1)")
                                    .frame(width: 16, alignment: .leading)
                                    .foregroundStyle(position < 2 ? Theme.positive : Theme.textMuted)
                                CrestView(club: club, size: 18)
                                Text(club.name)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(club.id == career.userClubID ? Theme.goldLight : Theme.textPrimary)
                                Text("\(row.played)").frame(width: 24)
                                Text(row.goalDifference > 0 ? "+\(row.goalDifference)" : "\(row.goalDifference)").frame(width: 30)
                                Text("\(row.points)").fontWeight(.heavy).frame(width: 28)
                            }
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 5)
                        }
                    }
                }
                .gameCard(padding: 10)
            }
        }
    }

    // MARK: - User games

    @ViewBuilder
    private var userGames: some View {
        let games = cup.fixtures(for: career.userClubID)
        if !games.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(text: L("cup.yourGames"))
                ForEach(games) { game in
                    if game.result != nil {
                        NavigationLink(value: MatchLink(fixtureID: game.id)) {
                            gameRow(game)
                        }
                        .buttonStyle(.plain)
                    } else {
                        gameRow(game)
                    }
                }
            }
            .gameCard()
        }
    }

    private func gameRow(_ game: CupFixture) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.stageCaption)
                    .font(.caption2)
                    .foregroundStyle(Theme.textMuted)
                HStack(spacing: 6) {
                    if let home = career.club(game.homeID) { CrestView(club: home, size: 18) }
                    Text(game.result.map { "\($0.homeGoals) - \($0.awayGoals)" } ?? L("common.vs"))
                        .font(.subheadline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(game.result == nil ? Theme.textMuted : Theme.goldLight)
                    if let away = career.club(game.awayID) { CrestView(club: away, size: 18) }
                    Text(opponentName(game))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(L("league.matchday", String(game.week)))
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
        }
    }

    private func opponentName(_ game: CupFixture) -> String {
        let opponent = game.homeID == career.userClubID ? game.awayID : game.homeID
        return career.club(opponent)?.name ?? ""
    }
}
