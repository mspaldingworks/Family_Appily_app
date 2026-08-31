import Foundation
import Testing
@testable import FamilyCore

struct RotationEngineTests {
    private let engine = RotationEngine()

    /// Every one of the 42 cells printed on the physical FAMILY CHORE CHART
    /// (3 weeks × 6 chores, weeks 4–7 being a repeat of 1–3, hence 42 not 18)
    /// must match exactly. This is the hard gate PHASE0_PROMPT.md calls out —
    /// nothing else in the rotation feature may proceed until this passes.
    @Test func matchesAllVerificationCells() throws {
        let rotation = try BundledContractSource().loadRotation()
        let weeks: [(index: Int, expected: [String: String])] = [
            (0, rotation.verification.week1),
            (1, rotation.verification.week2),
            (2, rotation.verification.week3),
        ]

        for (weekIndex, expected) in weeks {
            for chore in rotation.chores {
                let expectedChildRaw = try #require(expected[chore.id])
                let expectedChild = try #require(ChildID(rawValue: expectedChildRaw))
                let actual = engine.assignee(offset: chore.offset, weekIndex: weekIndex)
                #expect(
                    actual == expectedChild,
                    "week \(weekIndex + 1), chore \(chore.id): expected \(expectedChild), got \(actual)"
                )
            }
        }
    }

    /// The rotation must never expire: week 7 (index 6) repeats week 1 (index 0)
    /// exactly, per rotation.json's keyFinding that it's a 3-week cycle shown
    /// 2⅓ times on the physical 7-column chart.
    @Test func cycleRepeatsEveryThreeWeeks() throws {
        let rotation = try BundledContractSource().loadRotation()
        for chore in rotation.chores {
            let week1 = engine.assignee(offset: chore.offset, weekIndex: 0)
            let week7 = engine.assignee(offset: chore.offset, weekIndex: 6)
            #expect(week1 == week7)
        }
    }

    @Test func weekIndexComputesFromEpoch() {
        let calendar = Calendar(identifier: .gregorian)
        let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 4))! // a Sunday
        let sameWeek = calendar.date(byAdding: .day, value: 3, to: epoch)!
        let nextWeek = calendar.date(byAdding: .day, value: 8, to: epoch)!

        #expect(engine.weekIndex(epoch: epoch, on: epoch) == 0)
        #expect(engine.weekIndex(epoch: epoch, on: sameWeek) == 0)
        #expect(engine.weekIndex(epoch: epoch, on: nextWeek) == 1)
    }
}
