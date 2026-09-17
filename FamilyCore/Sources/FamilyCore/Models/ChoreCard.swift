import Foundation
import SwiftData

/// One chore as assigned to one child — the per-kid card an adult edits. Each
/// (child, base-chore) pair is its own card, so the same chore can be worth
/// different tickets, use a different icon, and be a different colour for each
/// kid. It links to a base `Chore` (`choreID`) so completions and the ticket
/// ledger keep stable IDs, and it is the source of truth the recurring
/// `ChoreAssignment` rows are derived from (see ChoreSettingsView).
///
/// Schedule is one of two modes: recurring on a set of weekdays, or a single
/// `dueDate`. Rotation "Weekly Chore" slots are system-managed and have no card.
@Model
public final class ChoreCard {
    public var id: String = ""   // "childID|choreID"
    public var childID: String = ""
    public var choreID: String = ""
    public var label: String = ""
    public var sfSymbol: String = ""
    public var colorToken: String?
    public var ticketValue: Int = 1
    /// true → repeats on `weekdaysMask` days; false → one-off on `dueDate`.
    public var scheduleIsRecurring: Bool = true
    /// Bitmask of `Weekday` raw values: bit i set ⇒ weekday i is scheduled.
    public var weekdaysMask: Int = 0
    public var dueDate: Date?

    public init(
        id: String,
        childID: String,
        choreID: String,
        label: String,
        sfSymbol: String,
        colorToken: String?,
        ticketValue: Int,
        scheduleIsRecurring: Bool = true,
        weekdaysMask: Int = 0,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.childID = childID
        self.choreID = choreID
        self.label = label
        self.sfSymbol = sfSymbol
        self.colorToken = colorToken
        self.ticketValue = ticketValue
        self.scheduleIsRecurring = scheduleIsRecurring
        self.weekdaysMask = weekdaysMask
        self.dueDate = dueDate
    }

    /// The stable card id for a (child, chore) pair.
    public static func id(childID: String, choreID: String) -> String { "\(childID)|\(choreID)" }

    public var weekdays: [Weekday] {
        Weekday.allCases.filter { isOn($0) }
    }

    public func isOn(_ weekday: Weekday) -> Bool {
        weekdaysMask & (1 << weekday.rawValue) != 0
    }

    public func setWeekday(_ weekday: Weekday, on: Bool) {
        if on { weekdaysMask |= (1 << weekday.rawValue) }
        else { weekdaysMask &= ~(1 << weekday.rawValue) }
    }
}
