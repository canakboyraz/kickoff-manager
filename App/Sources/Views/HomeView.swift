import SwiftUI
import GameEngine

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @State private var seasonSummary: SeasonSummary?
    @State private var pendingJob: JobOffer?

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
                clubLink()
                windowBanner(career)
                contractsBanner(career)
                ForEach(career.jobOffers) { offer in
                    VStack(alignment: .leading, spacing: 6) {
                        SectionTitle(text: L("job.offerTitle"))
                        JobOfferCard(offer: offer, career: career) {
                            pendingJob = offer
                        } onDecline: {
                            store.update { $0.declineJob(offer.id) }
                        }
                    }
                }
                if let cupMatch = career.nextUserCupMatch {
                    cupMatchBanner(cupMatch.cup, fixture: cupMatch.fixture, career: career)
                }
                nextMatchCard(career)
                if let cupMatch = career.lastUserCupMatch, cupMatch.fixture.week >= career.week - 1 {
                    NavigationLink(value: MatchLink(fixtureID: cupMatch.fixture.id)) {
                        ResultCard(homeID: cupMatch.fixture.homeID, awayID: cupMatch.fixture.awayID,
                                   result: cupMatch.fixture.result, caption: cupMatch.cup.kind.label, career: career)
                    }
                    .buttonStyle(.plain)
                }
                if let last = career.lastUserFixture {
                    NavigationLink(value: MatchLink(fixtureID: last.id)) {
                        ResultCard(homeID: last.homeID, awayID: last.awayID, result: last.result,
                                   caption: L("home.lastResult"), career: career)
                    }
                    .buttonStyle(.plain)
                }
                packsCard()
                RewardsCard()
                ManagerCard(career: career)
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
        ), onDismiss: showAdIfDue) { box in
            WeekReportSheet(report: box.report) { summary in
                seasonSummary = summary
            }
        }
        .confirmationDialog(
            L("job.confirm"),
            isPresented: Binding(get: { pendingJob != nil }, set: { if !$0 { pendingJob = nil } }),
            titleVisibility: .visible,
            presenting: pendingJob
        ) { offer in
            Button(L("job.accept")) {
                withAnimation { store.update { $0.acceptJob(offer.id) } }
            }
        } message: { offer in
            Text(L("job.confirmBody", career.club(offer.clubID)?.name ?? ""))
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
            VStack(alignment: .trailing, spacing: 6) {
                Chip(text: Fmt.money(club.finances.balance), icon: "dollarsign.circle.fill")
                Button {
                    store.profileSection = .store
                    store.selectedTab = .profile
                } label: {
                    Chip(text: L("points.short", Fmt.number(store.profile.points)), icon: "star.circle.fill", color: Theme.positive)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Club management (facilities, stadium, finances) now lives behind the club header.
    private func clubLink() -> some View {
        NavigationLink(value: ClubLink()) {
            HStack(spacing: 10) {
                Image(systemName: "building.columns.fill")
                    .foregroundStyle(Theme.goldLight)
                Text(L("home.clubManagement"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textMuted)
            }
            .gameCard(padding: 12)
        }
        .buttonStyle(.plain)
    }

    /// Packs teaser: points balance and a shortcut to the store.
    private func packsCard() -> some View {
        Button {
            store.profileSection = .store
            store.selectedTab = .profile
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PackType.all[2].gradient)
                        .frame(width: 44, height: 60)
                        .rotationEffect(.degrees(-8))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(PackType.all[3].gradient)
                        .frame(width: 44, height: 60)
                        .rotationEffect(.degrees(6))
                        .offset(x: 14)
                }
                .frame(width: 70)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("home.packs.title"))
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Text(L("home.packs.body", Fmt.number(store.profile.points)))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.goldLight)
            }
            .gameCard(padding: 12, highlight: Theme.gold.opacity(0.6))
        }
        .buttonStyle(.plain)
    }

    /// Every few played weeks an ad is shown once the match report is closed.
    private func showAdIfDue() {
        guard seasonSummary == nil, AdManager.shared.isAdDue else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            AdManager.shared.presentIfDue()
        }
    }

    /// Reminder for contracts that run out at the end of the season.
    @ViewBuilder
    private func contractsBanner(_ career: Career) -> some View {
        let expiring = career.expiringContracts
        if !expiring.isEmpty {
            NavigationLink(value: ContractsLink()) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("contracts.banner", String(expiring.count)))
                            .font(.subheadline.weight(.bold))
                        Text(L("contracts.bannerDetail", String(career.weeksUntilContractsExpire),
                               expiring.prefix(3).map(\.shortName).joined(separator: ", ")))
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(Theme.warning)
                .gameCard(padding: 10, highlight: Theme.warning.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    private func windowBanner(_ career: Career) -> some View {
        let status = career.transferWindowStatus
        let text: String
        if status.isOpen {
            text = L("home.windowOpenFor", String(status.weeksLeft ?? 0))
        } else if let opensIn = status.opensIn {
            text = L("home.windowOpensIn", String(opensIn))
        } else {
            text = L("home.windowNextSummer")
        }
        return HStack(spacing: 8) {
            Image(systemName: status.isOpen ? "arrow.left.arrow.right.circle.fill" : "lock.fill")
            Text(text)
                .lineLimit(2)
            Spacer()
            if !career.pendingOffers.isEmpty {
                Chip(text: L("home.offers", String(career.pendingOffers.count)), color: Theme.goldLight)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(status.isOpen ? Theme.positive : Theme.textMuted)
        .gameCard(padding: 10, highlight: status.isOpen ? Theme.positive.opacity(0.6) : nil)
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

            if career.needsLineupChanges {
                // The manager has to sort out the team sheet before kick-off.
                VStack(spacing: 8) {
                    Text(lineupProblem(career))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button {
                        store.selectedTab = .squad
                    } label: {
                        Label(L("home.fixLineup"), systemImage: "exclamationmark.triangle.fill")
                    }
                    .buttonStyle(GoldButtonStyle())
                }
            } else {
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
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(PitchBackground())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Midweek European game coming up this week.
    private func cupMatchBanner(_ cup: Cup, fixture: CupFixture, career: Career) -> some View {
        let opponentID = fixture.homeID == career.userClubID ? fixture.awayID : fixture.homeID
        let isHome = fixture.homeID == career.userClubID && !fixture.isNeutral
        return HStack(spacing: 12) {
            Image(systemName: cup.kind.icon)
                .font(.title2)
                .foregroundStyle(cup.kind.color)
            VStack(alignment: .leading, spacing: 3) {
                Text(L("home.midweek", cup.kind.label))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(cup.kind.color)
                Text(fixture.stageCaption)
                    .font(.caption2)
                    .foregroundStyle(Theme.textMuted)
                if let opponent = career.club(opponentID) {
                    HStack(spacing: 6) {
                        Text(isHome ? L("home.vsHome") : (fixture.isNeutral ? L("home.vsNeutral") : L("home.vsAway")))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.textSecondary)
                        CrestView(club: opponent, size: 18)
                        Text(opponent.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .gameCard(padding: 12, highlight: cup.kind.color.opacity(0.6))
    }

    private func lineupProblem(_ career: Career) -> String {
        let names = career.unavailableStarters.map(\.shortName).joined(separator: ", ")
        if !names.isEmpty {
            return L("home.unavailableStarters", names)
        }
        return L("home.emptySlots", String(career.emptyStarterSlots))
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
                                    PlayerCardView(player: player)
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
            squadNews(career)
            ForEach(career.inbox.suffix(5).reversed()) { message in
                MessageRow(message: message, career: career)
                    .gameCard(padding: 12, highlight: message.isRead ? nil : Theme.gold.opacity(0.5))
            }
        }
    }

    /// Injured and suspended players at a glance.
    @ViewBuilder
    private func squadNews(_ career: Career) -> some View {
        let out = career.userSquad.filter { !$0.isAvailable }
        if !out.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label(L("home.squadNews"), systemImage: "cross.case.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.negative)
                ForEach(out) { player in
                    NavigationLink(value: PlayerLink(id: player.id)) {
                        HStack(spacing: 8) {
                            Image(systemName: player.isInjured ? "cross.case.fill" : "rectangle.portrait.fill")
                                .foregroundStyle(Theme.negative)
                                .frame(width: 18)
                            Text(player.shortName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(player.position.shortLabel)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(player.isInjured
                                 ? L("home.injuredFor", String(player.injuryWeeks))
                                 : L("home.suspendedFor", String(player.suspendedMatches)))
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .gameCard(padding: 12, highlight: Theme.negative.opacity(0.5))
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
    let homeID: UUID
    let awayID: UUID
    let result: MatchResult?
    let caption: String
    let career: Career

    var body: some View {
        if let result, let home = career.club(homeID), let away = career.club(awayID) {
            let userIsHome = homeID == career.userClubID
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
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
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
                    if store.profile.lastEarned > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "star.circle.fill")
                            Text(L("report.points", Fmt.number(store.profile.lastEarned)))
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Text(L("points.short", Fmt.number(store.profile.points)))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .foregroundStyle(Theme.positive)
                        .gameCard(padding: 10, highlight: Theme.positive.opacity(0.5))
                    }
                    if let career = store.career, let fixture = report.userCupFixture, let kind = report.userCupKind {
                        let match = career.cupMatch(fixture.id)
                        MatchSummaryView(cupFixture: match?.fixture ?? fixture, kind: kind, cup: match?.cup, career: career)
                    }
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
