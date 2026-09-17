import Foundation

/// An RGBA colour captured from a source calendar, kept as plain `Double`s so
/// these value types stay `Sendable` and free of any UI framework (CLAUDE.md §8:
/// nothing below the view layer imports SwiftUI/UIKit/AppKit).
public struct CalendarRGBA: Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// One calendar the device can see (an EventKit calendar), flattened to a
/// Sendable value. `matchedChild` is set when the calendar's name is one of the
/// children — e.g. the family's "Finley" Google calendar resolves to `.finley`.
/// That name match is how an external calendar is tied to an app identity,
/// with no Google API and no per-family configuration.
public struct CalendarSource: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let color: CalendarRGBA?
    public let matchedChild: ChildID?

    public init(id: String, title: String, color: CalendarRGBA?, matchedChild: ChildID?) {
        self.id = id
        self.title = title
        self.color = color
        self.matchedChild = matchedChild
    }

    /// Maps a calendar title to a child identity by name (case-insensitive) —
    /// "Arthur" → `.arthur`. Nil for family/parent calendars (Family, Birthdays,
    /// a grown-up's own calendar). This is the whole of the auto-mapping.
    public static func child(forCalendarTitle title: String) -> ChildID? {
        ChildID(rawValue: title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}

/// One event from a source calendar, within the visible window. `childID` is
/// carried through when the event's calendar is a child's own, so the family
/// screen can render it in that child's identity colour.
public struct CalendarEventItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarID: String
    public let calendarTitle: String
    public let color: CalendarRGBA?
    public let childID: ChildID?

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarID: String,
        calendarTitle: String,
        color: CalendarRGBA?,
        childID: ChildID?
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.color = color
        self.childID = childID
    }
}
