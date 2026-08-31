import Foundation

/// Mirrors tickets.json exactly. See family-hub-assets/data/tickets.json.
public struct TicketsContract: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let rewardChart: RewardChart
    public let spendTiers: SpendTiers
    public let earnCatalog: EarnCatalog

    public struct RewardChart: Codable, Equatable, Sendable {
        public let rows: Int
        public let slotsPerRow: Int
        public let totalSlots: Int
        public let milestoneSlotIndex: Int
    }

    public struct SpendTiers: Codable, Equatable, Sendable {
        public let scope: String
        public let tiers: [Tier]

        public struct Tier: Codable, Equatable, Sendable {
            public let id: String
            public let cost: Int
            public let label: String
            public let sfSymbol: String
        }
    }

    public struct EarnCatalog: Codable, Equatable, Sendable {
        public let shared: [EarnItemContract]
        public let perChild: [String: [EarnItemContract]]

        public struct EarnItemContract: Codable, Equatable, Sendable {
            public let id: String
            public let label: String
            public let sfSymbol: String
            public let isPrivate: Bool

            enum CodingKeys: String, CodingKey {
                case id, label, sfSymbol
                case isPrivate = "private"
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                id = try container.decode(String.self, forKey: .id)
                label = try container.decode(String.self, forKey: .label)
                sfSymbol = try container.decode(String.self, forKey: .sfSymbol)
                isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
            }
        }
    }
}
