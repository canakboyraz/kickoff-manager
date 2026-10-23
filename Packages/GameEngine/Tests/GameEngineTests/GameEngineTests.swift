import XCTest
@testable import GameEngine

final class GameEngineTests: XCTestCase {
    // MARK: - World

    func testWorldGeneration() {
        let career = Career.generate(seed: 42)
        XCTAssertEqual(career.leagues.count, 5)
        for league in career.leagues {
            XCTAssertEqual(league.clubIDs.count, 18)
            XCTAssertEqual(league.matchdayCount, 34)
            XCTAssertEqual(league.fixtures.count, 18 * 17)
        }
        XCTAssertEqual(career.clubs.count, 90)
        XCTAssertEqual(career.players.values.filter { $0.clubID != nil }.count, 90 * 24)
        XCTAssertEqual(career.freeAgentCount, 60)
        XCTAssertTrue(career.players.values.allSatisfy { $0.fitness == 100 && !$0.isTransferListed })
    }

    func testEveryClubPlaysOncePerMatchday() {
        let career = Career.generate(seed: 7)
        for league in career.leagues {
            for matchday in 1...league.matchdayCount {
                let ids = league.fixtures(on: matchday).flatMap { [$0.homeID, $0.awayID] }
                XCTAssertEqual(Set(ids).count, 18, "matchday \(matchday)")
            }
            let pairs = league.fixtures.map { "\($0.homeID)-\($0.awayID)" }
            XCTAssertEqual(Set(pairs).count, league.fixtures.count)
        }
    }

    func testGeneratedOverallsLookRealistic() {
        let career = Career.generate(seed: 3)
        let overalls = career.players.values.map(\.overall)
        XCTAssertGreaterThan(overalls.min() ?? 0, 30)
        XCTAssertLessThan(overalls.max() ?? 100, 96)
        for player in career.players.values {
            XCTAssertGreaterThanOrEqual(player.potential, player.overall)
            XCTAssertEqual(player.topAttributes.count, 3)
        }
    }

    // MARK: - Matches

    func testStrongerTeamsWinMoreOften() {
        let career = Career.generate(seed: 11)
        let league = career.leagues[1]
        let strongest = league.clubIDs.max { career.clubs[$0]!.reputation < career.clubs[$1]!.reputation }!
        let weakest = league.clubIDs.min { career.clubs[$0]!.reputation < career.clubs[$1]!.reputation }!
        let strongSheet = Selection.autoSheet(squad: career.squad(of: strongest), formation: .f433)
        let weakSheet = Selection.autoSheet(squad: career.squad(of: weakest), formation: .f433)
        var rng = SeededRandom(seed: 99)
        var strongWins = 0
        var weakWins = 0
        var substitutions = 0
        for _ in 0..<200 {
            let outcome = MatchEngine.play(
                home: career.clubs[strongest]!, away: career.clubs[weakest]!,
                homeSheet: strongSheet, awaySheet: weakSheet, rng: &rng
            )
            if outcome.result.homeGoals > outcome.result.awayGoals { strongWins += 1 }
            if outcome.result.homeGoals < outcome.result.awayGoals { weakWins += 1 }
            substitutions += outcome.result.events.filter { $0.kind == .substitution }.count
            let minutes = outcome.result.ratings.filter { $0.clubID == strongest }.map(\.minutes).reduce(0, +)
            let sentOff = outcome.result.events.contains { $0.kind == .redCard && $0.clubID == strongest }
            if sentOff {
                XCTAssertLessThan(minutes, 11 * 90, "a red card leaves the team with ten men")
            } else {
                XCTAssertEqual(minutes, 11 * 90, "minutes on the pitch add up to eleven full players")
            }
        }
        XCTAssertGreaterThan(strongWins, weakWins * 3)
        XCTAssertGreaterThan(substitutions, 200 * 2 * 2 - 1)
    }

    func testTiredPlayersAreWorse() {
        let career = Career.generate(seed: 12)
        var player = career.userSquad.first { $0.position == .striker }!
        let fresh = Selection.rating(of: player, in: .striker)
        player.fitness = 55
        XCTAssertLessThan(Selection.rating(of: player, in: .striker), fresh - 5)
    }

    // MARK: - Lineup

    func testUserLineupEditing() {
        var career = Career.generate(seed: 21)
        career.chooseClub(career.leagues[0].clubIDs[4])
        XCTAssertEqual(career.userStarters.compactMap { $0 }.count, 11)
        XCTAssertEqual(career.userBench.count, Tactics.benchSize)

        // Bring a reserve into the side.
        let reserve = career.userReserves.first!
        let replaced = career.userStarters[3]!
        career.swapLineup(.starter(3), .reserve(reserve.id))
        XCTAssertEqual(career.userStarters[3]?.id, reserve.id)
        XCTAssertTrue(career.userReserves.contains { $0.id == replaced.id })

        // Swap a starter with a substitute.
        let sub = career.userBench[0]
        career.swapLineup(.bench(0), .starter(0))
        XCTAssertEqual(career.userStarters[0]?.id, sub.id)
        XCTAssertFalse(career.userBench.contains { $0.id == sub.id })

        // The team sheet uses exactly the chosen eleven when everyone is fit.
        let sheet = career.teamSheet(for: career.userClubID)
        XCTAssertEqual(sheet.starters.map(\.player.id), career.userStarters.compactMap { $0?.id })

        // Changing formation keeps eleven starters.
        career.setFormation(.f352)
        XCTAssertEqual(career.userTactics.formation, .f352)
        XCTAssertEqual(career.userStarters.compactMap { $0 }.count, 11)
    }

    func testInjuredStarterIsReplacedAtKickOff() {
        var career = Career.generate(seed: 22)
        career.chooseClub(career.leagues[0].clubIDs[2])
        let starter = career.userStarters[5]!
        career.players[starter.id]?.injuryWeeks = 3
        let sheet = career.teamSheet(for: career.userClubID)
        XCTAssertEqual(sheet.starters.count, 11)
        XCTAssertFalse(sheet.starters.contains { $0.player.id == starter.id })
    }

    // MARK: - Season and Europe

    func testFullSeasonWithEuropeanCups() {
        var career = Career.generate(seed: 5)
        career.chooseClub(career.leagues[0].clubIDs[5])
        let startSeason = career.season
        XCTAssertEqual(career.cups.count, 2)
        for cup in career.cups {
            XCTAssertEqual(cup.clubIDs.count, 16)
            XCTAssertEqual(Set(cup.clubIDs).count, 16)
            XCTAssertEqual(cup.groups.count, 4)
            XCTAssertEqual(cup.fixtures(in: .group).count, 4 * 12)
        }
        // A club can't be in both cups.
        XCTAssertTrue(Set(career.cups[0].clubIDs).isDisjoint(with: career.cups[1].clubIDs))

        var playedFitnessDrop = false
        for _ in 0..<(career.matchdayCount - 1) {
            career.manager.boardConfidence = 100
            career.advanceWeek()
            if career.userSquad.contains(where: { $0.fitness < 100 }) { playedFitnessDrop = true }
        }
        XCTAssertTrue(playedFitnessDrop)
        for cup in career.cups {
            XCTAssertNotNil(cup.winnerID, "\(cup.kind) should be decided by week 30")
            XCTAssertEqual(cup.fixtures(in: .quarterFinal).count, 8)
            XCTAssertEqual(cup.fixtures(in: .semiFinal).count, 4)
            XCTAssertEqual(cup.fixtures(in: .final).count, 1)
            XCTAssertTrue(cup.fixtures.allSatisfy { $0.result != nil })
        }

        career.manager.boardConfidence = 100
        let report = career.advanceWeek()
        XCTAssertNotNil(report.finishedSeason)
        XCTAssertEqual(career.season, startSeason + 1)
        XCTAssertEqual(career.week, 0)
        XCTAssertEqual(career.history.count, 1)
        XCTAssertTrue(career.leagues.allSatisfy { $0.fixtures.allSatisfy { $0.result == nil } })
        XCTAssertEqual(career.cups.count, 2)
        XCTAssertTrue(career.cups.allSatisfy { $0.season == startSeason + 1 && $0.clubIDs.count == 16 })
        for club in career.clubs.values where club.id != career.userClubID {
            XCTAssertGreaterThanOrEqual(club.playerIDs.count, 20)
        }
    }

    func testQualificationUsesLeaguePlaces() {
        let ids = (0..<18).map { _ in UUID() }
        let rankings = (0..<5).map { index in
            (strength: 1.0 - Double(index) * 0.01, order: index == 2 ? ids : (0..<18).map { _ in UUID() })
        }
        let qualifiers = Career.europeanQualifiers(rankings: rankings)
        XCTAssertEqual(qualifiers[.eliteCup]?.count, 16)
        XCTAssertEqual(qualifiers[.continentalLeague]?.count, 16)
        // Third strongest league: places 1–3 to the Elite Cup, 4–6 to the Continental League.
        XCTAssertTrue(Array(ids[0..<3]).allSatisfy { qualifiers[.eliteCup]!.contains($0) })
        XCTAssertTrue(Array(ids[3..<6]).allSatisfy { qualifiers[.continentalLeague]!.contains($0) })
        XCTAssertFalse(qualifiers[.continentalLeague]!.contains(ids[6]))
    }

    func testSaveRoundTrip() throws {
        var career = Career.generate(seed: 8)
        career.chooseClub(career.leagues[2].clubIDs[3])
        career.advanceWeek()
        let data = try JSONEncoder().encode(career)
        let decoded = try JSONDecoder().decode(Career.self, from: data)
        XCTAssertEqual(decoded.userClubID, career.userClubID)
        XCTAssertEqual(decoded.week, 1)
        XCTAssertEqual(decoded.players.count, career.players.count)
        XCTAssertEqual(decoded.userTactics, career.userTactics)
        XCTAssertEqual(decoded.cups.count, career.cups.count)
    }

    // MARK: - Transfers

    func testFeeNegotiationAndSigning() {
        var career = Career.generate(seed: 31)
        let myClub = career.leagues[0].clubIDs[0]
        career.chooseClub(myClub)
        let target = career.marketPlayers(filter: TransferFilter(maxPrice: 2_000_000))
            .first { career.isInterestedInJoining($0.id) && career.askingPrice(for: $0.id) <= career.availableTransferFunds }!
        let asking = career.askingPrice(for: target.id)

        // A low bid gets a counter-offer between the bid and the asking price.
        let lowBid = Career.roundTo(Double(asking) * 0.5, step: 50_000)
        guard case .counter(let counter, _) = career.negotiateFee(playerID: target.id, fee: lowBid) else {
            return XCTFail("expected a counter-offer")
        }
        XCTAssertGreaterThan(counter, lowBid)
        XCTAssertLessThanOrEqual(counter, asking)

        // Meeting the counter agrees the fee.
        XCTAssertEqual(career.negotiateFee(playerID: target.id, fee: counter), .agreed(fee: counter))

        // A stingy wage gets a counter; meeting the demand signs him.
        let demand = career.wageDemand(for: target.id)
        if case .counter(let wageCounter) = career.offerContract(playerID: target.id, weeklyWage: demand / 2, years: 3) {
            XCTAssertGreaterThan(wageCounter, demand / 2)
        }
        let outcome = career.offerContract(playerID: target.id, weeklyWage: demand, years: 3)
        if case .signed = outcome {
            XCTAssertEqual(career.player(target.id)?.clubID, myClub)
            XCTAssertNil(career.negotiation(for: target.id))
        } else {
            XCTAssertEqual(outcome, .wageBudgetExceeded)
        }
    }

    func testClubWalksAwayAfterRunningOutOfPatience() {
        var career = Career.generate(seed: 32)
        career.chooseClub(career.leagues[1].clubIDs[0])
        let target = career.marketPlayers(filter: TransferFilter(maxPrice: 3_000_000)).first!
        // Lowball bids use up one round of patience each; the club eventually walks away.
        var responses: [FeeResponse] = []
        for _ in 0..<Career.talkPatience {
            responses.append(career.negotiateFee(playerID: target.id, fee: 50_000))
        }
        XCTAssertTrue(responses.dropLast().allSatisfy { if case .counter = $0 { return true } else { return false } })
        XCTAssertEqual(responses.last, .walkedAway)
        XCTAssertEqual(career.negotiateFee(playerID: target.id, fee: 100_000), .walkedAway)
    }

    func testIncomingOfferCounter() {
        var career = Career.generate(seed: 33)
        career.chooseClub(career.leagues[0].clubIDs[8])
        let player = career.userSquad.sorted { $0.overall > $1.overall }[3]
        career.setTransferListed(player.id, listed: true)
        XCTAssertTrue(career.transferListedPlayers.contains { $0.id == player.id })

        career.makeOffer(for: player, factor: 0.9, listed: true)
        guard let offer = career.pendingOffers.first(where: { $0.playerID == player.id }) else { return }
        // Asking for slightly more than they bid (but within their limit) sells the player.
        let response = career.counterOffer(offer.id, fee: offer.maxFee)
        XCTAssertEqual(response, .accepted(fee: offer.maxFee))
        XCTAssertEqual(career.player(player.id)?.clubID, offer.fromClubID)
        XCTAssertEqual(career.player(player.id)?.isTransferListed, false)
        XCTAssertFalse(career.userStarters.contains { $0?.id == player.id })
    }

    func testFacilityUpgradeCompletes() {
        var career = Career.generate(seed: 2)
        career.chooseClub(career.leagues[0].clubIDs[0])
        let before = career.userClub.facilities.medical
        guard before < Facilities.maxLevel else { return }
        XCTAssertEqual(career.startUpgrade(.medical), .started)
        XCTAssertEqual(career.startUpgrade(.medical), .alreadyInProgress)
        let weeks = career.userClub.upgrades.first!.totalWeeks
        for _ in 0..<weeks {
            career.manager.boardConfidence = 100
            career.advanceWeek()
        }
        XCTAssertEqual(career.userClub.facilities.medical, before + 1)
    }

    // MARK: - Manager

    func testBoardSacksManagerAndJobOffersFollow() {
        var career = Career.generate(seed: 41)
        career.chooseClub(career.leagues[0].clubIDs[0])
        XCTAssertEqual(career.boardExpectation, .title)
        for _ in 0..<6 { career.advanceWeek() }
        career.manager.boardConfidence = Career.sackingThreshold
        career.checkJobSecurity()
        XCTAssertTrue(career.isUnemployed)
        XCTAssertFalse(career.jobOffers.isEmpty)
        XCTAssertEqual(career.manager.timesSacked, 1)
        XCTAssertTrue(career.inbox.contains { if case .sacked = $0.kind { return true } else { return false } })

        // No football while unemployed.
        let weekBefore = career.week
        career.advanceWeek()
        XCTAssertEqual(career.week, weekBefore)

        // Taking a new job starts fresh at the new club.
        let offer = career.jobOffers[0]
        career.acceptJob(offer.id)
        XCTAssertFalse(career.isUnemployed)
        XCTAssertEqual(career.userClubID, offer.clubID)
        XCTAssertEqual(career.manager.boardConfidence, 60)
        XCTAssertEqual(career.userStarters.compactMap { $0 }.count, 11)
        career.advanceWeek()
        XCTAssertEqual(career.week, weekBefore + 1)
    }

    func testBoardWarnsBeforeSacking() {
        var career = Career.generate(seed: 42)
        career.chooseClub(career.leagues[1].clubIDs[3])
        for _ in 0..<6 { career.advanceWeek() }
        career.manager.boardConfidence = 25
        career.checkJobSecurity()
        XCTAssertFalse(career.isUnemployed)
        XCTAssertEqual(career.manager.warningLevel, 1)
    }

    func testWinterWindowAndAnnouncements() {
        var career = Career.generate(seed: 43)
        career.chooseClub(career.leagues[0].clubIDs[6])
        XCTAssertTrue(career.isTransferWindowOpen)
        while career.week < Career.summerWindowWeeks {
            career.manager.boardConfidence = 100
            career.advanceWeek()
        }
        XCTAssertFalse(career.isTransferWindowOpen)
        XCTAssertEqual(career.transferWindowStatus.opensIn, career.matchdayCount / 2 - career.week)
        while career.week < career.matchdayCount / 2 {
            career.manager.boardConfidence = 100
            career.advanceWeek()
        }
        XCTAssertTrue(career.isTransferWindowOpen)
        XCTAssertEqual(career.transferWindowStatus.weeksLeft, Career.winterWindowWeeks)
        XCTAssertTrue(career.inbox.contains { if case .transferWindowOpened(true, _) = $0.kind { return true } else { return false } })
    }

    func testVersionTwoSaveStillLoads() throws {
        var career = Career.generate(seed: 44)
        career.chooseClub(career.leagues[0].clubIDs[3])
        career.advanceWeek()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as! [String: Any]
        json.removeValue(forKey: "manager")
        json.removeValue(forKey: "jobOffers")
        json.removeValue(forKey: "isUnemployed")
        json["version"] = 2
        let data = try JSONSerialization.data(withJSONObject: json)
        let loaded = try JSONDecoder().decode(Career.self, from: data)
        XCTAssertEqual(loaded.version, Career.currentVersion)
        XCTAssertEqual(loaded.userClubID, career.userClubID)
        XCTAssertFalse(loaded.isUnemployed)
        XCTAssertGreaterThan(loaded.manager.reputation, 0)
    }

    func testNegotiationIsFlexible() {
        var career = Career.generate(seed: 45)
        career.chooseClub(career.leagues[0].clubIDs[1])
        let target = career.marketPlayers(filter: TransferFilter(maxPrice: 3_000_000))
            .first { career.askingPrice(for: $0.id) >= 500_000 }!
        let asking = career.askingPrice(for: target.id)
        // Five serious rounds are allowed, and each counter moves towards the bid.
        var previous = asking
        var agreed = false
        for _ in 0..<4 {
            switch career.negotiateFee(playerID: target.id, fee: Career.roundTo(Double(asking) * 0.6, step: 50_000)) {
            case .counter(let fee, _):
                XCTAssertLessThanOrEqual(fee, previous)
                previous = fee
            case .agreed:
                agreed = true
            default:
                XCTFail("talks should still be open")
            }
            if agreed { break }
        }
        XCTAssertLessThan(previous, asking)
    }

    // MARK: - v0.4

    func testEveryFormationHasElevenSlots() {
        XCTAssertEqual(Formation.allCases.count, 10)
        for formation in Formation.allCases {
            XCTAssertEqual(formation.slots.count, 11, formation.rawValue)
            XCTAssertEqual(formation.slots.filter { $0 == .goalkeeper }.count, 1, formation.rawValue)
        }
    }

    func testCardsAndSuspensions() {
        var career = Career.generate(seed: 51)
        career.chooseClub(career.leagues[0].clubIDs[2])
        for _ in 0..<12 {
            career.manager.boardConfidence = 100
            career.advanceWeek()
        }
        let events = career.leagues.flatMap(\.fixtures).compactMap(\.result).flatMap(\.events)
        let yellows = events.filter { $0.kind == .yellowCard }.count
        let reds = events.filter { $0.kind == .redCard }.count
        let games = career.leagues.flatMap(\.fixtures).filter { $0.result != nil }.count
        // Roughly 2–5 yellows per game and a red now and then.
        XCTAssertGreaterThan(Double(yellows) / Double(games), 1.5)
        XCTAssertLessThan(Double(yellows) / Double(games), 6)
        XCTAssertGreaterThan(reds, 0)
        XCTAssertTrue(career.players.values.contains { $0.yellowCards > 0 })

        // A suspended starter must be dealt with before the next match.
        let starter = career.userStarters[4]!
        career.players[starter.id]?.suspendedMatches = 2
        XCTAssertTrue(career.needsLineupChanges)
        XCTAssertFalse(career.teamSheet(for: career.userClubID).starters.contains { $0.player.id == starter.id })
        career.autoPickLineup()
        XCTAssertFalse(career.needsLineupChanges)
    }

    func testSuspensionIsServed() {
        var career = Career.generate(seed: 52)
        career.chooseClub(career.leagues[0].clubIDs[2])
        let player = career.userReserves.first!
        career.players[player.id]?.suspendedMatches = 1
        career.manager.boardConfidence = 100
        career.advanceWeek()
        XCTAssertEqual(career.player(player.id)?.suspendedMatches, 0)
    }

    func testOffersArriveDuringTheWindow() {
        var career = Career.generate(seed: 53)
        career.chooseClub(career.leagues[0].clubIDs[3])
        for _ in 0..<3 {
            career.manager.boardConfidence = 100
            career.advanceWeek()
        }
        XCTAssertFalse(career.offers.isEmpty, "clubs should bid during the summer window")

        // Offering a squad player to clubs brings bids straight away.
        let pending = Set(career.pendingOffers.map(\.playerID))
        let player = career.userSquad.filter { !pending.contains($0.id) }.sorted { $0.overall < $1.overall }[8]
        let bids = career.offerToClubs(player.id)
        XCTAssertGreaterThan(bids, 0)
        XCTAssertEqual(career.pendingOffers.filter { $0.playerID == player.id }.count, bids)
        XCTAssertEqual(career.player(player.id)?.isTransferListed, true)
    }

    func testOldPlayerRecordsLoad() throws {
        let career = Career.generate(seed: 54)
        let player = career.players.values.first!
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(player)) as! [String: Any]
        json.removeValue(forKey: "suspendedMatches")
        json.removeValue(forKey: "yellowCards")
        let loaded = try JSONDecoder().decode(Player.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(loaded.id, player.id)
        XCTAssertEqual(loaded.suspendedMatches, 0)
        XCTAssertEqual(loaded.yellowCards, 0)
    }

    // MARK: - 0.5: free agents, contracts, leaderboards, budgets

    func testFreeAgentSignsWithoutFeeForHigherWages() {
        var career = Career.generate(seed: 61)
        career.chooseClub(career.leagues[0].clubIDs[2])
        // Free agents can sign outside the window, and no fee is paid.
        while career.isTransferWindowOpen {
            career.manager.boardConfidence = 100
            career.advanceWeek()
        }
        let agent = career.freeAgents().first { career.isInterestedInJoining($0.id) }!
        let normalDemand = Double(agent.expectedWage(season: career.season)) * 1.1
        let demand = career.wageDemand(for: agent.id)
        XCTAssertGreaterThan(Double(demand), normalDemand)
        XCTAssertTrue(career.player(agent.id)?.isFreeAgent ?? false)
        career.clubs[career.userClubID]?.finances.wageBudget += demand * 2
        let budget = career.userClub.finances.transferBudget
        let result = career.offerContract(playerID: agent.id, weeklyWage: demand, years: 2)
        XCTAssertEqual(result, .signed(fee: 0, weeklyWage: demand, years: 2))
        XCTAssertEqual(career.player(agent.id)?.clubID, career.userClubID)
        XCTAssertFalse(career.player(agent.id)?.isFreeAgent ?? true)
        XCTAssertEqual(career.userClub.finances.transferBudget, budget)
    }

    func testExpiredContractsCreateFreeAgentsAndReminders() {
        var career = Career.generate(seed: 62)
        career.chooseClub(career.leagues[1].clubIDs[4])
        let leaving = career.userSquad.prefix(2).map(\.id)
        for id in leaving { career.players[id]?.contract.expiresSeason = career.season }
        XCTAssertEqual(Set(career.expiringContracts.map(\.id)), Set(career.userSquad.filter { $0.contract.expiresSeason <= career.season }.map(\.id)))
        XCTAssertTrue(leaving.allSatisfy { id in career.expiringContracts.contains { $0.id == id } })

        career.manager.boardConfidence = 100
        career.advanceWeek()
        XCTAssertTrue(career.inbox.contains {
            if case .contractsReminder(let ids, false) = $0.kind { return Set(leaving).isSubset(of: ids) }
            return false
        })
        while career.week < career.matchdayCount - 1 {
            career.manager.boardConfidence = 100
            career.advanceWeek()
        }
        career.manager.boardConfidence = 100
        career.advanceWeek()
        for id in leaving {
            guard let player = career.player(id) else { continue }
            XCTAssertNotEqual(player.clubID, career.userClubID)
        }
        // The pool stays healthy and every free agent is still an active player.
        XCTAssertGreaterThanOrEqual(career.freeAgentCount, 40)
        XCTAssertLessThanOrEqual(career.freeAgentCount, 200)
        XCTAssertTrue(career.freeAgents().allSatisfy { $0.age(in: career.season) <= 34 && !$0.isRetired })
    }

    func testLeaderboardsCountLeagueGoals() {
        var career = Career.generate(seed: 63)
        career.chooseClub(career.leagues[0].clubIDs[0])
        for _ in 0..<6 {
            career.manager.boardConfidence = 100
            career.advanceWeek()
        }
        let league = career.userLeague
        let scorers = career.leaderboard(.goals, leagueID: league.id)
        XCTAssertFalse(scorers.isEmpty)
        XCTAssertEqual(scorers.map(\.goals), scorers.map(\.goals).sorted(by: >))
        let goalsInLeague = league.fixtures.compactMap(\.result).flatMap(\.events).filter { $0.kind == .goal }
        let top = scorers[0]
        XCTAssertEqual(top.goals, goalsInLeague.filter { $0.playerID == top.playerID }.count)
        let assists = career.leaderboard(.assists, leagueID: league.id)
        XCTAssertEqual(assists.map(\.assists), assists.map(\.assists).sorted(by: >))
        XCTAssertTrue(assists.allSatisfy { $0.assists > 0 })
    }

    func testMovingBudgetBetweenTransfersAndWages() {
        var career = Career.generate(seed: 64)
        career.chooseClub(career.leagues[0].clubIDs[1])
        let before = career.userClub.finances
        let result = career.moveBudget(weekly: 10_000)
        XCTAssertEqual(result, .moved(transferBudget: before.transferBudget - 10_000 * Career.budgetConversionRate,
                                      wageBudget: before.wageBudget + 10_000))
        // Moving it back restores the original budgets.
        career.moveBudget(weekly: -10_000)
        XCTAssertEqual(career.userClub.finances.transferBudget, before.transferBudget)
        XCTAssertEqual(career.userClub.finances.wageBudget, before.wageBudget)
        // The wage budget can't drop below the wage bill.
        XCTAssertEqual(career.moveBudget(weekly: -(career.maxWageToTransfer + 1_000)), .belowWageBill)
        XCTAssertEqual(career.moveBudget(weekly: career.maxTransferToWage + 1), .notEnough)
    }

    func testOldSaveGetsFreeAgents() throws {
        var career = Career.generate(seed: 65)
        career.chooseClub(career.leagues[0].clubIDs[3])
        for agent in career.freeAgents(limit: 500) { career.players.removeValue(forKey: agent.id) }
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(career)) as! [String: Any]
        json["version"] = 3
        let loaded = try JSONDecoder().decode(Career.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(loaded.freeAgentCount, 60)
    }
}
