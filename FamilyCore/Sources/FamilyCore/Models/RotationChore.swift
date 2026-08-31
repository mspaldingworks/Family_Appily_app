import Foundation
import SwiftData

/// One of the six shared family-rotation chores, from rotation.json. The
/// rotation assignment itself is computed (see RotationEngine) — this model
/// just holds the catalog entry (label, sfSymbol, offset), not a per-week grid.
@Model
public final class RotationChore {
    @Attribute(.unique) public var id: String
    public var label: String
    public var offset: Int
    public var sfSymbol: String

    public init(id: String, label: String, offset: Int, sfSymbol: String) {
        self.id = id
        self.label = label
        self.offset = offset
        self.sfSymbol = sfSymbol
    }
}
