import FamilyCore
import SwiftData
import SwiftUI

/// Per-child weekly chore assignment for an adult (CLAUDE.md §4): which chores
/// this child does on each day. Grouped by weekday (Sun→Sat, the chart's week),
/// one section per day. Adding is a tap menu of that day's not-yet-assigned
/// chores; removing is a tap on the row's minus button — never swipe-only, per
/// §3.1. Edits save straight to the shared store and show on the child's chart.
struct ChoreAssignmentEditorView: View {
    let child: Child

    @Environment(\.modelContext) private var modelContext
    @Query private var assignments: [ChoreAssignment]
    @Query(sort: \Chore.defaultLabel) private var chores: [Chore]

    var body: some View {
        List {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                daySection(weekday)
            }
        }
        .navigationTitle("\(child.name)'s chores")
    }

    private func daySection(_ weekday: Weekday) -> some View {
        let dayAssignments = assignments(on: weekday)
        let available = availableChores(on: weekday)
        return Section(weekday.shortLabel) {
            if dayAssignments.isEmpty {
                Text("No chores")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(dayAssignments) { assignmentRow($0) }
            if !available.isEmpty {
                addMenu(for: weekday, available: available)
            }
        }
    }

    private func assignmentRow(_ assignment: ChoreAssignment) -> some View {
        let chore = chore(for: assignment)
        let text = label(for: assignment)
        return HStack(spacing: 12) {
            Image(systemName: chore?.sfSymbol ?? "circle")
                .frame(width: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(text)
                if chore?.choreType == .rotationResolved {
                    Text("Family rotation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive) {
                remove(assignment)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Remove \(text)")
        }
    }

    private func addMenu(for weekday: Weekday, available: [Chore]) -> some View {
        Menu {
            ForEach(available) { chore in
                Button {
                    add(chore, to: weekday)
                } label: {
                    Label(menuLabel(chore), systemImage: chore.sfSymbol)
                }
            }
        } label: {
            Label("Add chore", systemImage: "plus.circle")
        }
        .frame(minHeight: 44)
    }

    // MARK: Data

    private func assignments(on weekday: Weekday) -> [ChoreAssignment] {
        assignments
            .filter { $0.childID == child.id && $0.weekday == weekday.rawValue }
            .sorted { label(for: $0).localizedCaseInsensitiveCompare(label(for: $1)) == .orderedAscending }
    }

    private func availableChores(on weekday: Weekday) -> [Chore] {
        let assignedIDs = Set(
            assignments.filter { $0.childID == child.id && $0.weekday == weekday.rawValue }.map(\.choreID)
        )
        return chores.filter { !assignedIDs.contains($0.id) }
    }

    private func chore(for assignment: ChoreAssignment) -> Chore? {
        chores.first { $0.id == assignment.choreID }
    }

    private func label(for assignment: ChoreAssignment) -> String {
        assignment.displayLabelOverride ?? chore(for: assignment)?.defaultLabel ?? assignment.choreID
    }

    private func menuLabel(_ chore: Chore) -> String {
        chore.choreType == .rotationResolved ? "\(chore.defaultLabel) · rotation" : chore.defaultLabel
    }

    private func add(_ chore: Chore, to weekday: Weekday) {
        modelContext.insert(ChoreAssignment(childID: child.id, choreID: chore.id, weekday: weekday, displayLabelOverride: nil))
        try? modelContext.save()
    }

    private func remove(_ assignment: ChoreAssignment) {
        modelContext.delete(assignment)
        try? modelContext.save()
    }
}
