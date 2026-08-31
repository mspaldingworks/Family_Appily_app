import Testing
@testable import FamilyCore

struct ContractDecodingTests {
    private let source = BundledContractSource()

    @Test func decodesFamilyContract() throws {
        let family = try source.loadFamily()
        #expect(family.children.count == 3)
        #expect(family.children.map(\.id).sorted() == ["arthur", "finley", "maryn"])
        #expect(family.schedule["finley"]?["sunday"]?.contains("weekly-chore") == true)
    }

    @Test func decodesTicketsContractAndFlagsPrivateItems() throws {
        let tickets = try source.loadTickets()
        #expect(tickets.rewardChart.totalSlots == 30)
        #expect(tickets.spendTiers.tiers.count == 4)

        let arthurItems = try #require(tickets.earnCatalog.perChild["arthur"])
        let privateItems = arthurItems.filter(\.isPrivate)
        #expect(privateItems.count == 2, "Arthur's two therapy-adjacent items must decode as private")

        let sharedPrivateItems = tickets.earnCatalog.shared.filter(\.isPrivate)
        #expect(sharedPrivateItems.isEmpty, "no shared earn item should be private")
    }
}
