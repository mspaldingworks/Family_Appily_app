import FamilyCore
import SwiftData
import SwiftUI

/// Seven day cards, four in the top row and three in the bottom, week
/// beginning Sunday — preserved on iPad/Mac, collapsing to a vertical list
/// only on iPhone and at accessibility Dynamic Type sizes, per CLAUDE.md §7.2.
public struct WeeklyChartView: View {
    let child: Child

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query private var assignments: [ChoreAssignment]
    @Query private var chores: [Chore]
    @Query private var completions: [Completion]
    @Query private var rotationChores: [RotationChore]

    @Environment(\.modelContext) private var modelContext

    @AppStorage("rotationEpochISO8601") private var rotationEpochISO8601: String = ""
    @State private var showingRotationSetup = false

    public init(child: Child) {
        self.child = child
    }

    private var rotationEpoch: Date? {
        guard !rotationEpochISO8601.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: rotationEpochISO8601)
    }

    private var rotationContract: RotationContract? {
        try? BundledContractSource().loadRotation()
    }

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var completedIDsToday: Set<String> {
        let childIDRaw = child.id
        return Set(completions.filter { $0.childID == childIDRaw && Calendar.current.isDate($0.date, inSameDayAs: today) }.map(\.choreID))
    }

    private var useVerticalList: Bool {
        horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }

    public var body: some View {
        ScrollView {
            if rotationEpoch == nil {
                RotationSetupPrompt(onSet: setRotationEpoch)
                    .padding(.bottom)
            }

            if useVerticalList {
                VStack(spacing: 16) {
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        dayCard(for: weekday)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Weekday.allCases.prefix(4), id: \.self) { weekday in
                            dayCard(for: weekday)
                        }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Weekday.allCases.suffix(3), id: \.self) { weekday in
                            dayCard(for: weekday)
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle(child.name)
    }

    @ViewBuilder
    private func dayCard(for weekday: Weekday) -> some View {
        if let rotationContract, let childID = child.childID {
            let resolved = ChoreResolver.chores(
                for: childID, weekday: weekday, assignments: assignments, chores: chores,
                rotationEpoch: rotationEpoch, rotationContract: rotationContract
            )
            DayCardFrame(child: child, weekday: weekday, chores: resolved, completedChoreIDs: completedIDsToday) { chore in
                toggle(chore: chore)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func toggle(chore: ResolvedChore) {
        let childID = child.id
        let choreID = chore.id
        let day = today
        let existing = completions.first { $0.childID == childID && $0.choreID == choreID && Calendar.current.isDate($0.date, inSameDayAs: day) }

        if let existing {
            modelContext.delete(existing)
        } else {
            modelContext.insert(Completion(childID: childID, choreID: choreID, date: day))
        }
        try? modelContext.save()
    }

    private func setRotationEpoch(_ date: Date) {
        rotationEpochISO8601 = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
    }
}

private struct RotationSetupPrompt: View {
    let onSet: (Date) -> Void
    @State private var selectedDate = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One-time setup")
                .font(.headline)
            Text("Which Sunday did Week 1 of the family rotation begin? This fills in the \"Weekly Chore\" slots automatically from then on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            DatePicker("Week 1 start", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
            Button("Save") { onSet(selectedDate) }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.yellow.opacity(0.15)))
    }
}
