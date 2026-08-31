import Foundation

/// Mirrors rotation.json exactly. See family-hub-assets/data/rotation.json.
public struct RotationContract: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let cycle: [String]
    public let rotationEpoch: RotationEpoch
    public let chores: [RotationChoreContract]
    public let verification: Verification

    public struct RotationEpoch: Codable, Equatable, Sendable {
        /// ISO8601 date string once set by the one-time adult setup step, else nil.
        public let value: String?
    }

    public struct RotationChoreContract: Codable, Equatable, Sendable {
        public let id: String
        public let label: String
        public let offset: Int
        public let sfSymbol: String
    }

    /// All 42 printed grid cells (3 weeks × 6 chores × ~2.33 repeats on the physical
    /// chart, collapsed to weeks 1–3), used to unit-test the rotation formula.
    public struct Verification: Codable, Equatable, Sendable {
        public let week1: [String: String]
        public let week2: [String: String]
        public let week3: [String: String]
    }
}
