import Foundation
import Testing
@testable import FamilyCore

struct ChoreResolverTests {
    @Test func resolvesRotationSlotToRealChoreLabel() throws {
        let rotation = try BundledContractSource().loadRotation()
        let assignment = ChoreAssignment(childID: "finley", choreID: "weekly-chore", weekday: .sunday, displayLabelOverride: nil)
        let choreCatalog = [Chore(id: "weekly-chore", type: .rotationResolved, defaultLabel: "Weekly Chore", sfSymbol: "star.circle", category: nil, note: nil)]

        let calendar = Calendar(identifier: .gregorian)
        let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))! // week 1, Sunday

        let resolved = ChoreResolver.chores(
            for: .finley,
            weekday: .sunday,
            assignments: [assignment],
            chores: choreCatalog,
            rotationEpoch: epoch,
            rotationContract: rotation,
            on: epoch
        )

        #expect(resolved.count == 1)
        #expect(resolved.first?.isRotationResolved == true)
        // Per rotation.json verification.week1: finley has collect-trash + feed-cats-pm.
        #expect(resolved.first?.label.contains("Collect Trash") == true)
        #expect(resolved.first?.label.contains("Feed Cats") == true)
    }

    @Test func showsSetupPromptWhenEpochUnset() throws {
        let rotation = try BundledContractSource().loadRotation()
        let assignment = ChoreAssignment(childID: "arthur", choreID: "weekly-chore", weekday: .sunday, displayLabelOverride: nil)
        let choreCatalog = [Chore(id: "weekly-chore", type: .rotationResolved, defaultLabel: "Weekly Chore", sfSymbol: "star.circle", category: nil, note: nil)]

        let resolved = ChoreResolver.chores(
            for: .arthur,
            weekday: .sunday,
            assignments: [assignment],
            chores: choreCatalog,
            rotationEpoch: nil,
            rotationContract: rotation
        )

        #expect(resolved.count == 1)
        #expect(resolved.first?.label == "Set up rotation start date")
    }

    @Test func resolvesFixedChoreWithPerChildLabelOverride() {
        let assignment = ChoreAssignment(childID: "finley", choreID: "empty-dishwasher", weekday: .monday, displayLabelOverride: "Empty Dishes")
        let choreCatalog = [Chore(id: "empty-dishwasher", type: .fixed, defaultLabel: "Empty Dishwasher", sfSymbol: "dishwasher", category: "kitchen", note: nil)]
        let rotation = RotationContract(
            schemaVersion: 1, cycle: ["finley", "maryn", "arthur"],
            rotationEpoch: .init(value: nil), chores: [],
            verification: .init(week1: [:], week2: [:], week3: [:])
        )

        let resolved = ChoreResolver.chores(
            for: .finley, weekday: .monday, assignments: [assignment], chores: choreCatalog,
            rotationEpoch: nil, rotationContract: rotation
        )

        #expect(resolved.first?.label == "Empty Dishes")
        #expect(resolved.first?.isRotationResolved == false)
    }
}
