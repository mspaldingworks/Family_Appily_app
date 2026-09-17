import Foundation
import Testing
@testable import FamilyCore

struct ChoreCalendarProjectorTests {
    private let calendar = Calendar(identifier: .gregorian)
    private func week() -> DateInterval {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))! // Sunday
        let end = calendar.date(byAdding: .day, value: 6, to: start)!                  // Saturday
        return DateInterval(start: start, end: end)
    }

    @Test func projectsFixedAssignmentOntoItsWeekday() {
        let chore = Chore(id: "make-bed", type: .fixed, defaultLabel: "Make the bed", sfSymbol: "bed.double.fill", category: nil, note: nil)
        let assignment = ChoreAssignment(childID: "finley", choreID: "make-bed", weekday: .monday, displayLabelOverride: nil)

        let occurrences = ChoreCalendarProjector.occurrences(
            in: week(), children: [.finley],
            assignments: [assignment], chores: [chore],
            rotationEpoch: nil, rotationContract: nil, calendar: calendar
        )

        #expect(occurrences.count == 1) // exactly one Monday in the window
        let monday = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        #expect(occurrences.first?.childID == .finley)
        #expect(occurrences.first?.label == "Make the bed")
        #expect(occurrences.first.map { calendar.isDate($0.date, inSameDayAs: monday) } == true)
    }

    @Test func skipsRotationSlotsWhenNoContract() {
        let rotationChore = Chore(id: "weekly-chore", type: .rotationResolved, defaultLabel: "Weekly Chore", sfSymbol: "star.circle", category: nil, note: nil)
        let assignment = ChoreAssignment(childID: "finley", choreID: "weekly-chore", weekday: .sunday, displayLabelOverride: nil)

        let occurrences = ChoreCalendarProjector.occurrences(
            in: week(), children: [.finley],
            assignments: [assignment], chores: [rotationChore],
            rotationEpoch: nil, rotationContract: nil, calendar: calendar
        )

        #expect(occurrences.isEmpty) // no contract → rotation slot can't resolve, so it's skipped
    }

    @Test func honoursDisplayLabelOverride() {
        let chore = Chore(id: "dishes", type: .fixed, defaultLabel: "Empty the dishwasher", sfSymbol: "dishwasher", category: nil, note: nil)
        let assignment = ChoreAssignment(childID: "maryn", choreID: "dishes", weekday: .tuesday, displayLabelOverride: "Load & run dishwasher")

        let occurrences = ChoreCalendarProjector.occurrences(
            in: week(), children: [.maryn],
            assignments: [assignment], chores: [chore],
            rotationEpoch: nil, rotationContract: nil, calendar: calendar
        )

        #expect(occurrences.count == 1)
        #expect(occurrences.first?.label == "Load & run dishwasher")
    }
}
