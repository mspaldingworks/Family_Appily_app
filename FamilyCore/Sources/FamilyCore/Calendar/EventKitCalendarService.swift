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
    #endif
}
