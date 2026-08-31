import Foundation
import SwiftData

/// One way to earn tickets, from tickets.json's earnCatalog. `childID` is nil
/// for the five shared items; set for per-child items (Arthur's two private
/// therapy-adjacent items, each child's derived "Practice Dance").
///
/// `isPrivate` items must never be shown outside that child's own profile and
/// adult views — never in shared/family views, exports, or a widget on a
/// shared device, per CLAUDE.md §7.7 and §5. Enforce this at the query/view
/// layer, not just by convention: shared-view queries must explicitly filter
/// `isPrivate == false` unless the current context is that child's own
/// profile or an adult.
@Model
public final class EarnItem {
    @Attribute(.unique) public var id: String
    public var label: String
    public var sfSymbol: String
    public var isPrivate: Bool
    /// nil = shared across all children.
    public var childID: String?
    public var bonusAmount: Int?
    public var bonusCondition: String?

    public init(
        id: String,
        label: String,
        sfSymbol: String,
        isPrivate: Bool = false,
        childID: String? = nil,
        bonusAmount: Int? = nil,
        bonusCondition: String? = nil
    ) {
        self.id = id
        self.label = label
        self.sfSymbol = sfSymbol
        self.isPrivate = isPrivate
        self.childID = childID
        self.bonusAmount = bonusAmount
        self.bonusCondition = bonusCondition
    }
}
