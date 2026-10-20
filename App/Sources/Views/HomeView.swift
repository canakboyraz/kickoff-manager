import SwiftUI
import GameEngine

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @State private var seasonSummary: SeasonSummary?

    var body: some View {
        if let career = store.career {
            content(career)
        }
    }

    private func content(_ career: Career) -> some View {
        let club = career.userClub
        return ScrollView {
            VStack(spacing: 14) {
                clubHeader(career, club: club)
                if career.isTransferWindowOpen {
                    windowBanner(career)
                }
                nextMatchCard(career)
                if let last = career.lastUserFixture {
                    NavigationLink(value: MatchLink(fixtureID: last.id)) {
                        ResultCard(fixture: last, career: career)
                    }
                    .buttonStyle(.plain)
                }
                topPerformers(career)
                inboxPreview(career)
            }
            .padding(16)
        }
        .gameBackground()
        .navigationTitle(L("tab.home"))
        .navigationBarTitleDisplayMode(.inline)
        .gameDestinations()
        .sheet(item: Binding(
            get: { store.presentedReport },
            set: { store.presentedReport = $0 }
        )) { box in
            WeekReportSheet(report: box.report) { summary in
                seasonSummary = summary
            }
        }
        .alert(
            L("season.over.title"),
            isPresented: Binding(get: { seasonSummary != nil }, set: { if !$0 { seasonSummary = nil } }),
            presenting: seasonSummary
        ) { _ in
            Button(L("common.ok")) {}
        } message: { summary in
            Text(L("season.over.body", Fmt.seasonLabel(summary.season), String(summary.position), String(summary.points), Fmt.money(summary.prizeMoney)))
        }
    }

    private func clubHeader(_ career: Career, club: Club) -> some View {
        HStack(spacing: 12) {
            CrestView(club: club, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(club.name)
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text(L("home.leagueLine",
                       career.userLeague.name,
                       career.userLeaguePosition.map { String($0) } ?? "-",
                       Fmt.seasonLabel(career.season)))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Chip(text: Fmt.money(club.finances.balance), icon: "dollarsign.circle.fill")
        }
    }

    private func windowBanner(_ career: Career) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
            Text(L("home.windowOpen"))
            Spacer()
            if !career.pendingOffers.isEmpty {
                Chip(text: L("home.offers", String(career.pendingOffers.count)), color: Theme.goldLight)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Theme.positive)
        .gameCard(padding: 10, highlight: Theme.positive.opacity(0.6))
    }

    private func nextMatchCard(_ career: Career) -> some View {
        VStack(spacing: 12) {
            if let fixture = career.nextUserFixture,
               let home = career.club(fixture.homeID),
               let away = career.club(fixture.awayID) {
                Text(L("home.nextMatch", String(fixture.matchday), String(career.matchdayCount)))
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Color(hex: "C0DD97"))
                HStack {
                    teamColumn(home, career: career)
                    Text(L("common.vs"))
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Theme.goldLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.background, in: RoundedRectangle(cornerRadius: 8))
                    teamColumn(away, career: career)
                }
            }

            Button {
                Task { await store.playWeek() }
            } label: {
                HStack(spacing: 8) {
                    if store.isSimulating {
                        ProgressView().tint(Theme.goldDark)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(store.isSimulating ? L("home.simulating") : L("home.playWeek"))
                }
            }
            .buttonStyle(GoldButtonStyle())
            .disabled(store.isSimulating)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(PitchBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func teamColumn(_ club: Club, career: Career) -> some View {
        VStack(spacing: 6) {
            CrestView(club: club, size: 46)
            Text(club.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(career.userLeague.position(of: club.id).map { L("format.rank", String($0)) } ?? "")
                .font(.caption2)
                .foregroundStyle(Color(hex: "C0DD97"))
        }
        .frame(maxWidth: .infinity)
    }

    private func topPerformers(_ career: Career) -> some View {
        let squad = career.userSquad.filter { $0.stats.appearances > 0 }
        let scorers = squad.sorted { ($0.stats.goals, $0.stats.averageRating) > ($1.stats.goals, $1.stats.averageRating) }.prefix(3)
        return Group {
            if !scorers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: L("home.topPerformers"))
                    HStack(spacing: 8) {
                        ForEach(Array(scorers)) { player in
                            NavigationLink(value: PlayerLink(id: player.id)) {
                                VStack(spacing: 4) {
                                    PlayerCardView(player: player, season: career.season)
                                    Text(L("home.goalsRating", String(player.stats.goals), Fmt.rating(player.stats.averageRating)))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textMuted)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func inboxPreview(_ career: Career) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(text: L("home.inbox"))
                if career.unreadCount > 0 {
                    Chip(text: String(career.unreadCount), color: Theme.goldLight)
                }
                NavigationLink(value: InboxLink()) {
                    Text(L("common.seeAll"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
            ForEach(career.inbox.suffix(3).reversed()) { message in
                MessageRow(message: message, career: career)
                    .gameCard(padding: 12)
            }
        }
    }
}

struct PitchBackground: View {
    var body: some View {
        ZStack {
            Theme.pitch
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: proxy.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: proxy.size.width / 2, y: proxy.size.height))
                }
                .stroke(Theme.pitchLine.opacity(0.6), lineWidth: 1)
                Circle()
                    .stroke(Theme.pitchLine.opacity(0.6), lineWidth: 1)
                    .frame(width: 70, height: 70)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }
}

struct ResultCard: View {
    let fixture: Fixture
    let career: Career

    var body: some View {
        if let result = fixture.result,
           let home = career.club(fixture.homeID),
           let away = career.club(fixture.awayID) {
            let userIsHome = fixture.homeID == career.userClubID
            let userGoals = userIsHome ? result.homeGoals : result.awayGoals
            let otherGoals = userIsHome ? result.awayGoals : result.homeGoals
            let outcome = userGoals > otherGoals ? "W" : (userGoals == otherGoals ? "D" : "L")
            HStack(spacing: 10) {
                Text(L("result.\(outcome)"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.background)
                    .frame(width: 26, height: 26)
                    .background(outcome == "W" ? Theme.positive : (outcome == "D" ? Theme.silver : Theme.negative), in: Circle())
                CrestView(club: home, size: 26)
                Text("\(result.homeGoals) - \(result.awayGoals)")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                CrestView(club: away, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("home.lastResult"))
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                    Text(userIsHome ? away.name : home.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            .gameCard(padding: 12)
        }
    }
}

/// Shown after "play week": the user's match plus the week's news.
struct WeekReportSheet: View {
    let report: WeekReport
    let onClose: (SeasonSummary?) -> Void
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let career = store.career, let fixture = report.userFixture {
                        MatchSummaryView(fixture: fixture, career: career)
                    }
                    if let career = store.career, !report.newMessages.isEmpty {
                        SectionTitle(text: L("report.news"))
                        ForEach(report.newMessages) { message in
                            MessageRow(message: message, career: career)
                                .gameCard(padding: 12)
                        }
                    }
                }
                .padding(16)
            }
            .gameBackground()
            .navigationTitle(L("report.title", String(report.matchday)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.continue")) {
                        dismiss()
                        onClose(report.finishedSeason)
                    }
                }
            }
        }
        .interactiveDismissDisabled(report.finishedSeason != nil)
    }
}
