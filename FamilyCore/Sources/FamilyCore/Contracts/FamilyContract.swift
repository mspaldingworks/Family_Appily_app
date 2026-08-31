import Foundation

/// Mirrors family.json exactly. See family-hub-assets/data/family.json.
public struct FamilyContract: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let weekStartsOn: String
    public let children: [ChildContract]
    public let chores: [ChoreContract]
    public let schedule: [String: [String: [String]]]

    public struct ChildContract: Codable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let motif: String
        public let avatars: Avatars
        public let cardFrame: String
        public let decorations: Decorations
        public let titleColorToken: String

        public struct Avatars: Codable, Equatable, Sendable {
            public let primary: String
            public let alternate: String?
        }

        public struct Decorations: Codable, Equatable, Sendable {
            public let topCorners: String
            public let bottomCorners: String
        }
    }

    public struct ChoreContract: Codable, Equatable, Sendable {
        public let id: String
        public let type: String
        public let defaultLabel: String
        public let childLabels: [String: String]?
        public let sfSymbol: String
        public let category: String?
        public let note: String?
    }
}
