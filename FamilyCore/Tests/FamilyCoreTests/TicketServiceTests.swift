import Testing
@testable import FamilyCore

struct TicketServiceTests {
    private let chart = try! BundledContractSource().loadTickets().rewardChart

    @Test func balanceSumsSignedEntriesForOneChildOnly() {
        let entries = [
            TicketLedgerEntry(childID: "finley", amount: 1, kind: .earn, referenceID: "a"),
            TicketLedgerEntry(childID: "finley", amount: 1, kind: .earn, referenceID: "b"),
            TicketLedgerEntry(childID: "finley", amount: -5, kind: .spend, referenceID: "t"),
            TicketLedgerEntry(childID: "maryn", amount: 3, kind: .earn, referenceID: "c"),
        ]
        #expect(TicketService.balance(for: "finley", in: entries) == -3)
        #expect(TicketService.balance(for: "maryn", in: entries) == 3)
        #expect(TicketService.balance(for: "arthur", in: entries) == 0)
    }

    @Test func chartHoldsTwentyFiveTicketsPlusFiveStars() {
        #expect(TicketService.ticketColumns(chart) == 5)
        #expect(TicketService.ticketCapacity(chart) == 25)
    }

    @Test func starsAndVaultTrackBalance() {
        #expect(TicketService.starsEarned(0, chart: chart) == 0)
        #expect(TicketService.starsEarned(5, chart: chart) == 1)
        #expect(TicketService.starsEarned(13, chart: chart) == 2)
        #expect(TicketService.starsEarned(25, chart: chart) == 5)
        #expect(TicketService.starsEarned(40, chart: chart) == 5, "stars cap at the number of rows")

        #expect(TicketService.vaultBalance(24, chart: chart) == 0)
        #expect(TicketService.vaultBalance(31, chart: chart) == 6)
    }

    @Test func cellsFillTicketsThenLightEachRowStar() {
        let cells = TicketService.cells(balance: 6, chart: chart)
        #expect(cells.count == chart.totalSlots)
        // Row 0: five ticket slots filled, its star earned (a full row = 5).
        #expect(cells[0] == .ticket(filled: true))
        #expect(cells[4] == .ticket(filled: true))
        #expect(cells[5] == .star(earned: true))
        // Row 1: the 6th ticket lands in the first slot; the row star waits for 10.
        #expect(cells[6] == .ticket(filled: true))
        #expect(cells[7] == .ticket(filled: false))
        #expect(cells[11] == .star(earned: false))
    }
}
