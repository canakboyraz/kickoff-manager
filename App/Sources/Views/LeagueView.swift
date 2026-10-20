import SwiftUI
import GameEngine

struct LeagueView: View {
    @Environment(GameStore.self) private var store
    @State private var leagueID: UUID?
    @State private var matchday: Int?

    var body: some View {
        ScrollView {
            if let career = store.career {
                let league = leagueID.flatMap { career.league($0) } ?? career.userLeague
                VStack(spacing: 14) {
                    leaguePicker(career, selected: league)
                    table(career, league: league)
                    fixtures(career, league: league)
                }
                .padding(16)
            }
        }
        .gameBackground()
        .navigationTitle(L("tab.league"))
        .navigationBarTitleDisplayMode(.inline)
        .gameDestinations()
    }

    private func leaguePicker(_ career: Career, selected: League) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(career.leagues) { league in
                    Button {
                        leagueID = league.id
                    } label: {
                        Text("\(Flags.emoji(league.countryCode)) \(league.name)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(league.id == selected.id ? Theme.goldDark : Theme.textPrimary)
                            .background(league.id == selected.id ? Theme.gold : Theme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func table(_ career: Career, league: League) -> some View {
        let rows = league.table()
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("#").frame(width: 22, alignment: .leading)
                Text(L("league.club")).frame(maxWidth: .infinity, alignment: .leading)
                Text(L("league.played")).frame(width: 26)
                Text(L("league.gd")).frame(width: 34)
                Text(L("league.points")).frame(width: 32)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.textMuted)
            .padding(.vertical, 8)

            ForEach(Array(rows.enumerated()), id: \.element.clubID) { index, row in
                if let club = career.club(row.clubID) {
                    let isUser = row.clubID == career.userClubID
                    HStack(spacing: 6) {
                        Text("\(index + 1)")
                            .frame(width: 22, alignment: .leading)
                            .foregroundStyle(index < 4 ? Theme.positive : (index >= rows.count - 3 ? Theme.negative : Theme.textSecondary))
                        CrestView(club: club, size: 20)
                        Text(club.name)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(isUser ? Theme.goldLight : Theme.textPrimary)
                        Text("\(row.played)").frame(width: 26)
                        Text(row.goalDifference > 0 ? "+\(row.goalDifference)" : "\(row.goalDifference)").frame(width: 34)
                        Text("\(row.points)")
                            .fontWeight(.heavy)
                            .frame(width: 32)
                            .foregroundStyle(isUser ? Theme.goldLight : Theme.textPrimary)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 4)
                    .background(isUser ? Theme.gold.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .gameCard(padding: 10)
    }

    private func fixtures(_ career: Career, league: League) -> some View {
        let total = max(1, league.matchdayCount)
        let current = (matchday ?? max(1, career.week)).clamped(min: 1, max: total)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: L("league.matchday", String(current)))
                Button { matchday = max(1, current - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(current <= 1)
                Button { matchday = min(total, current + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(current >= total)
            }
            .foregroundStyle(Theme.gold)
            ForEach(league.fixtures(on: current)) { fixture in
                if let home = career.club(fixture.homeID), let away = career.club(fixture.awayID) {
                    let row = HStack(spacing: 8) {
                        Text(home.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .trailing)
                        CrestView(club: home, size: 18)
                        Text(fixture.result.map { "\($0.homeGoals) - \($0.awayGoals)" } ?? "-")
                            .font(.subheadline.weight(.heavy).monospacedDigit())
                            .foregroundStyle(fixture.result == nil ? Theme.textMuted : Theme.goldLight)
                            .frame(width: 54)
                        CrestView(club: away, size: 18)
                        Text(away.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption)
                    .foregroundStyle(fixture.involves(career.userClubID) ? Theme.goldLight : Theme.textPrimary)

                    if fixture.result != nil {
                        NavigationLink(value: MatchLink(fixtureID: fixture.id)) { row }
                            .buttonStyle(.plain)
                    } else {
                        row
                    }
                }
            }
        }
        .gameCard()
    }
}

private extension Int {
    func clamped(min lower: Int, max upper: Int) -> Int {
        Swift.min(Swift.max(self, lower), upper)
    }
}
