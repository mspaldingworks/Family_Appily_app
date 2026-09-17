import Foundation
import Testing
@testable import FamilyCore

struct WeeklyChoreBoardTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func occ(_ choreID: String, _ date: Date) -> ChoreOccurrence {
        ChoreOccurrence(
            id: "finley|\(choreID)|\(date.timeIntervalSince1970)",
            childID: .finley, choreID: choreID, label: choreID.capitalized,
            sfSymbol: "star", date: date, isRotationResolved: false, ticketValue: 2
        )
    }

    @Test func splitsTodayHeldOverAndUpcoming() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 7))!  // Wednesday
        let monday = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 1, day: 9))!

        let board = WeeklyChoreBoard.build(
            occurrences: [occ("bed", monday), occ("dishes", today), occ("trash", friday)],
            doneKeys: [],
            today: today,
            calendar: calendar
        )

        #expect(board.today.count == 2) // Monday's "bed" held over + today's "dishes"
        #expect(board.today.contains { $0.occurrence.choreID == "bed" && $0.isHeldOver })
        #expect(board.today.contains { $0.occurrence.choreID == "dishes" && !$0.isHeldOver })
        #expect(board.upcoming.count == 1)
        #expect(board.upcoming.first?.chores.first?.occurrence.choreID == "trash")
    }

    @Test func doneEarlierChoreIsNotHeldOver() {
        let today = calendar.date(from: DateComponents(year: 2026, month: 1, day: 7))!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 1, day: 5))!
        let doneKey = WeeklyChoreBoard.key(childID: "finley", choreID: "bed", date: monday, calendar: calendar)

        let board = WeeklyChoreBoard.build(
            occurrences: [occ("bed", monday), occ("dishes", today)],
            doneKeys: [doneKey],
            today: today,
            calendar: calendar
        )

        // "bed" was done Monday → not held over, and not shown in today.
        #expect(board.today.count == 1)
        #expect(board.today.first?.occurrence.choreID == "dishes")
    }
}
