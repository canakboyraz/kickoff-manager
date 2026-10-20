import Foundation

/// State of the user's talks for one player at another club.
public struct TransferTalks: Codable, Hashable, Sendable {
    public var playerID: UUID
    /// Fee the selling club has accepted; personal terms come next.
    public var agreedFee: Int?
    /// The selling club's latest demand.
    public var lastCounter: Int?
    /// The player's latest wage demand.
    public var lastWageCounter: Int?
    /// Rounds the selling club will still listen to.
    public var patience: Int
    /// Rounds the player will still listen to.
    public var contractPatience: Int
    /// Talks broke down; no more offers for this player this window.
    public var isClosed: Bool
}

public enum FeeResponse: Equatable, Sendable {
    case agreed(fee: Int)
    /// The club wants more. `insulted` means the bid was far too low and cost extra patience.
    case counter(fee: Int, insulted: Bool)
    case walkedAway
    case windowClosed
    case insufficientBudget
    case squadFull
    case unavailable
}

public enum ContractResponse: Equatable, Sendable {
    case signed(fee: Int, weeklyWage: Int, years: Int)
    case counter(weeklyWage: Int)
    case walkedAway
    /// The player doesn't want to join a club of this level.
    case notInterested
    case wageBudgetExceeded
    case insufficientBudget
    case noFeeAgreed
    case windowClosed
    case squadFull
}

/// What a bidding club does when the user asks for more.
public enum CounterResponse: Equatable, Sendable {
    /// They pay what the user asked; the player is sold.
    case accepted(fee: Int)
    /// They improve their offer but not all the way.
    case raised(fee: Int)
    case withdrawn
    case unavailable
}

public enum RenewalOutcome: Equatable, Sendable {
    case renewed(weeklyWage: Int, expiresSeason: Int)
    case wageBudgetExceeded
    case unavailable
}

public struct TransferFilter: Equatable, Sendable {
    public var position: Position?
    public var maxPrice: Int?
    public var minOverall: Int?
    public var maxAge: Int?
    public var query: String

    public init(position: Position? = nil, maxPrice: Int? = nil, minOverall: Int? = nil, maxAge: Int? = nil, query: String = "") {
        self.position = position
        self.maxPrice = maxPrice
        self.minOverall = minOverall
        self.maxAge = maxAge
        self.query = query
    }
}

extension Career {
    public static let maxSquadSize = 32
    /// Rounds the selling club listens to before walking away.
    public static let talkPatience = 5
    /// Rounds the player listens to during contract talks.
    public static let contractTalkPatience = 4

    // MARK: - Prices

    /// What the selling club asks for a player.
    public func askingPrice(for playerID: UUID) -> Int {
        guard let player = players[playerID], let clubID = player.clubID, let club = clubs[clubID] else { return 0 }
        var price = Double(player.marketValue(season: season)) * (1.05 + Double(club.reputation) / 500)
        let bestThree = squad(of: clubID).sorted { $0.overall > $1.overall }.prefix(3).map(\.id)
        if bestThree.contains(playerID) { price *= 1.15 }
        if player.contract.expiresSeason <= season { price *= 0.7 }
        return max(50_000, Career.roundTo(price, step: 50_000))
    }

    /// Weekly wage the player asks for to join the user's club. Joining a smaller club costs more.
    public func wageDemand(for playerID: UUID) -> Int {
        guard let player = players[playerID] else { return 0 }
        var demand = max(Double(player.expectedWage(season: season)) * 1.1, Double(player.contract.weeklyWage) * 1.15)
        if let sellerID = player.clubID, let seller = clubs[sellerID] {
            demand *= 1 + Double(max(0, seller.reputation - userClub.reputation)) / 220
        }
        return Career.roundUp(demand, step: 500)
    }

    /// Stars far above the club's level refuse to join.
    public func isInterestedInJoining(_ playerID: UUID) -> Bool {
        guard let player = players[playerID] else { return false }
        return Double(player.overall) <= Career.averageOverall(reputation: userClub.reputation) + 15
    }

    /// Money the user can actually spend on a fee right now.
    public var availableTransferFunds: Int {
        max(0, min(userClub.finances.transferBudget, userClub.finances.balance))
    }

    public func negotiation(for playerID: UUID) -> TransferTalks? {
        talks[playerID]
    }

    /// Lowest share of the asking price this club will accept (0.72–0.87, fixed per player).
    func sellerFloor(for playerID: UUID) -> Double {
        0.72 + Double(playerID.uuid.0 % 16) / 100
    }

    static func roundUp(_ value: Double, step: Int) -> Int {
        Int((value / Double(step)).rounded(.up)) * step
    }

    // MARK: - Buying

    /// Players at other clubs, best first.
    public func marketPlayers(filter: TransferFilter, limit: Int = 100) -> [Player] {
        let query = filter.query.trimmingCharacters(in: .whitespaces).lowercased()
        let results = players.values.filter { player in
            guard let clubID = player.clubID, clubID != userClubID else { return false }
            if let position = filter.position, player.position != position { return false }
            if let minOverall = filter.minOverall, player.overall < minOverall { return false }
            if let maxAge = filter.maxAge, player.age(in: season) > maxAge { return false }
            if !query.isEmpty && !player.fullName.lowercased().contains(query) { return false }
            if let maxPrice = filter.maxPrice, player.marketValue(season: season) > maxPrice { return false }
            return true
        }
        return Array(results.sorted { ($0.overall, $0.potential) > ($1.overall, $1.potential) }.prefix(limit))
    }

    /// Step 1: agree a fee with the selling club. Low bids get a counter-offer; repeated
    /// low bids (or an insulting one) make the club walk away.
    public mutating func negotiateFee(playerID: UUID, fee: Int) -> FeeResponse {
        guard isTransferWindowOpen else { return .windowClosed }
        guard let player = players[playerID], let sellerID = player.clubID, sellerID != userClubID else { return .unavailable }
        guard userClub.playerIDs.count < Career.maxSquadSize else { return .squadFull }
        guard fee <= availableTransferFunds else { return .insufficientBudget }

        var talk = talks[playerID] ?? TransferTalks(
            playerID: playerID, agreedFee: nil, lastCounter: nil, lastWageCounter: nil,
            patience: Career.talkPatience, contractPatience: Career.contractTalkPatience, isClosed: false
        )
        guard !talk.isClosed else { return .walkedAway }
        if let agreed = talk.agreedFee, fee >= agreed { return .agreed(fee: agreed) }

        let asking = askingPrice(for: playerID)
        let floor = Career.roundTo(Double(asking) * sellerFloor(for: playerID), step: 50_000)
        // Close to their floor the club is sometimes happy to do business.
        let closeEnough = Double(fee) >= Double(floor) * 0.93 && rng.chance(0.35)
        if fee >= floor || closeEnough || (talk.lastCounter.map { fee >= $0 } ?? false) {
            talk.agreedFee = fee
            talks[playerID] = talk
            return .agreed(fee: fee)
        }

        let insulted = Double(fee) < Double(asking) * 0.45
        talk.patience -= 1
        if talk.patience <= 0 {
            talk.isClosed = true
            talks[playerID] = talk
            return .walkedAway
        }
        // Each round the club meets the bid part of the way (more when the bid is serious),
        // never below its floor and never above its previous demand.
        let anchor = talk.lastCounter ?? asking
        let step = insulted ? rng.double(0.1...0.25) : rng.double(0.35...0.6)
        let counter = min(anchor, max(floor, Career.roundTo(Double(anchor) - Double(anchor - fee) * step, step: 50_000)))
        talk.lastCounter = counter
        talks[playerID] = talk
        return .counter(fee: counter, insulted: insulted)
    }

    /// Step 2: personal terms. The player accepts a wage close to his demand.
    public mutating func offerContract(playerID: UUID, weeklyWage: Int, years: Int) -> ContractResponse {
        guard isTransferWindowOpen else { return .windowClosed }
        guard var talk = talks[playerID] else { return .noFeeAgreed }
        guard !talk.isClosed else { return .walkedAway }
        guard let fee = talk.agreedFee,
              let player = players[playerID], let sellerID = player.clubID, sellerID != userClubID else { return .noFeeAgreed }
        guard userClub.playerIDs.count < Career.maxSquadSize else { return .squadFull }
        guard fee <= availableTransferFunds else { return .insufficientBudget }
        guard wageBill(of: userClubID) + weeklyWage <= userClub.finances.wageBudget else { return .wageBudgetExceeded }
        guard isInterestedInJoining(playerID) else {
            talk.isClosed = true
            talks[playerID] = talk
            return .notInterested
        }

        let contractYears = years.clamped(to: 1...5)
        let demand = Double(wageDemand(for: playerID))
        var required = demand * 0.85
        // Older players want security; young players don't like being tied down too long.
        let age = player.age(in: season)
        if age >= 29 && contractYears <= 1 { required *= 1.1 }
        if age <= 23 && contractYears >= 5 { required *= 1.05 }

        if Double(weeklyWage) >= required || (talk.lastWageCounter.map { weeklyWage >= $0 } ?? false) {
            clubs[userClubID]?.finances.transferBudget -= fee
            clubs[userClubID]?.finances.balance -= fee
            clubs[userClubID]?.finances.seasonExpenses += fee
            clubs[sellerID]?.finances.balance += fee
            clubs[sellerID]?.finances.seasonIncome += fee
            movePlayer(playerID, from: sellerID, to: userClubID, wage: weeklyWage, years: contractYears)
            talks.removeValue(forKey: playerID)
            post(.signingCompleted(playerID: playerID, fee: fee))
            normalizeUserTactics()
            return .signed(fee: fee, weeklyWage: weeklyWage, years: contractYears)
        }

        talk.contractPatience -= 1
        if talk.contractPatience <= 0 {
            talk.isClosed = true
            talks[playerID] = talk
            return .walkedAway
        }
        let anchor = Double(talk.lastWageCounter ?? Career.roundUp(demand, step: 500))
        let step = rng.double(0.35...0.6)
        let counter = max(Career.roundUp(required, step: 500),
                          Career.roundUp(anchor - (anchor - Double(weeklyWage)) * step, step: 500))
        talk.lastWageCounter = counter
        talks[playerID] = talk
        return .counter(weeklyWage: counter)
    }

    mutating func movePlayer(_ playerID: UUID, from sellerID: UUID, to buyerID: UUID, wage: Int, years: Int) {
        clubs[sellerID]?.playerIDs.removeAll { $0 == playerID }
        clubs[buyerID]?.playerIDs.append(playerID)
        players[playerID]?.clubID = buyerID
        players[playerID]?.contract = Contract(weeklyWage: wage, expiresSeason: season + years)
        players[playerID]?.morale = 75
        players[playerID]?.recentRatings = []
        players[playerID]?.isTransferListed = false
    }

    // MARK: - Contracts

    public mutating func renewContract(playerID: UUID, years: Int) -> RenewalOutcome {
        guard let player = players[playerID], player.clubID == userClubID else { return .unavailable }
        let newWage = renewalWage(for: playerID)
        let billAfter = wageBill(of: userClubID) - player.contract.weeklyWage + newWage
        guard billAfter <= userClub.finances.wageBudget else { return .wageBudgetExceeded }
        let expires = season + years.clamped(to: 1...5)
        players[playerID]?.contract = Contract(weeklyWage: newWage, expiresSeason: expires)
        players[playerID]?.morale = min(100, player.morale + 5)
        return .renewed(weeklyWage: newWage, expiresSeason: expires)
    }

    /// Wage the player would ask for in a renewal (shown before confirming).
    public func renewalWage(for playerID: UUID) -> Int {
        guard let player = players[playerID] else { return 0 }
        return max(player.contract.weeklyWage, Career.roundTo(Double(player.expectedWage(season: season)) * 1.05, step: 500))
    }

    // MARK: - Selling

    /// Put a player up for sale (or take him off the list). Listed players attract more bids.
    public mutating func setTransferListed(_ playerID: UUID, listed: Bool) {
        guard players[playerID]?.clubID == userClubID else { return }
        players[playerID]?.isTransferListed = listed
    }

    public var transferListedPlayers: [Player] {
        userSquad.filter(\.isTransferListed)
    }

    public mutating func respond(to offerID: UUID, accept: Bool) {
        guard let index = offers.firstIndex(where: { $0.id == offerID }), offers[index].status == .pending else { return }
        guard accept else {
            offers[index].status = .rejected
            return
        }
        completeSale(offerIndex: index)
    }

    /// Ask a bidding club for more. They pay up to a hidden maximum and give up if pushed too hard.
    public mutating func counterOffer(_ offerID: UUID, fee: Int) -> CounterResponse {
        guard let index = offers.firstIndex(where: { $0.id == offerID }), offers[index].status == .pending,
              players[offers[index].playerID]?.clubID == userClubID else { return .unavailable }
        var offer = offers[index]
        if fee <= offer.maxFee {
            offers[index].fee = max(fee, offer.fee)
            let finalFee = offers[index].fee
            completeSale(offerIndex: index)
            return .accepted(fee: finalFee)
        }
        offer.rounds += 1
        if Double(fee) > Double(offer.maxFee) * 2 || offer.rounds >= 4 {
            offer.status = .withdrawn
            offers[index] = offer
            return .withdrawn
        }
        let raised = Career.roundTo(Double(offer.fee) + Double(offer.maxFee - offer.fee) * rng.double(0.4...0.8), step: 50_000)
        offer.fee = min(offer.maxFee, max(offer.fee + 50_000, raised))
        offer.expiresWeek = week + 2
        offers[index] = offer
        return .raised(fee: offer.fee)
    }

    private mutating func completeSale(offerIndex index: Int) {
        let offer = offers[index]
        guard players[offer.playerID]?.clubID == userClubID, clubs[offer.fromClubID] != nil else {
            offers[index].status = .expired
            return
        }
        offers[index].status = .accepted

        clubs[userClubID]?.finances.balance += offer.fee
        clubs[userClubID]?.finances.transferBudget += offer.fee
        clubs[userClubID]?.finances.seasonIncome += offer.fee
        clubs[offer.fromClubID]?.finances.balance -= offer.fee
        clubs[offer.fromClubID]?.finances.transferBudget -= offer.fee

        let wage = players[offer.playerID].map { $0.expectedWage(season: season) } ?? 0
        post(.playerLeft(playerID: offer.playerID, toClubID: offer.fromClubID, fee: offer.fee))
        movePlayer(offer.playerID, from: userClubID, to: offer.fromClubID, wage: wage, years: rng.int(3...4))

        // Other bids for the same player are no longer valid.
        for other in offers.indices where offers[other].playerID == offer.playerID && offers[other].status == .pending {
            offers[other].status = .expired
        }
        normalizeUserTactics()
    }

    mutating func expireOffers() {
        for index in offers.indices where offers[index].status == .pending && offers[index].expiresWeek < week {
            offers[index].status = .expired
        }
    }

    /// While the window is open, AI clubs bid for the user's players: now and then for anyone,
    /// and often for players on the transfer list.
    mutating func generateIncomingOffers() {
        guard isTransferWindowOpen else { return }
        let pending = Set(offers.filter { $0.status == .pending }.map(\.playerID))
        let candidates = userSquad.filter { !$0.isInjured && !pending.contains($0.id) }
        guard candidates.count > 14 else { return }

        // Clubs sometimes improve a bid on their own.
        for index in offers.indices where offers[index].status == .pending && offers[index].fee < offers[index].maxFee {
            guard rng.chance(0.3) else { continue }
            let improved = Career.roundTo(Double(offers[index].fee) * rng.double(1.05...1.15), step: 50_000)
            offers[index].fee = min(offers[index].maxFee, max(offers[index].fee + 50_000, improved))
            offers[index].expiresWeek = week + 2
            post(.offerImproved(offerID: offers[index].id))
        }

        let unlisted = candidates.filter { !$0.isTransferListed }
        if rng.chance(0.6), !unlisted.isEmpty {
            let weights = unlisted.map { pow(1.12, Double($0.overall - 50)) * (1 + Double(max(0, $0.potential - $0.overall)) / 20) }
            if let index = rng.weightedIndex(weights) {
                makeOffer(for: unlisted[index], factor: rng.double(0.9...1.3), listed: false)
            }
        }
        for player in candidates where player.isTransferListed && rng.chance(0.4) {
            makeOffer(for: player, factor: rng.double(0.7...1.05), listed: true)
        }
    }

    mutating func makeOffer(for player: Player, factor: Double, listed: Bool) {
        let value = Double(player.marketValue(season: season))
        let fee = max(50_000, Career.roundTo(value * factor, step: 50_000))
        let reach = listed ? 12.0 : 6.0
        let buyers = clubs.values.filter { club in
            let level = Career.averageOverall(reputation: club.reputation)
            return club.id != userClubID
                && level + reach >= Double(player.overall)
                && level - 14 <= Double(player.overall)
                && club.finances.transferBudget >= fee
        }
        guard !buyers.isEmpty else { return }
        let buyer = rng.pick(buyers.sorted { $0.name < $1.name })
        let ceiling = Career.roundTo(Double(fee) * rng.double(1.15...1.5), step: 50_000)
        let maxFee = max(fee, min(buyer.finances.transferBudget, ceiling))

        let offer = IncomingOffer(
            id: UUID(),
            playerID: player.id,
            fromClubID: buyer.id,
            fee: fee,
            expiresWeek: week + 2,
            status: .pending,
            maxFee: maxFee,
            rounds: 0
        )
        offers.append(offer)
        post(.transferOffer(offerID: offer.id))
    }
}
