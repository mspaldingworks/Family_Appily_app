import Foundation
import SwiftData

public enum TicketLedgerKind: String, Codable, Sendable {
    case earn
    case spend
    /// An adult-awarded bonus ticket outside the normal earn catalog (the "extra
    /// ticket" proposal noted in the design handoff) — still logged here, not a
    /// separate currency.
    case adultAward = "adult-award"
}

/// One entry in the append-only ticket ledger for one child. A child's ticket
/// balance is always `entries.filter { $0.childID == id }.map(\.amount).sum` —
/// never a mutable stored counter, so it can't drift from its own history.
@Model
public final class TicketLedgerEntry {
    public var childID: String
    /// Positive for earn/adult-award, negative for spend.
    public var amount: Int
    public var kind: String
    /// The EarnItem.id or SpendTier.id this entry is for.
    public var referenceID: String
    public var occurredAt: Date

    public init(childID: String, amount: Int, kind: TicketLedgerKind, referenceID: String, occurredAt: Date = .now) {
        self.childID = childID
        self.amount = amount
        self.kind = kind.rawValue
        self.referenceID = referenceID
        self.occurredAt = occurredAt
    }
}
