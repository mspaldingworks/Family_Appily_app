import Foundation

/// One chore occurrence on the family board, with its completion + carry-over state.
public struct DashChore: Identifiable, Sendable {
    public let occurrence: ChoreOccurrence
    public let isDone: Bool
    /// Was due earlier this week and still not done — carried over to today.
    public let isHeldOver: Bool
    public var id: String { occurrence.id }

    public init(occurrence: ChoreOccurrence, isDone: Bool, isHeldOver: Bool) {
        self.occurrence = occurrence
        self.isDone = isDone
        self.isHeldOver = isHeldOver
    }
}

/// One upcoming day of the week and its chores.
public struct ChoreDayGroup: Identifiable, Sendable {
    public let date: Date
    public let chores: [DashChore]
    public var id: Date { date }

    public init(date: Date, chores: [DashChore]) {
        self.date = date
        self.chores = chores
    }
}

/// What's due **today** — including anything **held over** from earlier this week
/// and not yet done — and the rest of the week grouped by upcoming day.
public struct ChoreBoard: Sendable {
    public let today: [DashChore]
    public let upcoming: [ChoreDayGroup]

    public init(today: [DashChore], upcoming: [ChoreDayGroup]) {
        self.today = today
        self.upcoming = upcoming
    }
}

public enum WeeklyChoreBoard {
    /// Builds the board from a week's chore occurrences. `doneKeys` marks the
    /// completed occurrences, one entry per completion, keyed to match
    /// `key(for:)`. Pure and testable — carry-over is derived here, nowhere else.
    public static func build(
        occurrences: [ChoreOccurrence],
        doneKeys: Set<String>,
        today: Date,
        calendar: Calendar = .current
    ) -> ChoreBoard {
        let todayStart = calendar.startOfDay(for: today)

        let all = occurrences.map { occ -> DashChore in
            let day = calendar.startOfDay(for: occ.date)
            let done = doneKeys.contains(key(childID: occ.childID.rawValue, choreID: occ.choreID, date: occ.date, calendar: calendar))
            return DashChore(occurrence: occ, isDone: done, isHeldOver: day < todayStart && !done)
        }

        // Today = due today, plus earlier-this-week chores not yet done (held over).
        let todayList = all
            .filter { dash in
                let day = calendar.startOfDay(for: dash.occurrence.date)
                return calendar.isDate(day, inSameDayAs: todayStart) || (day < todayStart && !dash.isDone)
            }
            .sorted(by: ordered)

        // Upcoming = later this week, grouped by day.
        let future = all.filter { calendar.startOfDay(for: $0.occurrence.date) > todayStart }
        let byDay = Dictionary(grouping: future) { calendar.startOfDay(for: $0.occurrence.date) }
        let upcoming = byDay.keys.sorted().map { day in
            ChoreDayGroup(date: day, chores: byDay[day, default: []].sorted(by: ordered))
        }

        return ChoreBoard(today: todayList, upcoming: upcoming)
    }

    /// Stable key for a (child, chore, day) completion — build the same key from
    /// each `Completion` when assembling `doneKeys`.
    public static func key(childID: String, choreID: String, date: Date, calendar: Calendar = .current) -> String {
        "\(childID)|\(choreID)|\(calendar.startOfDay(for: date).timeIntervalSince1970)"
    }

    private static func ordered(_ a: DashChore, _ b: DashChore) -> Bool {
        if a.isHeldOver != b.isHeldOver { return a.isHeldOver && !b.isHeldOver }  // held-over first
        if a.occurrence.childID.rawValue != b.occurrence.childID.rawValue {
            return a.occurrence.childID.rawValue < b.occurrence.childID.rawValue
        }
        return a.occurrence.label < b.occurrence.label
    }
}
