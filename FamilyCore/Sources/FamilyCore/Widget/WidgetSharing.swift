import Foundation

/// The bridge between the app and its widgets. Widgets run in a separate
/// process and can't read the app's SwiftData store, so the app writes a small
/// glanceable **snapshot** into a shared App Group container and the widget
/// reads it. Deliberately NOT the live store: the SwiftData/CloudKit store stays
/// where it is (no risky relocation), and only this derived summary is shared.
public enum FamilyWidgetSharing {
    /// Must match the App Group entitlement on both the app and the widget.
    public static let appGroupID = "group.com.mspaldingworks.FamilyAppily"
    private static let snapshotKey = "widgetSnapshot.v1"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// Writes the latest summary for the widgets. A no-op if the App Group isn't
    /// available (e.g. the Mac without the entitlement), so callers needn't guard.
    public static func write(_ snapshot: WidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    public static func read() -> WidgetSnapshot? {
        guard let defaults, let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

/// A glanceable summary of the family, small enough to hand to a widget: per kid,
/// how many of today's chores are left and their ticket balance. Plain `Codable`
/// value types — no SwiftData — so the widget never opens the store.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public struct Kid: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        /// The kid's identity colour as hex (legend colour for originals, chosen
        /// colour for parent-added kids).
        public let colorHex: String
        /// An SF Symbol emblem, or "" to use a monogram of the name.
        public let emblemSymbol: String
        public let choresToday: Int
        public let choresDone: Int
        public let tickets: Int

        public init(id: String, name: String, colorHex: String, emblemSymbol: String,
                    choresToday: Int, choresDone: Int, tickets: Int) {
            self.id = id
            self.name = name
            self.colorHex = colorHex
            self.emblemSymbol = emblemSymbol
            self.choresToday = choresToday
            self.choresDone = choresDone
            self.tickets = tickets
        }

        public var remaining: Int { max(0, choresToday - choresDone) }
        public var allDone: Bool { choresToday > 0 && remaining == 0 }
        public var initial: String {
            String(name.trimmingCharacters(in: .whitespaces).first ?? "?").uppercased()
        }
    }

    /// One of today's calendar events, flattened for the agenda widget. Fetched
    /// by the app (which already has EventKit access) and carried in the snapshot,
    /// so the widget never touches EventKit itself.
    public struct Event: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let start: Date
        public let isAllDay: Bool
        public let color: CalendarRGBA?
        public init(id: String, title: String, start: Date, isAllDay: Bool, color: CalendarRGBA?) {
            self.id = id
            self.title = title
            self.start = start
            self.isAllDay = isAllDay
            self.color = color
        }
    }

    public let kids: [Kid]
    public let events: [Event]
    public let generatedAt: Date

    public init(kids: [Kid], events: [Event] = [], generatedAt: Date = .now) {
        self.kids = kids
        self.events = events
        self.generatedAt = generatedAt
    }

    // Decode tolerantly so a snapshot written by an older build (before events
    // existed) still loads — the widget shows chores while events default empty.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kids = try c.decode([Kid].self, forKey: .kids)
        events = try c.decodeIfPresent([Event].self, forKey: .events) ?? []
        generatedAt = try c.decodeIfPresent(Date.self, forKey: .generatedAt) ?? .now
    }

    /// Family total of today's remaining chores — the headline number.
    public var totalRemaining: Int { kids.reduce(0) { $0 + $1.remaining } }

    /// Sample data for widget placeholders and previews.
    public static var sample: WidgetSnapshot {
        let now = Calendar.current.startOfDay(for: .now)
        return WidgetSnapshot(
            kids: [
                .init(id: "finley", name: "Finley", colorHex: "#1B4F9C", emblemSymbol: "", choresToday: 4, choresDone: 2, tickets: 12),
                .init(id: "arthur", name: "Arthur", colorHex: "#5CB85C", emblemSymbol: "", choresToday: 3, choresDone: 3, tickets: 8),
                .init(id: "maryn", name: "Maryn", colorHex: "#E04E2C", emblemSymbol: "", choresToday: 5, choresDone: 1, tickets: 20),
            ],
            events: [
                .init(id: "e1", title: "Soccer practice", start: now.addingTimeInterval(15 * 3600), isAllDay: false, color: CalendarRGBA(red: 0.11, green: 0.31, blue: 0.61, alpha: 1)),
                .init(id: "e2", title: "Dentist — Maryn", start: now.addingTimeInterval(16.5 * 3600), isAllDay: false, color: CalendarRGBA(red: 0.88, green: 0.31, blue: 0.17, alpha: 1)),
                .init(id: "e3", title: "Library books due", start: now, isAllDay: true, color: CalendarRGBA(red: 0.36, green: 0.72, blue: 0.36, alpha: 1)),
            ]
        )
    }
}
