import Foundation

/// Messages are stored as structured data; the app turns them into localized text.
public enum InboxKind: Codable, Hashable, Sendable {
    /// Another club wants to buy one of the user's players.
    case transferOffer(offerID: UUID)
    /// A player arrived (the user's bid was accepted).
    case signingCompleted(playerID: UUID, fee: Int)
    /// A player left the club (sold or contract expired).
    case playerLeft(playerID: UUID, toClubID: UUID?, fee: Int)
    case injury(playerID: UUID, weeks: Int)
    case upgradeCompleted(kind: FacilityKind)
    case youthIntake(playerIDs: [UUID])
    case contractExpiring(playerID: UUID)
    case seasonEnded(season: Int, position: Int, prizeMoney: Int)
    case boardWelcome
}

public struct InboxMessage: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var season: Int
    public var week: Int
    public var kind: InboxKind
    public var isRead: Bool
}

public enum OfferStatus: String, Codable, Hashable, Sendable {
    case pending, accepted, rejected, expired
}

/// A bid from an AI club for one of the user's players.
public struct IncomingOffer: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var playerID: UUID
    public var fromClubID: UUID
    public var fee: Int
    public var expiresWeek: Int
    public var status: OfferStatus
}
