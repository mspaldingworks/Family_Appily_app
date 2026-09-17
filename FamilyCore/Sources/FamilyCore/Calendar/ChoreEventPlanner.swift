import Foundation

/// A fixed (non-rotation) chore assignment to be mirrored into a child's own
/// calendar as a weekly all-day event: (child, chore, weekday, label).
public struct FixedChoreEvent: Hashable, Sendable {
    public let childID: ChildID
    public let choreID: String
    public let weekday: Int          // 0 = Sunday … 6 = Saturday
    public let label: String

    public init(childID: ChildID, choreID: String, weekday: Int, label: String) {
        self.childID = childID
        self.choreID = choreID
        self.weekday = weekday
        self.label = label
    }

    /// Stable tag stored in the event's notes so write-through only ever touches
    /// its own events — the family's real events never carry this.
    public var marker: String { "\(childID.rawValue)|\(choreID)|\(weekday)" }
}

/// Outcome of a write-through pass, for surfacing to the adult.
public struct ChoreSyncSummary: Sendable {
    public let created: Int
    public let removed: Int
    /// Children whose chores couldn't be written because no writable calendar
    /// named for them exists on this device.
    public let skippedChildren: [ChildID]

    public init(created: Int, removed: Int, skippedChildren: [ChildID]) {
        self.created = created
        self.removed = removed
        self.skippedChildren = skippedChildren
    }
}

/// Turns the stored chore assignments into the set of events write-through
/// should keep in each child's calendar. Pure and testable; the EventKit side
/// (`EventKitCalendarService.syncFixedChoreEvents`) just reconciles to this.
public enum ChoreEventPlanner {
    /// Fixed (non-rotation) assignments only. Rotation-resolved "Weekly Chore"
    /// slots are skipped: their assignee and label rotate every three weeks, so
    /// a plain weekly recurrence can't represent them (a v1 limitation).
    public static func fixedEvents(assignments: [ChoreAssignment], chores: [Chore]) -> [FixedChoreEvent] {
        assignments.compactMap { assignment in
            guard let child = ChildID(rawValue: assignment.childID),
                  let chore = chores.first(where: { $0.id == assignment.choreID }),
                  chore.choreType != .rotationResolved else { return nil }
            return FixedChoreEvent(
                childID: child,
                choreID: chore.id,
                weekday: assignment.weekday,
                label: assignment.displayLabelOverride ?? chore.defaultLabel
            )
        }
    }
}
