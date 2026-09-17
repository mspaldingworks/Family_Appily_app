import Foundation
import SwiftData

public enum ChoreType: String, Codable, Sendable {
    case fixed
    case rotationResolved = "rotation-resolved"
}

@Model
public final class Chore {
    public var id: String = ""
    public var type: String = ""
    public var defaultLabel: String = ""
    public var sfSymbol: String = ""
    public var category: String?
    public var note: String?

    /// How many tickets finishing this chore earns — shown big on the definition
    /// card and credited to the child's ledger when they check it off (see
    /// `WeeklyChartView.toggle`). Adult-set; defaults to 1, which preserves the
    /// previous flat one-ticket-per-chore behaviour. Defaulted (not optional) so
    /// it stays CloudKit-compatible and existing rows migrate in place.
    public var ticketValue: Int = 1

    /// Raw value of a `ChoreColor` (e.g. "red"), the adult-chosen tile colour.
    /// Optional: `nil` falls back to a stable per-chore default so a chore is
    /// never colourless. Kept as a palette token, never raw hex, per CLAUDE.md §7.4.
    public var colorToken: String?

    /// Optional day this chore is due by. `nil` renders as "None". Most chores
    /// recur by weekday via `ChoreAssignment`; this is for one-off deadlines.
    public var dueDate: Date?

    public var choreType: ChoreType { ChoreType(rawValue: type) ?? .fixed }

    public init(
        id: String,
        type: ChoreType,
        defaultLabel: String,
        sfSymbol: String,
        category: String?,
        note: String?,
        ticketValue: Int = 1,
        colorToken: String? = nil,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.type = type.rawValue
        self.defaultLabel = defaultLabel
        self.sfSymbol = sfSymbol
        self.category = category
        self.note = note
        self.ticketValue = ticketValue
        self.colorToken = colorToken
        self.dueDate = dueDate
    }
}
