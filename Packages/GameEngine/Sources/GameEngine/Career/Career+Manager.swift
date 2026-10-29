import Foundation

extension Career {
    /// Board confidence at or below this gets the manager sacked.
    public static let sackingThreshold = 10
    /// Weeks of the winter transfer window.
    public static let winterWindowWeeks = 4
    /// Weeks of the summer transfer window (start of the season).
    public static let summerWindowWeeks = 4

    // MARK: - Expectations

    /// Where the board expects a club to finish: its reputation rank within the league.
    public func expectedPosition(of clubID: UUID) -> Int {
        guard let club = clubs[clubID], let league = league(club.leagueID) else { return 10 }
        let order = league.clubIDs.sorted { (clubs[$0]?.reputation ?? 0) > (clubs[$1]?.reputation ?? 0) }
        return (order.firstIndex(of: clubID) ?? order.count / 2) + 1
    }

    public var boardExpectation: BoardExpectation {
        switch expectedPosition(of: userClubID) {
        case 1: return .title
        case 2...3: return .topThree
        case 4...7: return .topHalf
        case 8...13: return .midTable
        default: return .survival
        }
    }

    // MARK: - Board confidence

    mutating func adjustBoardConfidence(_ delta: Int) {
        manager.boardConfidence = (manager.boardConfidence + delta).clamped(to: 0...100)
    }

    /// After every league game: wins help, losses hurt, more so against weaker opponents.
    mutating func updateBoardAfterMatch(scored: Int, conceded: Int, opponentID: UUID) {
        guard !isUnemployed else { return }
        rewardMatch(scored: scored, conceded: conceded)
        // Positive when the opponent is expected to finish higher than us.
        let gap = Double(expectedPosition(of: userClubID) - expectedPosition(of: opponentID)) / 6
        var delta: Double
        if scored > conceded {
            delta = 2.5 + max(0, gap) * 1.5
        } else if scored == conceded {
            delta = gap
        } else {
            delta = -3 + gap * 1.5
            delta = min(delta, -0.5)
        }
        if scored - conceded <= -3 { delta -= 2 }
        adjustBoardConfidence(Int(delta.rounded()))
    }

    /// Every four weeks: the board compares the league position with its target.
    mutating func reviewLeaguePosition() {
        guard !isUnemployed, week >= 8, let position = userLeaguePosition else { return }
        let difference = expectedPosition(of: userClubID) - position
        adjustBoardConfidence((difference / 2).clamped(to: -4...3))
    }

    /// Warnings first, then the sack.
    mutating func checkJobSecurity() {
        guard !isUnemployed, week >= 6 else { return }
        let confidence = manager.boardConfidence
        if confidence <= Career.sackingThreshold {
            sackManager()
        } else if confidence <= 20 && manager.warningLevel < 2 {
            manager.warningLevel = 2
            post(.boardWarning(level: 2))
        } else if confidence <= 32 && manager.warningLevel < 1 {
            manager.warningLevel = 1
            post(.boardWarning(level: 1))
        } else if confidence >= 45 {
            manager.warningLevel = 0
        }
    }

    mutating func sackManager() {
        let previous = userClubID
        manager.timesSacked += 1
        manager.reputation = max(5, manager.reputation - 6)
        manager.warningLevel = 0
        isUnemployed = true
        leaveCurrentClub()
        post(.sacked(clubID: previous))
        jobOffers = makeJobOffers(afterSacking: true, count: 3)
    }

    /// Unfinished business at the old club is void once the manager leaves.
    private mutating func leaveCurrentClub() {
        for index in offers.indices where offers[index].status == .pending {
            offers[index].status = .expired
        }
        talks.removeAll()
        for id in clubs[userClubID]?.playerIDs ?? [] {
            players[id]?.isTransferListed = false
        }
    }

    // MARK: - Job offers

    /// After a sacking: smaller clubs willing to take a chance. Otherwise: bigger clubs impressed by the manager.
    mutating func makeJobOffers(afterSacking: Bool, count: Int) -> [JobOffer] {
        let reputation = manager.reputation
        let current = clubs[userClubID]?.reputation ?? 0
        var pool = clubs.values.filter { club in
            guard club.id != userClubID else { return false }
            if afterSacking {
                return club.reputation <= reputation + 5 && club.reputation >= reputation - 30
            }
            return club.reputation > current + 2 && club.reputation <= reputation + 6
        }
        if afterSacking && pool.count < count {
            pool = Array(clubs.values.filter { $0.id != userClubID }.sorted { $0.reputation < $1.reputation }.prefix(count * 2))
        }
        let picks = pool.sorted { $0.name < $1.name }.shuffled(using: &rng).prefix(count)
        return picks.map { JobOffer(id: UUID(), clubID: $0.id, expiresWeek: week + 3) }
    }

    /// Bigger clubs come calling at the winter break and after a good season.
    mutating func considerJobOffers(seasonEnd: Bool) {
        guard !isUnemployed,
              manager.reputation >= userClub.reputation + 3,
              manager.boardConfidence >= 50,
              rng.chance(seasonEnd ? 0.7 : 0.4) else { return }
        let fresh = makeJobOffers(afterSacking: false, count: seasonEnd ? 2 : 1)
            .filter { offer in !jobOffers.contains { $0.clubID == offer.clubID } }
        for offer in fresh {
            jobOffers.append(offer)
            post(.jobOffer(offerID: offer.id, clubID: offer.clubID))
        }
    }

    mutating func expireJobOffers() {
        guard !isUnemployed else { return }
        jobOffers.removeAll { $0.expiresWeek < week }
    }

    public func jobOffer(_ id: UUID) -> JobOffer? {
        jobOffers.first { $0.id == id }
    }

    /// Takes over another club straight away (mid-season moves are allowed).
    public mutating func acceptJob(_ offerID: UUID) {
        guard let offer = jobOffer(offerID), let club = clubs[offer.clubID] else { return }
        if !isUnemployed { leaveCurrentClub() }
        userClubID = club.id
        userTactics = Tactics(formation: club.formation, starters: [], bench: [])
        autoPickLineup()
        manager.boardConfidence = 60
        manager.warningLevel = 0
        isUnemployed = false
        jobOffers.removeAll()
        post(.newJob(clubID: club.id))
        if let cup = userCup {
            post(.cupQualified(kind: cup.kind, season: season))
        }
    }

    public mutating func declineJob(_ offerID: UUID) {
        // An unemployed manager has to keep at least one option.
        guard !isUnemployed || jobOffers.count > 1 else { return }
        jobOffers.removeAll { $0.id == offerID }
    }

    // MARK: - Season review

    /// Reputation and board confidence after the final table. `expected` is the pre-season target.
    mutating func reviewSeason(expected: Int, position: Int) {
        guard !isUnemployed else { return }
        let difference = expected - position
        manager.seasonsManaged += 1
        rewardSeason(expected: expected, position: position)
        var reputationChange = Int((Double(difference) * 1.5).rounded()).clamped(to: -6...8)
        if position == 1 {
            reputationChange += 6
            manager.trophies += 1
        }
        manager.reputation = (manager.reputation + reputationChange).clamped(to: 1...100)
        let confidence = (50 + difference * 5).clamped(to: 0...95)
        post(.seasonReview(expected: expected, position: position, confidence: confidence))
        if confidence <= Career.sackingThreshold {
            manager.boardConfidence = confidence
            sackManager()
        } else {
            manager.boardConfidence = max(confidence, 30)
            manager.warningLevel = 0
        }
    }

    /// European runs impress the board and the wider football world.
    mutating func recordCupResult(_ kind: CompetitionKind, stage: CupStage, won: Bool) {
        guard !isUnemployed else { return }
        rewardCup(kind, won: won)
        if won {
            manager.trophies += 1
            manager.reputation = min(100, manager.reputation + (kind == .eliteCup ? 10 : 5))
            adjustBoardConfidence(15)
        } else if stage >= .quarterFinal {
            adjustBoardConfidence(4)
            manager.reputation = min(100, manager.reputation + 1)
        }
    }

    // MARK: - Transfer windows

    /// Open now, with weeks left; or closed, with weeks until the winter window (nil = next summer).
    public var transferWindowStatus: (isOpen: Bool, weeksLeft: Int?, opensIn: Int?) {
        let half = matchdayCount / 2
        if week < Career.summerWindowWeeks {
            return (true, Career.summerWindowWeeks - week, nil)
        }
        if week >= half && week < half + Career.winterWindowWeeks {
            return (true, half + Career.winterWindowWeeks - week, nil)
        }
        if week < half {
            return (false, nil, half - week)
        }
        return (false, nil, nil)
    }

    mutating func announceTransferWindows() {
        let half = matchdayCount / 2
        if week == half {
            post(.transferWindowOpened(winter: true, weeks: Career.winterWindowWeeks))
        } else if week == half + Career.winterWindowWeeks || week == Career.summerWindowWeeks {
            post(.transferWindowClosed)
        }
    }
}
