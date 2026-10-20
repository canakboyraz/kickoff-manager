import XCTest
@testable import GameEngine

final class GameEngineTests: XCTestCase {
    func testWorldGeneration() {
        let career = Career.generate(seed: 42)
        XCTAssertEqual(career.leagues.count, 5)
        for league in career.leagues {
            XCTAssertEqual(league.clubIDs.count, 18)
            XCTAssertEqual(league.matchdayCount, 34)
            XCTAssertEqual(league.fixtures.count, 18 * 17)
        }
        XCTAssertEqual(career.clubs.count, 90)
        XCTAssertEqual(career.players.count, 90 * 24)
    }

    func testEveryClubPlaysOncePerMatchday() {
        let career = Career.generate(seed: 7)
        for league in career.leagues {
            for matchday in 1...league.matchdayCount {
                let ids = league.fixtures(on: matchday).flatMap { [$0.homeID, $0.awayID] }
                XCTAssertEqual(Set(ids).count, 18, "matchday \(matchday)")
            }
            // Each pairing happens exactly twice, once at each ground.
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
        }
    }

    func testStrongerTeamsWinMoreOften() {
        var career = Career.generate(seed: 11)
        let league = career.leagues[1]
        let strongest = league.clubIDs.max { career.clubs[$0]!.reputation < career.clubs[$1]!.reputation }!
        let weakest = league.clubIDs.min { career.clubs[$0]!.reputation < career.clubs[$1]!.reputation }!
        var rng = SeededRandom(seed: 99)
        var strongWins = 0
        var weakWins = 0
        for _ in 0..<200 {
            let outcome = MatchEngine.play(
                home: career.clubs[strongest]!,
                away: career.clubs[weakest]!,
                homeSquad: career.squad(of: strongest),
                awaySquad: career.squad(of: weakest),
                rng: &rng
            )
            if outcome.result.homeGoals > outcome.result.awayGoals { strongWins += 1 }
            if outcome.result.homeGoals < outcome.result.awayGoals { weakWins += 1 }
        }
        XCTAssertGreaterThan(strongWins, weakWins * 3)
        career.chooseClub(weakest)
        XCTAssertEqual(career.userClubID, weakest)
    }

    func testFullSeasonRunsAndRollsOver() throws {
        var career = Career.generate(seed: 5)
        career.chooseClub(career.leagues[0].clubIDs[5])
        let startSeason = career.season
        var summary: SeasonSummary?
        for _ in 0..<career.matchdayCount {
            let report = career.advanceWeek()
            if let finished = report.finishedSeason { summary = finished }
        }
        XCTAssertNotNil(summary)
        XCTAssertEqual(career.season, startSeason + 1)
        XCTAssertEqual(career.week, 0)
        XCTAssertEqual(career.history.count, 1)
        XCTAssertTrue(career.leagues.allSatisfy { $0.fixtures.allSatisfy { $0.result == nil } })
        // Squads stay playable after retirements, expiries and youth intake.
        for club in career.clubs.values where club.id != career.userClubID {
            XCTAssertGreaterThanOrEqual(club.playerIDs.count, 20)
        }
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
    }

    func testBuyingAPlayer() {
        var career = Career.generate(seed: 21)
        let myClub = career.leagues[0].clubIDs[0]
        career.chooseClub(myClub)
        let target = career.marketPlayers(filter: TransferFilter(maxPrice: 3_000_000)).first!
        let asking = career.askingPrice(for: target.id)
        let outcome = career.placeBid(playerID: target.id, fee: asking)
        if case .accepted = outcome {
            XCTAssertEqual(career.player(target.id)?.clubID, myClub)
            XCTAssertTrue(career.userClub.playerIDs.contains(target.id))
        } else {
            // Only budget limits may block a full-price bid.
            XCTAssertTrue([.insufficientBudget, .wageBudgetExceeded].contains(outcome), "\(outcome)")
        }
        XCTAssertEqual(career.placeBid(playerID: target.id, fee: 0), .unavailable)
    }

    func testFacilityUpgradeCompletes() {
        var career = Career.generate(seed: 2)
        career.chooseClub(career.leagues[0].clubIDs[0])
        let before = career.userClub.facilities.medical
        guard before < Facilities.maxLevel else { return }
        XCTAssertEqual(career.startUpgrade(.medical), .started)
        XCTAssertEqual(career.startUpgrade(.medical), .alreadyInProgress)
        let weeks = career.userClub.upgrades.first!.totalWeeks
        for _ in 0..<weeks { career.advanceWeek() }
        XCTAssertEqual(career.userClub.facilities.medical, before + 1)
    }
}
