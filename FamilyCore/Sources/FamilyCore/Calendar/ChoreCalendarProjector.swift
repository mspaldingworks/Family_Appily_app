import Foundation

/// One assigned chore landing on one calendar day for one child — a chore
/// assignment (which is stored per *weekday*, not per date) expanded onto a
/// real date so it can sit on the family calendar next to real events.
public struct ChoreOccurrence: Identifiable, Hashable, Sendable {
    public let id: String
    public let childID: ChildID
    public let choreID: String
    public let label: String
    public let sfSymbol: String
    public let date: Date
    public let isRotationResolved: Bool
    /// Tickets earned and the chore's colour token, so the calendar can show the
    /// same mini card tile as the weekly chart. Filled from the child's ChoreCard.
    public let ticketValue: Int
    public let colorToken: String?

    public init(
        id: String,
        childID: ChildID,
        choreID: String,
        label: String,
        sfSymbol: String,
        date: Date,
        isRotationResolved: Bool,
        ticketValue: Int = 1,
        colorToken: String? = nil
    ) {
        self.id = id
        self.childID = childID
        self.choreID = choreID
        self.label = label
        self.sfSymbol = sfSymbol
        self.date = date
        self.isRotationResolved = isRotationResolved
        self.ticketValue = ticketValue
        self.colorToken = colorToken
    }
}

/// Projects the per-weekday chore assignments onto concrete dates in a window,
/// so the family calendar screen can show each kid's chores tied to their app
/// identity. Pure and testable — it reuses `ChoreResolver` (so rotation-resolved
/// "Weekly Chore" slots come through with their real label) rather than
/// re-deriving anything. Chores stay in SwiftData; this only *reads* them.
public enum ChoreCalendarProjector {
    public static func occurrences(
        in interval: DateInterval,
        children: [ChildID],
        assignments: [ChoreAssignment],
        chores: [Chore],
        rotationEpoch: Date?,
        rotationContract: RotationContract?,
        calendar: Calendar = .current
    ) -> [ChoreOccurrence] {
        var result: [ChoreOccurrence] = []
        var day = calendar.startOfDay(for: interval.start)
        let end = interval.end

        while day <= end {
            // Foundation weekday is 1...7 (Sun...Sat); Weekday is 0...6.
            let weekdayIndex = calendar.component(.weekday, from: day) - 1
            if let weekday = Weekday(rawValue: weekdayIndex) {
                for child in children {
                    let resolved = resolvedChores(
                        for: child, weekday: weekday, on: day,
                        assignments: assignments, chores: chores,
                        rotationEpoch: rotationEpoch, rotationContract: rotationContract
                    )
                    for chore in resolved {
                        result.append(ChoreOccurrence(
                            id: "\(child.rawValue)|\(chore.id)|\(day.timeIntervalSince1970)",
                            childID: child,
                            choreID: chore.id,
                            label: chore.label,
                            sfSymbol: chore.sfSymbol,
                            date: day,
                            isRotationResolved: chore.isRotationResolved,
                            ticketValue: chore.ticketValue,
                            colorToken: chore.colorToken
                        ))
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    private static func resolvedChores(
        for child: ChildID,
        weekday: Weekday,
        on day: Date,
        assignments: [ChoreAssignment],
        chores: [Chore],
        rotationEpoch: Date?,
        rotationContract: RotationContract?
    ) -> [ResolvedChore] {
        if let rotationContract {
            return ChoreResolver.chores(
                for: child, weekday: weekday,
                assignments: assignments, chores: chores,
                rotationEpoch: rotationEpoch, rotationContract: rotationContract,
                on: day
            )
        }
        // No rotation contract available (e.g. a unit test or a decode failure):
        // project the fixed chores only, skipping rotation-resolved slots.
        let raw = child.rawValue
        return assignments
            .filter { $0.childID == raw && $0.weekday == weekday.rawValue }
            .compactMap { assignment in
                guard let chore = chores.first(where: { $0.id == assignment.choreID }),
                      chore.choreType != .rotationResolved else { return nil }
                return ResolvedChore(
                    id: chore.id,
                    label: assignment.displayLabelOverride ?? chore.defaultLabel,
                    sfSymbol: chore.sfSymbol,
                    isRotationResolved: false
                )
            }
    }
}
