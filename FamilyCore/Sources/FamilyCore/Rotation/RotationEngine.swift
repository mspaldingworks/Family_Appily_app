import Foundation

/// Computes family-rotation chore assignments from the formula in rotation.json,
/// rather than storing a grid — so the rotation runs forever instead of
/// expiring after the physical chart's seven printed week columns.
///
/// Formula: `assignee(chore, weekIndex) = cycle[(chore.offset + weekIndex) mod 3]`,
/// `cycle = [finley, maryn, arthur]`, `weekIndex` is 0-based from `rotationEpoch`
/// (the Sunday Week 1 began).
public struct RotationEngine: Sendable {
    public static let cycle: [ChildID] = [.finley, .maryn, .arthur]

    private let calendar: Calendar

    public init(calendar: Calendar = .init(identifier: .gregorian)) {
        var calendar = calendar
        calendar.firstWeekday = 1 // Sunday
        self.calendar = calendar
    }

    /// nil if `rotationEpoch` hasn't been set yet — callers must show the
    /// one-time adult setup step ("Which Sunday did Week 1 begin?") rather
    /// than guessing a current week. See CLAUDE.md §11 and PHASE0_PROMPT.md.
    public func weekIndex(epoch: Date, on date: Date = .now) -> Int {
        let epochStart = calendar.startOfDay(for: epoch)
        let dayStart = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: epochStart, to: dayStart).day ?? 0
        // floorDiv so dates before the epoch (shouldn't happen in practice) don't
        // round toward zero into the wrong week.
        return Int(floor(Double(days) / 7.0))
    }

    public func assignee(offset: Int, weekIndex: Int) -> ChildID {
        let index = ((offset + weekIndex) % 3 + 3) % 3 // non-negative modulo
        return Self.cycle[index]
    }

    /// The rotation chores assigned to one child in a given week.
    public func chores(for childID: ChildID, weekIndex: Int, in rotationChores: [RotationContract.RotationChoreContract]) -> [RotationContract.RotationChoreContract] {
        rotationChores.filter { assignee(offset: $0.offset, weekIndex: weekIndex) == childID }
    }
}
