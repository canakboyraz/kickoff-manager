import Foundation

extension Career {
    /// Plays the next matchday in every league and runs the weekly systems
    /// (injuries, finances, upgrades, development, transfer offers).
    /// After the last matchday the season is closed and the next one starts automatically.
    @discardableResult
    public mutating func advanceWeek() -> WeekReport {
        let inboxStart = inbox.map(\.id)
        let matchday = week + 1

        for leagueIndex in leagues.indices {
            for fixtureIndex in leagues[leagueIndex].fixtures.indices {
                let fixture = leagues[leagueIndex].fixtures[fixtureIndex]
                if fixture.matchday == matchday && fixture.result == nil {
                    playFixture(leagueIndex: leagueIndex, fixtureIndex: fixtureIndex)
                }
            }
        }
        week = matchday

        // Players hurt this week keep their full injury length; everyone else heals one week.
        let injuredNow = Set(leagues.flatMap { $0.fixtures(on: matchday) }
            .compactMap(\.result)
            .flatMap(\.events)
            .filter { $0.kind == .injury }
            .map(\.playerID))
        tickInjuries(excluding: injuredNow)

        weeklyFinances()
        tickUpgrades()
        if matchday % 4 == 0 { developmentTick() }
        if matchday == max(1, matchdayCount - 8) { warnAboutExpiringContracts() }
        expireOffers()
        generateIncomingOffers()

        let userFixture = userLeague.fixtures.first { $0.matchday == matchday && $0.involves(userClubID) }

        var summary: SeasonSummary?
        if week >= matchdayCount {
            summary = closeSeason()
            startNewSeason()
        }

        let known = Set(inboxStart)
        return WeekReport(
            matchday: matchday,
            userFixture: userFixture,
            newMessages: inbox.filter { !known.contains($0.id) },
            finishedSeason: summary
        )
    }

    // MARK: - Matches

    mutating func playFixture(leagueIndex: Int, fixtureIndex: Int) {
        let fixture = leagues[leagueIndex].fixtures[fixtureIndex]
        guard let home = clubs[fixture.homeID], let away = clubs[fixture.awayID] else { return }
        let homeSquad = squad(of: home.id)
        let awaySquad = squad(of: away.id)

        var generator = rng
        let outcome = MatchEngine.play(home: home, away: away, homeSquad: homeSquad, awaySquad: awaySquad, rng: &generator)
        rng = generator

        let result = outcome.result
        leagues[leagueIndex].fixtures[fixtureIndex].result = result

        var goals: [UUID: Int] = [:]
        var assists: [UUID: Int] = [:]
        for event in result.events where event.kind == .goal {
            goals[event.playerID, default: 0] += 1
            if let assistID = event.assistID { assists[assistID, default: 0] += 1 }
        }

        var played = Set<UUID>()
        for rating in result.ratings {
            played.insert(rating.playerID)
            players[rating.playerID]?.recordMatch(
                rating: rating.rating,
                goals: goals[rating.playerID] ?? 0,
                assists: assists[rating.playerID] ?? 0
            )
        }

        applyMorale(clubID: home.id, scored: result.homeGoals, conceded: result.awayGoals, played: played)
        applyMorale(clubID: away.id, scored: result.awayGoals, conceded: result.homeGoals, played: played)

        for injury in outcome.injuries {
            players[injury.playerID]?.injuryWeeks = injury.weeks
            if players[injury.playerID]?.clubID == userClubID {
                post(.injury(playerID: injury.playerID, weeks: injury.weeks))
            }
        }

        let gate = result.attendance * home.stadium.ticketPrice
        clubs[home.id]?.finances.balance += gate
        clubs[home.id]?.finances.seasonIncome += gate
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

    mutating func tickInjuries(excluding excluded: Set<UUID>) {
        for id in players.keys where (players[id]?.injuryWeeks ?? 0) > 0 && !excluded.contains(id) {
            players[id]?.injuryWeeks -= 1
        }
    }

    // MARK: - Finances and upgrades

    mutating func weeklyFinances() {
        for clubID in clubs.keys {
            guard let club = clubs[clubID] else { continue }
            let wages = wageBill(of: clubID)
            let commercial = club.weeklyCommercialIncome
            clubs[clubID]?.finances.balance += commercial - wages
            clubs[clubID]?.finances.seasonIncome += commercial
            clubs[clubID]?.finances.seasonExpenses += wages
        }
    }

    mutating func tickUpgrades() {
        for clubID in clubs.keys {
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

    mutating func closeSeason() -> SeasonSummary? {
        var userSummary: SeasonSummary?

        for league in leagues {
            let table = league.table()
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
                        prizeMoney: prize
                    )
                    history.append(summary)
                    userSummary = summary
                    post(.seasonEnded(season: season, position: index + 1, prizeMoney: prize))
                }
            }
        }

        // The board sets new budgets from reputation and cash in the bank.
        for clubID in clubs.keys {
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
        return userSummary
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
            if player.clubID == userClubID {
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
        for clubID in clubs.keys where clubID != userClubID {
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

    mutating func startNewSeason() {
        season += 1
        week = 0
        for index in leagues.indices {
            leagues[index].fixtures = Scheduler.doubleRoundRobin(clubIDs: leagues[index].clubIDs, rng: &rng)
        }
        for id in players.keys {
            players[id]?.stats = SeasonStats()
        }
        for id in clubs.keys {
            clubs[id]?.finances.seasonIncome = 0
            clubs[id]?.finances.seasonExpenses = 0
        }
        offers.removeAll { $0.status != .pending }
    }
}
