import FamilyCore
import SwiftData
import SwiftUI

/// The compiled family calendar (CLAUDE.md §6): one screen that aggregates the
/// family's calendars — including the "Finley/Arthur/Maryn" Google calendars,
/// read through EventKit so nothing leaves Apple's ecosystem (§5) — and overlays
/// each kid's chore assignments onto their dates in that kid's identity colour.
///
/// Chores render straight from SwiftData, so this screen is useful the moment
/// it opens, even before calendar access is granted; real events fill in on top
/// once the family's account is connected. An adaptive admin-style surface, so
/// it uses system colours that follow Light/Dark Mode; identity is carried by a
/// `dotFill` colour bar (a shape, per the ChildTheme contract) plus the name.
struct FamilyCalendarView: View {
    @Query(sort: \Child.name) private var children: [Child]
    @Query private var assignments: [ChoreAssignment]
    @Query private var chores: [Chore]
    @Query private var choreCards: [ChoreCard]

    @AppStorage("rotationEpochISO8601") private var rotationEpochISO8601 = ""

    @State private var service = EventKitCalendarService()
    @State private var access: EventKitCalendarService.Access = .notDetermined
    @State private var events: [CalendarEventItem] = []
    @State private var sources: [CalendarSource] = []
    @State private var lastSync: ChoreSyncSummary?
    @AppStorage("familyCalendar.hiddenIDs") private var hiddenIDsCSV = ""
    @AppStorage("familyCalendar.writeThrough") private var writeThroughEnabled = false

    private let horizonDays = 14

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if access != .granted { connectBanner }
                if writeThroughEnabled, let sync = lastSync, !sync.skippedChildren.isEmpty {
                    writeThroughWarning(sync.skippedChildren)
                }

                let days = buildDays()
                if days.isEmpty {
                    ContentUnavailableView(
                        "Nothing scheduled",
                        systemImage: "calendar",
                        description: Text("Chores and events for the next two weeks will show up here.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(days) { day in
                        daySection(day)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Family Calendar")
        .toolbar {
            if access == .granted && !sources.isEmpty {
                ToolbarItem(placement: .primaryAction) { calendarFilterMenu }
            }
        }
        .task {
            access = service.access
            if access == .granted { await reload(); syncChoreEvents() }
        }
        .onAppear { syncChoreEvents() }
        .onChange(of: writeThroughEnabled) { _, _ in syncChoreEvents() }
    }

    // MARK: Data

    private var interval: DateInterval {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: horizonDays, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private var rotationEpoch: Date? {
        rotationEpochISO8601.isEmpty ? nil : ISO8601DateFormatter().date(from: rotationEpochISO8601)
    }

    private var rotationContract: RotationContract? {
        try? BundledContractSource().loadRotation()
    }

    private var occurrences: [ChoreOccurrence] {
        ChoreCalendarProjector.occurrences(
            in: interval,
            children: children.compactMap(\.childID),
            assignments: assignments,
            chores: chores,
            rotationEpoch: rotationEpoch,
            rotationContract: rotationContract
        )
    }

    /// One-off, due-date chores (which keep no recurring assignment rows) shown
    /// on their date, in the kid's identity colour like any other chore.
    private var dueDateOccurrences: [ChoreOccurrence] {
        let calendar = Calendar.current
        return choreCards.compactMap { card in
            guard !card.scheduleIsRecurring, let due = card.dueDate,
                  interval.contains(due), let child = ChildID(rawValue: card.childID) else { return nil }
            return ChoreOccurrence(
                id: "due|\(card.id)",
                childID: child,
                label: card.label,
                sfSymbol: card.sfSymbol,
                date: calendar.startOfDay(for: due),
                isRotationResolved: false
            )
        }
    }

    private var childByID: [ChildID: Child] {
        Dictionary(children.compactMap { child in child.childID.map { ($0, child) } }, uniquingKeysWith: { first, _ in first })
    }

    /// Calendars the family has hidden, persisted so the curation sticks across
    /// launches (it was previously in-memory `@State` and reset every time).
    private var hiddenCalendarIDs: Set<String> {
        Set(hiddenIDsCSV.split(separator: ",").map(String.init))
    }

    private func hideCalendar(_ id: String) {
        var ids = hiddenCalendarIDs
        ids.insert(id)
        hiddenIDsCSV = ids.sorted().joined(separator: ",")
        Task { await reload() }
    }

    private func showAllCalendars() {
        hiddenIDsCSV = ""
        Task { await reload() }
    }

    /// Writes (or, when the toggle is off, clears) each kid's chores in their
    /// own calendar. No-op unless calendar access has been granted.
    @MainActor private func syncChoreEvents() {
        guard access == .granted else { return }
        lastSync = service.syncFixedChoreEvents(
            desired: writeThroughEnabled ? ChoreEventPlanner.fixedEvents(assignments: assignments, chores: chores) : []
        )
    }

    @MainActor private func reload() async {
        sources = service.sources()
        let visible = Set(sources.map(\.id)).subtracting(hiddenCalendarIDs)
        events = service.events(in: interval, calendarIDs: visible)
    }

    // MARK: Day grouping

    private enum AgendaItem: Identifiable {
        case chore(ChoreOccurrence)
        case event(CalendarEventItem)

        var id: String {
            switch self {
            case .chore(let c): return "chore-\(c.id)"
            case .event(let e): return "event-\(e.id)"
            }
        }

        /// All-day items and chores sort to the top of a day; timed events by start.
        var sortTime: Date? {
            switch self {
            case .chore: return nil
            case .event(let e): return e.isAllDay ? nil : e.start
            }
        }
    }

    private struct DayBucket: Identifiable {
        let id: Date
        let items: [AgendaItem]
    }

    private func buildDays() -> [DayBucket] {
        let cal = Calendar.current
        var byDay: [Date: [AgendaItem]] = [:]
        for occ in occurrences + dueDateOccurrences {
            byDay[cal.startOfDay(for: occ.date), default: []].append(.chore(occ))
        }
        for event in events where interval.contains(event.start) {
            byDay[cal.startOfDay(for: event.start), default: []].append(.event(event))
        }
        return byDay.keys.sorted().map { key in
            let items = byDay[key, default: []].sorted { lhs, rhs in
                switch (lhs.sortTime, rhs.sortTime) {
                case (nil, nil): return false
                case (nil, _): return true
                case (_, nil): return false
                case (let l?, let r?): return l < r
                }
            }
            return DayBucket(id: key, items: items)
        }
    }

    // MARK: Views

    private func daySection(_ day: DayBucket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayHeader(day.id))
                .font(.headline)
            ForEach(day.items) { item in
                switch item {
                case .chore(let occ): choreRow(occ)
                case .event(let event): eventRow(event)
                }
            }
        }
    }

    private func choreRow(_ occ: ChoreOccurrence) -> some View {
        let theme = ChildTheme.theme(for: occ.childID)
        let name = childByID[occ.childID]?.name ?? occ.childID.rawValue.capitalized
        return HStack(spacing: 10) {
            Capsule().fill(theme.dotFill).frame(width: 5, height: 36)
            Image(systemName: occ.sfSymbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(occ.label)
                    .font(.body)
            }
            Spacer()
            Text("Chore")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.dotFill.opacity(0.10)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)'s chore: \(occ.label)")
    }

    private func eventRow(_ event: CalendarEventItem) -> some View {
        let color = event.color.map(Color.init(rgba:)) ?? .secondary
        return HStack(spacing: 10) {
            Capsule().fill(color).frame(width: 5, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.body)
                Text(eventSubtitle(event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(eventSubtitle(event))")
    }

    @ViewBuilder private var connectBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("See your family's calendars here", systemImage: "calendar.badge.plus")
                .font(.headline)
            if access == .notDetermined {
                Text("Add your Google/Apple calendars alongside each kid's chores — read-only, and only the calendars you choose.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Show our calendars") {
                    Task {
                        access = await service.requestAccess()
                        if access == .granted { await reload() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
            } else {
                Text("Calendar access is off. Turn it on in Settings ▸ Family Appily to add your family's events. Chores still show below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(0.12)))
    }

    private var calendarFilterMenu: some View {
        Menu {
            // Only the calendars currently shown are listed; tapping one removes
            // it. Hidden calendars are deliberately not offered here — the single
            // "Show all calendars" reset is the only way back, so this stays a
            // short list of just the family's chosen calendars.
            ForEach(sources.filter { !hiddenCalendarIDs.contains($0.id) }) { source in
                Button {
                    hideCalendar(source.id)
                } label: {
                    Label(source.title, systemImage: "checkmark.square.fill")
                }
            }
            if !hiddenCalendarIDs.isEmpty {
                Divider()
                Button {
                    showAllCalendars()
                } label: {
                    Label("Show all calendars", systemImage: "arrow.counterclockwise")
                }
            }
        } label: {
            Label("Calendars", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    private func writeThroughWarning(_ kids: [ChildID]) -> some View {
        let names = kids.map { childByID[$0]?.name ?? $0.rawValue.capitalized }.joined(separator: ", ")
        return Label(
            "Add a calendar named \(names) to this device to sync their chores.",
            systemImage: "exclamationmark.triangle"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Formatting

    private func dayHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today · " + Self.headerFormatter.string(from: date) }
        if cal.isDateInTomorrow(date) { return "Tomorrow · " + Self.headerFormatter.string(from: date) }
        return Self.headerFormatter.string(from: date)
    }

    private func eventSubtitle(_ event: CalendarEventItem) -> String {
        let time = event.isAllDay
            ? "All day"
            : "\(Self.timeFormatter.string(from: event.start))–\(Self.timeFormatter.string(from: event.end))"
        return "\(time) · \(event.calendarTitle)"
    }

    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

private extension Color {
    init(rgba: CalendarRGBA) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}

// MARK: Previews

@MainActor private func previewContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: Child.self, Chore.self, ChoreAssignment.self, ChoreCard.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    ctx.insert(Child(id: "finley", name: "Finley", motif: "pizza", cardFrame: "book",
                     primaryAvatar: "finley", alternateAvatar: nil,
                     topCornerMotif: "cap", bottomCornerMotif: "hoodie", titleColorToken: "green"))
    ctx.insert(Child(id: "maryn", name: "Maryn", motif: "penguin", cardFrame: "sign",
                     primaryAvatar: "maryn", alternateAvatar: nil,
                     topCornerMotif: "flower", bottomCornerMotif: "ice", titleColorToken: "red"))
    ctx.insert(Chore(id: "make-bed", type: .fixed, defaultLabel: "Make the bed",
                     sfSymbol: "bed.double.fill", category: nil, note: nil, ticketValue: 4))
    ctx.insert(Chore(id: "dishes", type: .fixed, defaultLabel: "Empty the dishwasher",
                     sfSymbol: "dishwasher.fill", category: nil, note: nil, ticketValue: 2))
    for weekday in Weekday.allCases {
        ctx.insert(ChoreAssignment(childID: "finley", choreID: "make-bed", weekday: weekday, displayLabelOverride: nil))
        ctx.insert(ChoreAssignment(childID: "maryn", choreID: "dishes", weekday: weekday, displayLabelOverride: nil))
    }
    return container
}

#Preview("Family Calendar") {
    NavigationStack { FamilyCalendarView() }
        .modelContainer(previewContainer())
}

#Preview("AX5") {
    NavigationStack { FamilyCalendarView() }
        .modelContainer(previewContainer())
        .dynamicTypeSize(.accessibility5)
}

#Preview("Dark mode") {
    NavigationStack { FamilyCalendarView() }
        .modelContainer(previewContainer())
        .preferredColorScheme(.dark)
}
