import Foundation

public enum BidOutcome: Equatable, Sendable {
    case accepted(fee: Int, weeklyWage: Int)
    /// The club wants more. `askingPrice` is a hint for the next bid.
    case rejected(askingPrice: Int)
    case windowClosed
    case insufficientBudget
    case wageBudgetExceeded
    case squadFull
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

    // MARK: - Buying

    /// What the selling club wants for a player.
    public func askingPrice(for playerID: UUID) -> Int {
        guard let player = players[playerID], let clubID = player.clubID, let club = clubs[clubID] else { return 0 }
        var price = Double(player.marketValue(season: season)) * (1.15 + Double(club.reputation) / 400)
        let bestThree = squad(of: clubID).sorted { $0.overall > $1.overall }.prefix(3).map(\.id)
        if bestThree.contains(playerID) { price *= 1.25 }
        if player.contract.expiresSeason <= season { price *= 0.7 }
        return max(50_000, Career.roundTo(price, step: 50_000))
    }

    /// Weekly wage the player asks for to join the user's club.
    public func wageDemand(for playerID: UUID) -> Int {
        guard let player = players[playerID] else { return 0 }
        let demand = max(Double(player.expectedWage(season: season)) * 1.1, Double(player.contract.weeklyWage) * 1.15)
        return Career.roundTo(demand, step: 500)
    }

    /// Players at other clubs, best first.
    public func marketPlayers(filter: TransferFilter, limit: Int = 100) -> [Player] {
        let query = filter.query.trimmingCharacters(in: .whitespaces).lowercased()
        let results = players.values.filter { player in
            guard let clubID = player.clubID, clubID != userClubID else { return false }
            if let position = filter.position, player.position != position { return false }
            if let minOverall = filter.minOverall, player.overall < minOverall { return false }
            if let maxAge = filter.maxAge, player.age(in: season) > maxAge { return false }
            if !query.isEmpty && !player.fullName.lowercased().contains(query) { return false }
            return true
        }
        let priced = results.filter { player in
            guard let maxPrice = filter.maxPrice else { return true }
            return player.marketValue(season: season) <= maxPrice
        }
        return Array(priced.sorted { ($0.overall, $0.potential) > ($1.overall, $1.potential) }.prefix(limit))
    }

    public mutating func placeBid(playerID: UUID, fee: Int) -> BidOutcome {
        guard isTransferWindowOpen else { return .windowClosed }
        guard let player = players[playerID], let sellerID = player.clubID, sellerID != userClubID else { return .unavailable }
        guard userClub.playerIDs.count < Career.maxSquadSize else { return .squadFull }
        guard fee <= userClub.finances.transferBudget, fee <= userClub.finances.balance else { return .insufficientBudget }

        let wage = wageDemand(for: playerID)
        guard wageBill(of: userClubID) + wage <= userClub.finances.wageBudget else { return .wageBudgetExceeded }

        let asking = askingPrice(for: playerID)
        let accepted: Bool
        if fee >= asking {
            accepted = true
        } else if Double(fee) >= Double(asking) * 0.9 {
            accepted = rng.chance(0.5)
        } else {
            accepted = false
        }
        guard accepted else { return .rejected(askingPrice: asking) }

        clubs[userClubID]?.finances.transferBudget -= fee
        clubs[userClubID]?.finances.balance -= fee
        clubs[userClubID]?.finances.seasonExpenses += fee
        clubs[sellerID]?.finances.balance += fee
        clubs[sellerID]?.finances.seasonIncome += fee

        movePlayer(playerID, from: sellerID, to: userClubID, wage: wage, years: rng.int(3...5))
        post(.signingCompleted(playerID: playerID, fee: fee))
        return .accepted(fee: fee, weeklyWage: wage)
    }

    mutating func movePlayer(_ playerID: UUID, from sellerID: UUID, to buyerID: UUID, wage: Int, years: Int) {
        clubs[sellerID]?.playerIDs.removeAll { $0 == playerID }
        clubs[buyerID]?.playerIDs.append(playerID)
        players[playerID]?.clubID = buyerID
        players[playerID]?.contract = Contract(weeklyWage: wage, expiresSeason: season + years)
        players[playerID]?.morale = 75
        players[playerID]?.recentRatings = []
    }

    // MARK: - Contracts

    public mutating func renewContract(playerID: UUID, years: Int) -> RenewalOutcome {
        guard let player = players[playerID], player.clubID == userClubID else { return .unavailable }
        let newWage = max(player.contract.weeklyWage, Career.roundTo(Double(player.expectedWage(season: season)) * 1.05, step: 500))
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

    public mutating func respond(to offerID: UUID, accept: Bool) {
        guard let index = offers.firstIndex(where: { $0.id == offerID }), offers[index].status == .pending else { return }
        let offer = offers[index]
        guard accept else {
            offers[index].status = .rejected
            return
        }
        guard players[offer.playerID]?.clubID == userClubID, clubs[offer.fromClubID] != nil else {
            offers[index].status = .expired
            return
        }
        offers[index].status = .accepted

        clubs[userClubID]?.finances.balance += offer.fee
        clubs[userClubID]?.finances.transferBudget += offer.fee
        clubs[userClubID]?.finances.seasonIncome += offer.fee
        clubs[offer.fromClubID]?.finances.balance -= offer.fee

        let wage = players[offer.playerID].map { $0.expectedWage(season: season) } ?? 0
        post(.playerLeft(playerID: offer.playerID, toClubID: offer.fromClubID, fee: offer.fee))
        movePlayer(offer.playerID, from: userClubID, to: offer.fromClubID, wage: wage, years: rng.int(3...4))

        // Other bids for the same player are no longer valid.
        for other in offers.indices where offers[other].playerID == offer.playerID && offers[other].status == .pending {
            offers[other].status = .expired
        }
    }

    mutating func expireOffers() {
        for index in offers.indices where offers[index].status == .pending && offers[index].expiresWeek < week {
            offers[index].status = .expired
        }
    }

    /// While the window is open, AI clubs sometimes bid for the user's players.
    mutating func generateIncomingOffers() {
        guard isTransferWindowOpen, rng.chance(0.3) else { return }
        let candidates = userSquad.filter { !$0.isInjured }
        guard !candidates.isEmpty else { return }
        let weights = candidates.map { pow(1.12, Double($0.overall - 50)) }
        guard let index = rng.weightedIndex(weights) else { return }
        let target = candidates[index]
        guard !offers.contains(where: { $0.playerID == target.id && $0.status == .pending }) else { return }

        let fee = Career.roundTo(Double(target.marketValue(season: season)) * rng.double(0.85...1.35), step: 50_000)
        let buyers = clubs.values.filter { club in
            club.id != userClubID
                && Career.averageOverall(reputation: club.reputation) + 6 >= Double(target.overall)
                && club.finances.transferBudget >= fee
        }
        guard !buyers.isEmpty else { return }
        let buyer = rng.pick(buyers.sorted { $0.name < $1.name })

        let offer = IncomingOffer(
            id: UUID(),
            playerID: target.id,
            fromClubID: buyer.id,
            fee: fee,
            expiresWeek: week + 2,
            status: .pending
        )
        offers.append(offer)
        post(.transferOffer(offerID: offer.id))
    }
}
