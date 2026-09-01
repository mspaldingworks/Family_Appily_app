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
    /// The employer's ATS link — where the application form actually lives.
    /// Falls back to the listing URL when the board didn't expose one.
    public var applyUrl: String
    public var status: Status
    /// Fit against her profile, 0-100, computed server-side at ingest.
    public var score: Int
    /// Why it scored that way, so the ranking can be judged rather than trusted.
    public var scoreReasons: [String]
    public let createdAt: Date

    /// Where the Apply button should send her.
    public var bestApplyLink: URL? {
        URL(string: applyUrl.isEmpty ? url : applyUrl)
    }
}

/// Tailored application materials generated for one posting.
public struct ApplicationMaterials: Codable, Equatable, Sendable {
    public var coverLetter: String
    public var resumeSummary: String
    public var resumeBullets: [String]
    public var gaps: [String]
    /// True when the model's output didn't match the expected section format —
    /// the letter field then holds the whole response rather than losing it.
    public var unparsed: Bool
    // No explicit CodingKeys: the API client decodes with
    // .convertFromSnakeCase, which already maps cover_letter -> coverLetter.
    // Declaring snake_case keys here would double-convert and fail to decode.
}
