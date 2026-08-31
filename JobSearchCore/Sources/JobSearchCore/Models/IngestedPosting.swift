import Foundation

public struct IngestedPosting: Codable, Identifiable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case new
        case triaged
        case dismissed
    }

    public let id: Int
    public var source: String
    public var title: String
    public var companyName: String
    public var url: String
    public var status: Status
    public let createdAt: Date
}
