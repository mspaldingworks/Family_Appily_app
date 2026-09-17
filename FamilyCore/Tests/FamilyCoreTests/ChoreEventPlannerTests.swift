import Foundation
import Testing
@testable import FamilyCore

struct ChoreEventPlannerTests {
    @Test func excludesRotationAndMapsLabels() {
        let chores = [
            Chore(id: "make-bed", type: .fixed, defaultLabel: "Make the bed", sfSymbol: "bed.double.fill", category: nil, note: nil),
            Chore(id: "weekly-chore", type: .rotationResolved, defaultLabel: "Weekly Chore", sfSymbol: "star.circle", category: nil, note: nil),
            Chore(id: "dishes", type: .fixed, defaultLabel: "Empty the dishwasher", sfSymbol: "dishwasher", category: nil, note: nil),
        ]
        let assignments = [
            ChoreAssignment(childID: "finley", choreID: "make-bed", weekday: .monday, displayLabelOverride: nil),
            ChoreAssignment(childID: "finley", choreID: "weekly-chore", weekday: .sunday, displayLabelOverride: nil),
            ChoreAssignment(childID: "maryn", choreID: "dishes", weekday: .tuesday, displayLabelOverride: "Load & run dishwasher"),
        ]

        let events = ChoreEventPlanner.fixedEvents(assignments: assignments, chores: chores)

        #expect(events.count == 2) // rotation-resolved slot excluded
        #expect(events.contains { $0.childID == .finley && $0.choreID == "make-bed" && $0.weekday == Weekday.monday.rawValue && $0.label == "Make the bed" })
        #expect(events.contains { $0.childID == .maryn && $0.weekday == Weekday.tuesday.rawValue && $0.label == "Load & run dishwasher" })
        #expect(!events.contains { $0.choreID == "weekly-chore" })
    }

    @Test func markerEncodesChildChoreWeekday() {
        let event = FixedChoreEvent(childID: .arthur, choreID: "trash", weekday: 3, label: "Take out trash")
        #expect(event.marker == "arthur|trash|3")
    }
}
