import Foundation
import SwiftData

/// A ticket-spend tier from tickets.json. Family-scope and identical across
/// all children by design — do not add a childID here (see CLAUDE.md §7.7:
/// per-child pricing is the fastest way to make this feel unfair).
@Model
public final class SpendTier {
    @Attribute(.unique) public var id: String
    public var cost: Int
    public var label: String
    public var sfSymbol: String

    public init(id: String, cost: Int, label: String, sfSymbol: String) {
        self.id = id
        self.cost = cost
        self.label = label
        self.sfSymbol = sfSymbol
    }
}
