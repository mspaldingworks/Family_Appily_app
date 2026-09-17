import Foundation
import SwiftData

/// A chore's place on one child's weekly chart: which weekday, and (for chores
/// whose wording differs per child, e.g. "Empty Dishes" vs "Empty Dishwasher")
/// the display label to use for this child specifically.
@Model
public final class ChoreAssignment {
    public var childID: String = ""
    public var choreID: String = ""
    /// 0 = Sunday ... 6 = Saturday, matching family.json's weekStartsOn: "sunday".
    public var weekday: Int = 0
    public var displayLabelOverride: String?
    /// Per-kid overrides stamped from the child's `ChoreCard` when it's edited,
    /// so the chart/calendar/tickets show this kid's icon and ticket value.
    /// Nil falls back to the base chore (e.g. rotation slots, which have no card).
    public var sfSymbolOverride: String?
    public var ticketValueOverride: Int?

    public init(
        childID: String,
        choreID: String,
        weekday: Weekday,
        displayLabelOverride: String?,
        sfSymbolOverride: String? = nil,
        ticketValueOverride: Int? = nil
    ) {
        self.childID = childID
        self.choreID = choreID
        self.weekday = weekday.rawValue
        self.displayLabelOverride = displayLabelOverride
        self.sfSymbolOverride = sfSymbolOverride
        self.ticketValueOverride = ticketValueOverride
    }
}

public enum Weekday: Int, CaseIterable, Codable, Sendable {
    case sunday = 0, monday, tuesday, wednesday, thursday, friday, saturday

    public init?(jsonKey: String) {
        switch jsonKey {
        case "sunday": self = .sunday
        case "monday": self = .monday
        case "tuesday": self = .tuesday
        case "wednesday": self = .wednesday
        case "thursday": self = .thursday
        case "friday": self = .friday
        case "saturday": self = .saturday
        default: return nil
        }
    }

    public var shortLabel: String {
        switch self {
        case .sunday: return "SUN"
        case .monday: return "MON"
        case .tuesday: return "TUE"
        case .wednesday: return "WED"
        case .thursday: return "THU"
        case .friday: return "FRI"
        case .saturday: return "SAT"
        }
    }
}
