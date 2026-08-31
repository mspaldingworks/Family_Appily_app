import Foundation
import SwiftData

/// One chore marked complete, for one child, on one calendar day. Existence of
/// a `Completion` for (childID, choreID, date) means "done" — tapping again
/// removes the record rather than flipping a boolean, so the model has no
/// mutable "isComplete" state to get out of sync.
@Model
public final class Completion {
    public var childID: String
    public var choreID: String
    /// Normalized to midnight local time — the calendar day the chore was done, not a timestamp.
    public var date: Date
    public var completedAt: Date

    public init(childID: String, choreID: String, date: Date, completedAt: Date = .now) {
        self.childID = childID
        self.choreID = choreID
        self.date = date
        self.completedAt = completedAt
    }
}
