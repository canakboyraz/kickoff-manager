import Foundation

public struct SeasonSummary: Codable, Hashable, Sendable {
    public var season: Int
    public var leagueName: String
    public var position: Int
    public var points: Int
    public var prizeMoney: Int
    /// European cup the club played in that season, and how far it got.
    public var europe: CompetitionKind?
    public var europeStage: CupStage?
}

/// What happened when the user pressed "play week".
public struct WeekReport: Sendable {
    public var matchday: Int
    public var userFixture: Fixture?
    /// The user's midweek cup game, if there was one.
    public var userCupFixture: CupFixture?
    public var userCupKind: CompetitionKind?
    public var newMessages: [InboxMessage]
    /// Set when this week was the last matchday; the next season has already started.
    public var finishedSeason: SeasonSummary?
}

extension Career {
    /// Plays the coming week: a midweek European round (if scheduled), then the league
    /// matchday in every league, then the weekly systems (fitness, injuries, finances,
    /// upgrades, development, transfer offers). After the last matchday the season is
    /// closed and the next one starts automatically.
    @discardableResult
    public mutating func advanceWeek() -> WeekReport {
        let known = Set(inbox.map(\.id))
        let matchday = week + 1
        // A sacked manager has no team to play with until a new job is accepted.
        guard !isUnemployed else {
            return WeekReport(matchday: week, userFixture: nil, userCupFixture: nil, userCupKind: nil,
                              newMessages: [], finishedSeason: nil)
        }
        normalizeUserTactics()
        var injuredThisWeek = Set<UUID>()

        let hasCupGames = cups.contains { cup in
            cup.fixtures.contains { $0.week == matchday && $0.result == nil }
        }
        if hasCupGames {
            // Two games in a week: only half a week to recover before each.
            recoverFitness(fraction: 0.5)
            injuredThisWeek.formUnion(playCupMatches(week: matchday))
            updateCupBrackets()
            recoverFitness(fraction: 0.5)
        } else {
            recoverFitness(fraction: 1)
        }

        for leagueIndex in leagues.indices {
            for fixtureIndex in leagues[leagueIndex].fixtures.indices {
                let fixture = leagues[leagueIndex].fixtures[fixtureIndex]
                guard fixture.matchday == matchday, fixture.result == nil else { continue }
                injuredThisWeek.formUnion(playLeagueFixture(leagueIndex: leagueIndex, fixtureIndex: fixtureIndex))
            }
        }
        week = matchday
        announceTransferWindows()
        if matchday % 4 == 0 { reviewLeaguePosition() }
        checkJobSecurity()
        expireJobOffers()
        if matchday == matchdayCount / 2 { considerJobOffers(seasonEnd: false) }

        tickInjuries(excluding: injuredThisWeek)
        weeklyFinances()
        tickUpgrades()
        if matchday % 4 == 0 { developmentTick() }
        if matchday == max(1, matchdayCount - 8) { warnAboutExpiringContracts() }
        // Talks start over when the winter window opens.
        if matchday == matchdayCount / 2 { talks.removeAll() }
        expireOffers()
        generateIncomingOffers()

        let userFixture = userLeague.fixtures.first { $0.matchday == matchday && $0.involves(userClubID) }
        var userCupFixture: CupFixture?
        var userCupKind: CompetitionKind?
        for cup in cups {
            if let fixture = cup.fixtures.first(where: { $0.week == matchday && $0.involves(userClubID) }) {
                userCupFixture = fixture
                userCupKind = cup.kind
            }
        }

        var summary: SeasonSummary?
        if week >= matchdayCount {
            let closing = closeSeason()
            summary = closing.summary
            startNewSeason(qualifiers: closing.qualifiers)
            considerJobOffers(seasonEnd: true)
            generateIncomingOffers()
        }
        normalizeUserTactics()

        return WeekReport(
            matchday: matchday,
            userFixture: userFixture,
            userCupFixture: userCupFixture,
            userCupKind: userCupKind,
            newMessages: inbox.filter { !known.contains($0.id) },
            finishedSeason: summary
        )
    }

    // MARK: - Matches

    mutating func playLeagueFixture(leagueIndex: Int, fixtureIndex: Int) -> Set<UUID> {
        let fixture = leagues[leagueIndex].fixtures[fixtureIndex]
        guard let home = clubs[fixture.homeID], let away = clubs[fixture.awayID] else { return [] }
        let homeSheet = teamSheet(for: home.id)
        let awaySheet = teamSheet(for: away.id)

        var generator = rng
        let outcome = MatchEngine.play(home: home, away: away, homeSheet: homeSheet, awaySheet: awaySheet, rng: &generator)
        rng = generator

        leagues[leagueIndex].fixtures[fixtureIndex].result = outcome.result
        if home.id == userClubID {
            updateBoardAfterMatch(scored: outcome.result.homeGoals, conceded: outcome.result.awayGoals, opponentID: away.id)
        } else if away.id == userClubID {
            updateBoardAfterMatch(scored: outcome.result.awayGoals, conceded: outcome.result.homeGoals, opponentID: home.id)
        }
        let gate = outcome.result.attendance * home.stadium.ticketPrice
        clubs[home.id]?.finances.balance += gate
        clubs[home.id]?.finances.seasonIncome += gate
        return applyOutcome(outcome, homeID: home.id, awayID: away.id)
    }

    /// Stats, fitness, morale and injuries after a match. Returns players injured in it.
    mutating func applyOutcome(_ outcome: MatchEngine.Outcome, homeID: UUID, awayID: UUID) -> Set<UUID> {
        let result = outcome.result
        var played = Set<UUID>()
        for appearance in outcome.appearances {
            played.insert(appearance.playerID)
            guard var player = players[appearance.playerID] else { continue }
            player.recordMatch(rating: appearance.rating, goals: appearance.goals, assists: appearance.assists)
            // Physically strong players tire less.
            let cost = Double(appearance.minutes) / 90 * (24 - Double(player.attributes.physical) * 0.12)
            player.fitness = max(0, player.fitness - Int(cost.rounded()))
            players[appearance.playerID] = player
        }
        applyMorale(clubID: homeID, scored: result.homeGoals, conceded: result.awayGoals, played: played)
        applyMorale(clubID: awayID, scored: result.awayGoals, conceded: result.homeGoals, played: played)

        for injury in outcome.injuries {
            players[injury.playerID]?.injuryWeeks = injury.weeks
            if players[injury.playerID]?.clubID == userClubID {
                post(.injury(playerID: injury.playerID, weeks: injury.weeks))
            }
        }

        // Banned players who sat this game out have served one match.
        for clubID in [homeID, awayID] {
            for playerID in clubs[clubID]?.playerIDs ?? [] where (players[playerID]?.suspendedMatches ?? 0) > 0 && !played.contains(playerID) {
                players[playerID]?.suspendedMatches -= 1
            }
        }
        applyBookings(outcome.bookings)
        return Set(outcome.injuries.map(\.playerID))
    }

    /// Red card: 1 match for two yellows, 1–3 for a straight red. Every fifth yellow: 1 match.
    mutating func applyBookings(_ bookings: [MatchEngine.Booking]) {
        for booking in bookings {
            guard var player = players[booking.playerID] else { continue }
            var ban = 0
            var reason = SuspensionReason.yellowCards
            if booking.isRed {
                ban = booking.isSecondYellow ? 1 : rng.int(1...3)
                reason = booking.isSecondYellow ? .secondYellow : .redCard
            } else {
                player.yellowCards += 1
                if player.yellowCards % 5 == 0 { ban = 1 }
            }
            if ban > 0 {
                player.suspendedMatches += ban
                if player.clubID == userClubID {
                    post(.suspension(playerID: player.id, matches: ban, reason: reason))
                }
            }
            players[booking.playerID] = player
        }
    }

    mutating func applyMorale(clubID: UUID, scored: Int, conceded: Int, played: Set<UUID>) {
        let change = scored > conceded ? 4 : (scored == conceded ? 0 : -4)
        for playerID in clubs[clubID]?.playerIDs ?? [] {
            guard var player = players[playerID] else { continue }
            if played.contains(playerID) {
                player.morale = (player.morale + change).clamped(to: 0...100)
            } else if !player.isInjured {
                // Players left out drift slowly towards unhappy.
                player.morale = (player.morale + (player.morale > 50 ? -1 : 0)).clamped(to: 0...100)
            }
            players[playerID] = player
        }
    }

    // MARK: - Weekly systems

    /// Recovery between games. A better medical centre and strong physique speed it up.
    mutating func recoverFitness(fraction: Double) {
        for id in Array(players.keys) {
            guard var player = players[id], player.fitness < 100 else { continue }
            let medical = player.clubID.flatMap { clubs[$0]?.facilities.medical } ?? 3
            let amount = (17 + Double(medical) * 0.5 + Double(player.attributes.physical - 60) * 0.05) * fraction
            player.fitness = min(100, player.fitness + max(1, Int(amount.rounded())))
            players[id] = player
        }
    }

    mutating func tickInjuries(excluding excluded: Set<UUID>) {
        for id in Array(players.keys) where (players[id]?.injuryWeeks ?? 0) > 0 && !excluded.contains(id) {
            players[id]?.injuryWeeks -= 1
        }
    }

    mutating func weeklyFinances() {
        for clubID in Array(clubs.keys) {
            guard let club = clubs[clubID] else { continue }
            let wages = wageBill(of: clubID)
            let commercial = club.weeklyCommercialIncome
            clubs[clubID]?.finances.balance += commercial - wages
            clubs[clubID]?.finances.seasonIncome += commercial
            clubs[clubID]?.finances.seasonExpenses += wages
        }
    }

    mutating func tickUpgrades() {
        for clubID in Array(clubs.keys) {
            guard var club = clubs[clubID], !club.upgrades.isEmpty else { continue }
            var finished: [FacilityKind] = []
            for index in club.upgrades.indices {
                club.upgrades[index].weeksRemaining -= 1
                if club.upgrades[index].weeksRemaining <= 0 {
                    finished.append(club.upgrades[index].kind)
                }
            }
            club.upgrades.removeAll { $0.weeksRemaining <= 0 }
            for kind in finished {
                if kind == .stadium {
                    club.stadium.capacity = min(Career.maxStadiumCapacity, club.stadium.capacity + Career.stadiumExpansionSeats)
                } else {
                    club.facilities.raise(kind)
                }
                if clubID == userClubID { post(.upgradeCompleted(kind: kind)) }
            }
            clubs[clubID] = club
        }
    }

    mutating func warnAboutExpiringContracts() {
        for player in userSquad where player.contract.expiresSeason <= season {
            post(.contractExpiring(playerID: player.id))
        }
    }


    // MARK: - End of season

    mutating func closeSeason() -> (summary: SeasonSummary?, qualifiers: [CompetitionKind: [UUID]]) {
        var userSummary: SeasonSummary?
        var rankings: [(strength: Double, order: [UUID])] = []
        let userCup = self.userCup

        for league in leagues {
            let table = league.table()
            rankings.append((strength: league.strength, order: table.map(\.clubID)))
            let expectedOrder = league.clubIDs.sorted { (clubs[$0]?.reputation ?? 0) > (clubs[$1]?.reputation ?? 0) }
            for (index, row) in table.enumerated() {
                let prize = Career.roundTo(league.strength * (20_000_000 - Double(index) * 900_000), step: 50_000)
                clubs[row.clubID]?.finances.balance += prize
                clubs[row.clubID]?.finances.seasonIncome += prize

                // Beating expectations raises reputation, falling short lowers it.
                let expected = expectedOrder.firstIndex(of: row.clubID) ?? index
                let delta = ((expected - index) / 3).clamped(to: -3...3)
                if let reputation = clubs[row.clubID]?.reputation {
                    clubs[row.clubID]?.reputation = (reputation + delta).clamped(to: 20...95)
                }

                if row.clubID == userClubID {
                    let summary = SeasonSummary(
                        season: season,
                        leagueName: league.name,
                        position: index + 1,
                        points: row.points,
                        prizeMoney: prize,
                        europe: userCup?.kind,
                        europeStage: userCup?.stageReached(by: userClubID)
                    )
                    history.append(summary)
                    userSummary = summary
                    post(.seasonEnded(season: season, position: index + 1, prizeMoney: prize))
                    reviewSeason(expected: expected + 1, position: index + 1)
                }
            }
        }

        let qualifiers = Career.europeanQualifiers(rankings: rankings)
        for kind in CompetitionKind.allCases where qualifiers[kind]?.contains(userClubID) == true {
            post(.cupQualified(kind: kind, season: season + 1))
        }

        // The board sets new budgets from reputation and cash in the bank.
        for clubID in Array(clubs.keys) {
            guard let club = clubs[clubID] else { continue }
            let base = Career.baseTransferBudget(reputation: club.reputation)
            let fromCash = max(0, club.finances.balance) / 6
            clubs[clubID]?.finances.transferBudget = Career.roundTo(Double(base / 2 + fromCash), step: 100_000)
            let wages = wageBill(of: clubID)
            clubs[clubID]?.finances.wageBudget = Career.roundTo(Double(max(wages, club.finances.wageBudget)) * 1.05, step: 1_000)
        }

        handleRetirementsAndContracts()
        youthIntake()
        maintainAISquads()
        return (summary: userSummary, qualifiers: qualifiers)
    }

    mutating func handleRetirementsAndContracts() {
        let nextSeason = season + 1
        for id in Array(players.keys) {
            guard let player = players[id] else { continue }
            let age = player.age(in: nextSeason)
            let retireChance: Double
            switch age {
            case ..<34: retireChance = 0
            case 34...35: retireChance = 0.35
            case 36...37: retireChance = 0.75
            default: retireChance = 1
            }
            if rng.chance(retireChance) {
                removePlayer(id, leftTo: nil, fee: 0)
                continue
            }

            guard player.contract.expiresSeason <= season else { continue }
            if player.clubID == userClubID && !isUnemployed {
                // Contracts the user didn't renew run out: the player leaves for free.
                removePlayer(id, leftTo: nil, fee: 0)
            } else if rng.chance(0.85) {
                players[id]?.contract = Contract(
                    weeklyWage: player.expectedWage(season: nextSeason),
                    expiresSeason: nextSeason + rng.int(1...3)
                )
            } else {
                removePlayer(id, leftTo: nil, fee: 0)
            }
        }
    }

    /// Removes a player from his club. Without a destination he leaves the game world.
    mutating func removePlayer(_ playerID: UUID, leftTo destination: UUID?, fee: Int) {
        guard let player = players[playerID] else { return }
        if let clubID = player.clubID {
            clubs[clubID]?.playerIDs.removeAll { $0 == playerID }
            if clubID == userClubID {
                post(.playerLeft(playerID: playerID, toClubID: destination, fee: fee))
            }
        }
        if destination == nil {
            // Keep the record when the user's player left, so old messages can still show his name.
            if player.clubID == userClubID {
                players[playerID]?.clubID = nil
            } else {
                players.removeValue(forKey: playerID)
            }
        }
    }

    mutating func youthIntake() {
        let nextSeason = season + 1
        for clubID in clubs.keys {
            guard let club = clubs[clubID] else { continue }
            let count = 2 + club.facilities.youth / 4
            var newIDs: [UUID] = []
            for _ in 0..<count {
                let template = PlayerGenerator.squadTemplate
                let index = rng.weightedIndex(template.map { Double($0.count) }) ?? 0
                let position = template[index].position
                let target = Int((38 + Double(club.facilities.youth) * 2 + rng.normal(sd: 4)).rounded())
                let nationality = NamePools.randomNationality(domestic: club.countryCode, domesticShare: 0.85, rng: &rng)
                var player = PlayerGenerator.make(
                    position: position,
                    targetOverall: target,
                    age: rng.int(16...17),
                    nationality: nationality,
                    season: nextSeason,
                    clubID: clubID,
                    rng: &rng
                )
                player.potential = min(95, player.potential + Int(Double(club.facilities.youth) * 0.8))
                player.contract = Contract(weeklyWage: 1_000 + club.reputation * 10, expiresSeason: nextSeason + 3)
                players[player.id] = player
                newIDs.append(player.id)
            }
            clubs[clubID]?.playerIDs.append(contentsOf: newIDs)
            if clubID == userClubID { post(.youthIntake(playerIDs: newIDs)) }
        }
    }

    /// AI clubs top up thin squads and release surplus players so the world stays healthy.
    mutating func maintainAISquads() {
        let nextSeason = season + 1
        for clubID in clubs.keys where clubID != userClubID || isUnemployed {
            guard let club = clubs[clubID] else { continue }
            let average = Career.averageOverall(reputation: club.reputation)

            for (position, wanted) in PlayerGenerator.squadTemplate {
                let have = squad(of: clubID).filter { $0.position == position }.count
                guard have < wanted else { continue }
                for _ in have..<wanted {
                    let nationality = NamePools.randomNationality(domestic: club.countryCode, domesticShare: 0.6, rng: &rng)
                    let player = PlayerGenerator.make(
                        position: position,
                        targetOverall: Int((average + rng.normal(sd: 4)).rounded()),
                        age: PlayerGenerator.randomAge(rng: &rng),
                        nationality: nationality,
                        season: nextSeason,
                        clubID: clubID,
                        rng: &rng
                    )
                    players[player.id] = player
                    clubs[clubID]?.playerIDs.append(player.id)
                }
            }

            let current = squad(of: clubID)
            if current.count > 28 {
                let surplus = current
                    .sorted { ($0.overall, -$0.birthYear) < ($1.overall, -$1.birthYear) }
                    .prefix(current.count - 28)
                for player in surplus { removePlayer(player.id, leftTo: nil, fee: 0) }
            }
        }
    }

    mutating func startNewSeason(qualifiers: [CompetitionKind: [UUID]]) {
        season += 1
        week = 0
        for index in leagues.indices {
            leagues[index].fixtures = Scheduler.doubleRoundRobin(clubIDs: leagues[index].clubIDs, rng: &rng)
        }
        for id in Array(players.keys) {
            players[id]?.stats = SeasonStats()
            players[id]?.yellowCards = 0
            // Pre-season gets everyone fit again.
            players[id]?.fitness = 100
        }
        for id in Array(clubs.keys) {
            clubs[id]?.finances.seasonIncome = 0
            clubs[id]?.finances.seasonExpenses = 0
            clubs[id]?.finances.seasonEuropeIncome = 0
        }
        offers.removeAll { $0.status != .pending }
        talks.removeAll()
        setUpCups(qualifiers: qualifiers)
        if !isUnemployed {
            post(.transferWindowOpened(winter: false, weeks: Career.summerWindowWeeks))
        }
    }
}
