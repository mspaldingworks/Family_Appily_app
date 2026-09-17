import Foundation
#if canImport(EventKit)
import EventKit
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// EventKit adapter (CLAUDE.md §6/§8): reads the device's calendars and events
/// so the family screen can aggregate them, with **no third-party SDK**. The
/// household's Google calendars flow in only via the Calendar account the family
/// already has on the device, so nothing about the children leaves Apple's
/// ecosystem (§5). Every EventKit type is flattened to a `Sendable` value before
/// it leaves this file — no `EKEvent`/`EKCalendar` escapes into the view layer.
public final class EventKitCalendarService {
    public enum Access: Sendable { case notDetermined, granted, denied }

    #if canImport(EventKit)
    private let store = EKEventStore()
    #endif

    public init() {}

    /// Current authorization, without prompting. `.writeOnly` counts as denied
    /// here because this screen *reads* events; the chore overlay still shows.
    public var access: Access {
        #if canImport(EventKit)
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .denied, .restricted, .writeOnly: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
        #else
        return .denied
        #endif
    }

    /// Prompts for full calendar access (iOS 17 / macOS 14 API) and returns the
    /// resulting state. Safe to call when already decided — it just resolves.
    public func requestAccess() async -> Access {
        #if canImport(EventKit)
        _ = try? await store.requestFullAccessToEvents()
        #endif
        return access
    }

    /// Every event calendar the device can see, each tagged with the child it
    /// belongs to when its name matches one (a "Finley" calendar → `.finley`).
    public func sources() -> [CalendarSource] {
        #if canImport(EventKit)
        return store.calendars(for: .event)
            .map { cal in
                CalendarSource(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    color: Self.rgba(cal.cgColor),
                    matchedChild: CalendarSource.child(forCalendarTitle: cal.title)
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        #else
        return []
        #endif
    }

    /// Events in `interval`, limited to `calendarIDs` (nil = all). Returns [] if
    /// access hasn't been granted, so callers can always call it safely.
    public func events(in interval: DateInterval, calendarIDs: Set<String>?) -> [CalendarEventItem] {
        #if canImport(EventKit)
        guard access == .granted else { return [] }
        let all = store.calendars(for: .event)
        let chosen = calendarIDs.map { ids in all.filter { ids.contains($0.calendarIdentifier) } } ?? all
        guard !chosen.isEmpty else { return [] }

        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: chosen)
        return store.events(matching: predicate).map { event in
            let calendarTitle = event.calendar.title
            return CalendarEventItem(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "(untitled)",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                calendarID: event.calendar.calendarIdentifier,
                calendarTitle: calendarTitle,
                color: Self.rgba(event.calendar.cgColor),
                childID: CalendarSource.child(forCalendarTitle: calendarTitle)
            )
        }
        #else
        return []
        #endif
    }

    private static let markerPrefix = "[FAMILYAPPILY:"

    /// Reconciles weekly recurring all-day chore events in each child's own
    /// calendar (matched by name) to `desired`: creates missing ones, removes
    /// stale ones, and refreshes changed titles — touching **only** events this
    /// app tagged (never the family's real events). Requires full (write)
    /// access; a no-op that returns zeros otherwise. Pass `desired: []` to
    /// remove everything write-through added (i.e. when the adult turns it off).
    public func syncFixedChoreEvents(desired: [FixedChoreEvent], now: Date = .now) -> ChoreSyncSummary {
        #if canImport(EventKit)
        guard access == .granted else { return ChoreSyncSummary(created: 0, removed: 0, skippedChildren: []) }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 35, to: start) ?? start

        // Writable calendars matched to a child by name (skip read-only ones
        // like holidays/subscriptions, and any calendar not named for a child).
        var calByChild: [ChildID: EKCalendar] = [:]
        for cal in store.calendars(for: .event) where cal.allowsContentModifications {
            if let child = CalendarSource.child(forCalendarTitle: cal.title) { calByChild[child] = cal }
        }

        let desiredByChild = Dictionary(grouping: desired, by: \.childID)
        var created = 0
        var removed = 0
        let skipped = Set(desired.map(\.childID)).filter { calByChild[$0] == nil }

        for (child, cal) in calByChild {
            let wantByMarker = Dictionary(
                (desiredByChild[child] ?? []).map { ($0.marker, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            // Our previously-written events in this calendar, within the window.
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [cal])
            var existingByMarker: [String: EKEvent] = [:]
            for event in store.events(matching: predicate) {
                guard let marker = Self.marker(in: event.notes), existingByMarker[marker] == nil else { continue }
                existingByMarker[marker] = event
            }

            // Create the ones we want but don't have yet.
            for (marker, want) in wantByMarker where existingByMarker[marker] == nil {
                let event = EKEvent(eventStore: store)
                event.calendar = cal
                event.title = want.label
                event.isAllDay = true
                let day = Self.nextDate(weekday: want.weekday, from: start, calendar: calendar)
                event.startDate = day
                event.endDate = day
                event.notes = "Family Appily chore\n\(Self.markerPrefix)\(marker)]"
                event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil))
                if (try? store.save(event, span: .thisEvent, commit: false)) != nil { created += 1 }
            }

            // Remove ours that are no longer wanted; refresh changed titles.
            for (marker, event) in existingByMarker {
                if let want = wantByMarker[marker] {
                    if event.title != want.label {
                        event.title = want.label
                        try? store.save(event, span: .futureEvents, commit: false)
                    }
                } else if (try? store.remove(event, span: .futureEvents, commit: false)) != nil {
                    removed += 1
                }
            }
        }

        try? store.commit()
        return ChoreSyncSummary(created: created, removed: removed, skippedChildren: Array(skipped))
        #else
        return ChoreSyncSummary(created: 0, removed: 0, skippedChildren: [])
        #endif
    }

    #if canImport(EventKit)
    private static func rgba(_ cgColor: CGColor?) -> CalendarRGBA? {
        guard let cgColor, let components = cgColor.components else { return nil }
        switch components.count {
        case 2: // grayscale + alpha
            let white = Double(components[0])
            return CalendarRGBA(red: white, green: white, blue: white, alpha: Double(components[1]))
        case 4...: // RGBA
            return CalendarRGBA(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2]), alpha: Double(components[3]))
        default:
            return nil
        }
    }

    private static func marker(in notes: String?) -> String? {
        guard let notes, let open = notes.range(of: markerPrefix) else { return nil }
        let rest = notes[open.upperBound...]
        guard let close = rest.firstIndex(of: "]") else { return nil }
        return String(rest[..<close])
    }

    private static func nextDate(weekday: Int, from: Date, calendar: Calendar) -> Date {
        let targetFoundationWeekday = weekday + 1  // 0…6 → 1…7 (Sun…Sat)
        let start = calendar.startOfDay(for: from)
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: start),
               calendar.component(.weekday, from: day) == targetFoundationWeekday {
                return day
            }
        }
        return start
    }
    #endif
}
