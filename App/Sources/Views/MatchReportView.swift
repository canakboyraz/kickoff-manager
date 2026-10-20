import SwiftUI
import GameEngine

/// Full-screen report for any played fixture (opened from results and the league tab).
struct MatchReportView: View {
    let fixtureID: UUID
    @Environment(GameStore.self) private var store

    var body: some View {
        ScrollView {
            if let career = store.career,
               let fixture = career.leagues.lazy.flatMap(\.fixtures).first(where: { $0.id == fixtureID }) {
                MatchSummaryView(fixture: fixture, career: career)
                    .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("match.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Score header, goal timeline and player ratings.
struct MatchSummaryView: View {
    let fixture: Fixture
    let career: Career

    var body: some View {
        if let result = fixture.result,
           let home = career.club(fixture.homeID),
           let away = career.club(fixture.awayID) {
            VStack(spacing: 14) {
                scoreboard(result: result, home: home, away: away)
                timeline(result: result)
                ratings(result: result)
            }
        }
    }

    private func scoreboard(result: MatchResult, home: Club, away: Club) -> some View {
        VStack(spacing: 10) {
            Text(L("match.matchday", String(fixture.matchday)))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: "C0DD97"))
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
                let isHome = event.clubID == fixture.homeID
                HStack(spacing: 8) {
                    if !isHome { Spacer() }
                    Text("\(event.minute)'")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Theme.goldLight)
                    Image(systemName: event.kind == .goal ? "soccerball" : "cross.case.fill")
                        .foregroundStyle(event.kind == .goal ? Theme.textPrimary : Theme.negative)
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
                    if isHome { Spacer() }
                }
            }
        }
        .gameCard()
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
