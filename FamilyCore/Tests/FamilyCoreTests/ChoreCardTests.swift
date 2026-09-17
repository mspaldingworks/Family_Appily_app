import Foundation
import Testing
@testable import FamilyCore

struct ChoreCardTests {
    @Test func weekdayMaskRoundTrips() {
        let card = ChoreCard(id: "finley|make-bed", childID: "finley", choreID: "make-bed",
                             label: "Make the bed", sfSymbol: "bed.double.fill", colorToken: nil, ticketValue: 3)
        #expect(card.weekdays.isEmpty)

        card.setWeekday(.monday, on: true)
        card.setWeekday(.friday, on: true)
        #expect(card.isOn(.monday))
        #expect(card.isOn(.friday))
        #expect(!card.isOn(.tuesday))
        #expect(card.weekdays == [.monday, .friday]) // allCases order: Sun…Sat

        card.setWeekday(.monday, on: false)
        #expect(!card.isOn(.monday))
        #expect(card.weekdays == [.friday])
    }

    @Test func idComposesChildAndChore() {
        #expect(ChoreCard.id(childID: "arthur", choreID: "trash") == "arthur|trash")
    }
}
