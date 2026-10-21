import SwiftUI
import GameEngine

/// Full-screen report for any played league or cup game.
struct MatchReportView: View {
    let fixtureID: UUID
    @Environment(GameStore.self) private var store

    var body: some View {
        ScrollView {
            if let career = store.career {
                Group {
                    if let fixture = career.leagues.lazy.flatMap(\.fixtures).first(where: { $0.id == fixtureID }) {
                        MatchSummaryView(fixture: fixture, career: career)
                    } else if let match = career.cupMatch(fixtureID) {
                        MatchSummaryView(cupFixture: match.fixture, kind: match.cup.kind, cup: match.cup, career: career)
                    }
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("match.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Score header, events (goals, injuries, substitutions) and the user's player ratings.
struct MatchSummaryView: View {
    let homeID: UUID
    let awayID: UUID
    let result: MatchResult?
    let caption: String
    let captionColor: Color
    /// Aggregate score or penalty winner for cup ties.
    let note: String?
    let career: Career

    init(fixture: Fixture, career: Career) {
        homeID = fixture.homeID
        awayID = fixture.awayID
        result = fixture.result
        caption = L("match.matchday", String(fixture.matchday))
        captionColor = Color(hex: "C0DD97")
        note = nil
        self.career = career
    }

    init(cupFixture: CupFixture, kind: CompetitionKind, cup: Cup?, career: Career) {
        homeID = cupFixture.homeID
        awayID = cupFixture.awayID
        result = cupFixture.result
        caption = "\(kind.label.uppercased()) · \(cupFixture.stageCaption)"
        captionColor = kind.color
        var lines: [String] = []
        if let cup, let tie = cupFixture.tie, cupFixture.stage != .final, cupFixture.leg == 2,
           let score = cup.aggregate(stage: cupFixture.stage, tie: tie),
           let first = career.club(score.first), let second = career.club(score.second) {
            lines.append(L("match.aggregate", first.shortName, String(score.firstGoals), String(score.secondGoals), second.shortName))
        }
        if let winnerID = cupFixture.shootoutWinnerID, let winner = career.club(winnerID) {
            lines.append(L("match.penalties", winner.name))
        }
        note = lines.isEmpty ? nil : lines.joined(separator: "\n")
        self.career = career
    }

    var body: some View {
        if let result, let home = career.club(homeID), let away = career.club(awayID) {
            VStack(spacing: 14) {
                scoreboard(result: result, home: home, away: away)
                timeline(result: result)
                ratings(result: result)
            }
        }
    }

    private func scoreboard(result: MatchResult, home: Club, away: Club) -> some View {
        VStack(spacing: 10) {
            Text(caption)
                .font(.caption.weight(.bold))
                .foregroundStyle(captionColor)
                .multilineTextAlignment(.center)
            HStack {
                VStack(spacing: 6) {
                    CrestView(club: home, size: 52)
                    Text(home.name).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Text("\(result.homeGoals) - \(result.awayGoals)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.goldLight)
                VStack(spacing: 6) {
                    CrestView(club: away, size: 52)
                    Text(away.name).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.white)
            if let note {
                Text(note)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 14) {
                Label(L("match.xg", Fmt.rating(result.homeExpectedGoals), Fmt.rating(result.awayExpectedGoals)), systemImage: "scope")
                Label(Fmt.number(result.attendance), systemImage: "person.3.fill")
            }
            .font(.caption)
            .foregroundStyle(Color(hex: "C0DD97"))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(PitchBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timeline(result: MatchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: L("match.events"))
            if result.events.isEmpty {
                Text(L("match.noEvents"))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textMuted)
            }
            ForEach(Array(result.events.enumerated()), id: \.offset) { _, event in
                eventRow(event)
            }
        }
        .gameCard()
    }

    private func eventRow(_ event: MatchEvent) -> some View {
        let isHome = event.clubID == homeID
        return HStack(spacing: 8) {
            if !isHome { Spacer() }
            Text("\(event.minute)'")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.goldLight)
            switch event.kind {
            case .goal:
                Image(systemName: "soccerball").foregroundStyle(Theme.textPrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(career.player(event.playerID)?.shortName ?? "?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if let assistID = event.assistID, let assist = career.player(assistID) {
                        Text(L("match.assist", assist.shortName))
                            .font(.caption2)
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            case .injury:
                Image(systemName: "cross.case.fill").foregroundStyle(Theme.negative)
                Text(career.player(event.playerID)?.shortName ?? "?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
            case .yellowCard, .redCard:
                RoundedRectangle(cornerRadius: 2)
                    .fill(event.kind == .yellowCard ? Color(hex: "FAC775") : Color(hex: "E24B4A"))
                    .frame(width: 10, height: 14)
                Text(career.player(event.playerID)?.shortName ?? "?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
            case .substitution:
                Image(systemName: "arrow.up.arrow.down").foregroundStyle(Theme.textSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.subInID.flatMap { career.player($0)?.shortName } ?? "?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.positive)
                    Text(career.player(event.playerID)?.shortName ?? "?")
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            if isHome { Spacer() }
        }
    }

    private func ratings(result: MatchResult) -> some View {
        let userRatings = result.ratings
            .filter { $0.clubID == career.userClubID }
            .sorted { $0.rating > $1.rating }
        return Group {
            if !userRatings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionTitle(text: L("match.ratings"))
                    ForEach(userRatings, id: \.playerID) { entry in
                        if let player = career.player(entry.playerID) {
                            HStack {
                                Text(player.position.shortLabel)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 34, alignment: .leading)
                                Text(player.shortName)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                if entry.minutes < 90 {
                                    Text("\(entry.minutes)'")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textMuted)
                                }
                                Spacer()
                                Text(Fmt.rating(entry.rating))
                                    .font(.subheadline.weight(.heavy).monospacedDigit())
                                    .foregroundStyle(entry.rating >= 7.5 ? Theme.positive : (entry.rating < 6 ? Theme.negative : Theme.textPrimary))
                            }
                        }
                    }
                }
                .gameCard()
            }
        }
    }
}
