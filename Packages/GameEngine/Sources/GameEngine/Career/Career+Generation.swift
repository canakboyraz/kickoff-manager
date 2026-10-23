import Foundation

extension Career {
    /// Builds a fresh world: five fictional leagues, 18 clubs each, 24 players per club.
    /// The user picks a club afterwards with `chooseClub(_:)`.
    public static func generate(seed: UInt64, season: Int = 2026) -> Career {
        var rng = SeededRandom(seed: seed)
        var leagues: [League] = []
        var clubs: [UUID: Club] = [:]
        var players: [UUID: Player] = [:]

        for country in WorldData.countries {
            let leagueID = UUID()
            var clubIDs: [UUID] = []
            let topReputation = 45 + country.strength * 47

            for (index, clubSeed) in country.clubs.enumerated() {
                let reputation = Int((topReputation - Double(index) * rng.double(2.4...3.2)).rounded()).clamped(to: 20...95)
                let clubID = UUID()
                let squad = makeSquad(
                    clubID: clubID,
                    reputation: reputation,
                    countryCode: country.code,
                    season: season,
                    rng: &rng
                )
                for player in squad { players[player.id] = player }

                let wageBill = squad.map(\.contract.weeklyWage).reduce(0, +)
                let transferBudget = baseTransferBudget(reputation: reputation)
                let capacity = roundTo(Double(8_000 + reputation * 480 + rng.int(-4_000...4_000)), step: 500)
                let facilityBase = 1 + reputation / 12
                let formation = pickFormation(&rng)

                let club = Club(
                    id: clubID,
                    name: clubSeed.name,
                    shortName: clubSeed.shortName,
                    countryCode: country.code,
                    leagueID: leagueID,
                    reputation: reputation,
                    colors: ClubColors(primary: clubSeed.primary, secondary: clubSeed.secondary),
                    formation: formation,
                    stadium: Stadium(name: clubSeed.stadium, capacity: capacity, ticketPrice: fairTicketPrice(reputation: reputation)),
                    facilities: Facilities(
                        training: (facilityBase + rng.int(-1...1)).clamped(to: 1...Facilities.maxLevel),
                        youth: (facilityBase + rng.int(-1...1)).clamped(to: 1...Facilities.maxLevel),
                        medical: (facilityBase + rng.int(-1...1)).clamped(to: 1...Facilities.maxLevel)
                    ),
                    finances: Finances(
                        balance: transferBudget + transferBudget / 2 + 2_000_000,
                        transferBudget: transferBudget,
                        wageBudget: roundTo(Double(wageBill) * 1.12, step: 1_000)
                    ),
                    playerIDs: squad.map(\.id),
                    upgrades: []
                )
                clubs[clubID] = club
                clubIDs.append(clubID)
            }

            leagues.append(League(
                id: leagueID,
                name: country.leagueName,
                countryCode: country.code,
                strength: country.strength,
                clubIDs: clubIDs,
                fixtures: Scheduler.doubleRoundRobin(clubIDs: clubIDs, rng: &rng)
            ))
        }

        var career = Career(
            version: Career.currentVersion,
            season: season,
            week: 0,
            userClubID: leagues[0].clubIDs[0],
            leagues: leagues,
            clubs: clubs,
            players: players,
            inbox: [],
            offers: [],
            history: [],
            userTactics: Tactics(formation: .f433, starters: [], bench: []),
            talks: [:],
            cups: [],
            manager: Manager(reputation: 40, boardConfidence: 60, trophies: 0, timesSacked: 0, seasonsManaged: 0, warningLevel: 0),
            jobOffers: [],
            isUnemployed: false,
            rng: rng
        )

        // In the first season the most reputable clubs play in Europe ("last season's" top places).
        let rankings = leagues.map { league in
            (strength: league.strength,
             order: league.clubIDs.sorted { (clubs[$0]?.reputation ?? 0) > (clubs[$1]?.reputation ?? 0) })
        }
        career.setUpCups(qualifiers: Career.europeanQualifiers(rankings: rankings))
        career.seedFreeAgents(count: 60, season: season)
        return career
    }

    /// Sets the club the user manages, picks a starting eleven and posts the board's welcome.
    public mutating func chooseClub(_ clubID: UUID) {
        guard let club = clubs[clubID] else { return }
        userClubID = clubID
        inbox.removeAll()
        offers.removeAll()
        talks.removeAll()
        scoutMissions.removeAll()
        scoutReports.removeAll()
        userTactics = Tactics(formation: club.formation, starters: [], bench: [])
        autoPickLineup()
        manager = Manager.starting(at: club)
        jobOffers.removeAll()
        isUnemployed = false
        post(.boardWelcome)
        if let cup = cups.first(where: { $0.clubIDs.contains(clubID) }) {
            post(.cupQualified(kind: cup.kind, season: season))
        }
        generateIncomingOffers()
    }

    static func pickFormation(_ rng: inout SeededRandom) -> Formation {
        let options: [(formation: Formation, weight: Double)] = [
            (.f433, 3), (.f442, 3), (.f4231, 3), (.f352, 1), (.f532, 1)
        ]
        let index = rng.weightedIndex(options.map { $0.weight }) ?? 0
        return options[index].formation
    }

    // MARK: - Helpers

    static func makeSquad(
        clubID: UUID,
        reputation: Int,
        countryCode: String,
        season: Int,
        rng: inout SeededRandom
    ) -> [Player] {
        let average = averageOverall(reputation: reputation)
        var squad: [Player] = []
        for (position, count) in PlayerGenerator.squadTemplate {
            let starters = starterCount(for: position)
            for slot in 0..<count {
                let isStarter = slot < starters
                var age = PlayerGenerator.randomAge(rng: &rng)
                var offset = isStarter ? 3.0 : -3.0
                if !isStarter && rng.chance(0.3) {
                    age = rng.int(17...20)
                    offset -= 4
                }
                let target = Int((average + offset + rng.normal(sd: 3)).rounded())
                let nationality = NamePools.randomNationality(domestic: countryCode, domesticShare: 0.68, rng: &rng)
                squad.append(PlayerGenerator.make(
                    position: position,
                    targetOverall: target,
                    age: age,
                    nationality: nationality,
                    season: season,
                    clubID: clubID,
                    rng: &rng
                ))
            }
        }
        return squad
    }

    static func starterCount(for position: Position) -> Int {
        Formation.f433.slots.filter { $0 == position }.count
    }

    static func averageOverall(reputation: Int) -> Double {
        48 + Double(reputation) * 0.34
    }

    static func baseTransferBudget(reputation: Int) -> Int {
        roundTo(pow(Double(reputation) / 10, 3) * 60_000, step: 100_000)
    }

    static func fairTicketPrice(reputation: Int) -> Int {
        Int((12 + Double(reputation) * 0.45).rounded())
    }

    static func roundTo(_ value: Double, step: Int) -> Int {
        Int((value / Double(step)).rounded()) * step
    }
}
