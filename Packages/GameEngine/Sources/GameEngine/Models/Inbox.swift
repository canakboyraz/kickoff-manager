import Foundation

/// Messages are stored as structured data; the app turns them into localized text.
public enum InboxKind: Codable, Hashable, Sendable {
    /// Another club wants to buy one of the user's players.
    case transferOffer(offerID: UUID)
    /// A player arrived.
    case signingCompleted(playerID: UUID, fee: Int)
    /// A player left the club (sold or contract expired).
    case playerLeft(playerID: UUID, toClubID: UUID?, fee: Int)
    case injury(playerID: UUID, weeks: Int)
    case upgradeCompleted(kind: FacilityKind)
    case youthIntake(playerIDs: [UUID])
    case contractExpiring(playerID: UUID)
    case seasonEnded(season: Int, position: Int, prizeMoney: Int)
    case boardWelcome
    /// The club plays in a European cup in `season`.
    case cupQualified(kind: CompetitionKind, season: Int)
    case cupProgress(kind: CompetitionKind, stage: CupStage, prize: Int)
    case cupEliminated(kind: CompetitionKind, stage: CupStage)
    case cupWon(kind: CompetitionKind, prize: Int)
    /// A bidding club improved its offer without being asked.
    case offerImproved(offerID: UUID)
    case transferWindowOpened(winter: Bool, weeks: Int)
    case transferWindowClosed
    /// The board is unhappy (1) or issuing a final warning (2).
    case boardWarning(level: Int)
    case sacked(clubID: UUID)
    case jobOffer(offerID: UUID, clubID: UUID)
    case newJob(clubID: UUID)
    /// End-of-season verdict: where the board expected the club to finish and where it did.
    case seasonReview(expected: Int, position: Int, confidence: Int)
    case suspension(playerID: UUID, matches: Int, reason: SuspensionReason)
    /// Players whose contracts run out at the end of this season. `final` = last few weeks.
    case contractsReminder(playerIDs: [UUID], final: Bool)
    /// A scout came back with these players (empty when he found nobody).
    case scoutReport(playerIDs: [UUID])
    /// Bonus money from a rewarded ad or the penalty challenge.
    case bonus(amount: Int, source: BonusSource)
}

public enum BonusSource: String, Codable, Hashable, Sendable {
    case rewardedAd, penalty
}

public enum SuspensionReason: String, Codable, Hashable, Sendable {
    case redCard, secondYellow, yellowCards
}

public struct InboxMessage: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var season: Int
    public var week: Int
    public var kind: InboxKind
    public var isRead: Bool
}

public enum OfferStatus: String, Codable, Hashable, Sendable {
    case pending, accepted, rejected, expired, withdrawn
}

/// A bid from an AI club for one of the user's players.
public struct IncomingOffer: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var playerID: UUID
    public var fromClubID: UUID
    public var fee: Int
    public var expiresWeek: Int
    public var status: OfferStatus
    /// Most the bidding club is prepared to pay (hidden from the user).
    var maxFee: Int
    /// Counter-offers the user has made so far.
    var rounds: Int
}
