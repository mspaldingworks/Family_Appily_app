import Foundation

/// A chore as it should render for one child on one day — the "weekly-chore"
/// rotation placeholder already resolved to its real label, per CLAUDE.md §7.7:
/// "Do not ask an adult to type it in each week."
public struct ResolvedChore: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let sfSymbol: String
    public let isRotationResolved: Bool

    public init(id: String, label: String, sfSymbol: String, isRotationResolved: Bool) {
        self.id = id
        self.label = label
        self.sfSymbol = sfSymbol
        self.isRotationResolved = isRotationResolved
    }
}

public enum ChoreResolver {
    /// Resolves one child's chore list for one weekday, filling any
    /// `rotation-resolved` slot with the real chore(s) the rotation assigns
    /// that child this week. `rotationEpoch` nil means the one-time setup
    /// step hasn't happened yet — callers should show that instead of a chart.
    public static func chores(
        for childID: ChildID,
        weekday: Weekday,
        assignments: [ChoreAssignment],
        chores: [Chore],
        rotationEpoch: Date?,
        rotationContract: RotationContract,
        on date: Date = .now,
        engine: RotationEngine = RotationEngine()
    ) -> [ResolvedChore] {
        let childIDRaw = childID.rawValue
        let dayAssignments = assignments.filter { $0.childID == childIDRaw && $0.weekday == weekday.rawValue }

        return dayAssignments.compactMap { assignment -> ResolvedChore? in
            guard let chore = chores.first(where: { $0.id == assignment.choreID }) else { return nil }

            if chore.choreType == .rotationResolved {
                guard let epoch = rotationEpoch else {
                    return ResolvedChore(id: chore.id, label: "Set up rotation start date", sfSymbol: "questionmark.circle", isRotationResolved: true)
                }
                let weekIndex = engine.weekIndex(epoch: epoch, on: date)
                let assignedRotationChores = engine.chores(for: childID, weekIndex: weekIndex, in: rotationContract.chores)
                // Family rotation gives each child up to 2 chores/week, matching
                // the two "Weekly Chore" slots (Sunday/Saturday) on their chart.
                // If more than one lands on this exact slot, combine the labels.
                guard !assignedRotationChores.isEmpty else { return nil }
                let label = assignedRotationChores.map(\.label).joined(separator: " + ")
                let symbol = assignedRotationChores.first?.sfSymbol ?? chore.sfSymbol
                return ResolvedChore(id: chore.id, label: label, sfSymbol: symbol, isRotationResolved: true)
            }

            let label = assignment.displayLabelOverride ?? chore.defaultLabel
            return ResolvedChore(id: chore.id, label: label, sfSymbol: chore.sfSymbol, isRotationResolved: false)
        }
    }
}
