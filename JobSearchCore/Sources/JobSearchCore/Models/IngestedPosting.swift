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
    /// Which ATS the application goes through, and whether it demands an
    /// account before showing the form.
    public var platform: String
    public var requiresAccount: Bool
    public var signInUrl: String
    public let createdAt: Date

    /// Where the Apply button should send her.
    public var bestApplyLink: URL? {
        URL(string: applyUrl.isEmpty ? url : applyUrl)
    }
}

/// Tailored application materials generated for one posting.
public extension IngestedPosting {
    /// Where to create an account, when the portal insists on one before it
    /// will show the form.
    var signInLink: URL? { URL(string: signInUrl) }
}

public struct ApplicationMaterials: Codable, Equatable, Sendable {
    public var coverLetter: String
    public var resumeSummary: String
    public var resumeBullets: [String]
    public var gaps: [String]
    /// True when the model's output didn't match the expected section format —
    /// the letter field then holds the whole response rather than losing it.
    public var unparsed: Bool

    // Raw values are camelCase on purpose: the client decodes with
    // .convertFromSnakeCase, so "cover_letter" has already become
    // "coverLetter" by the time these are matched.
    enum CodingKeys: String, CodingKey {
        case coverLetter, resumeSummary, resumeBullets, gaps, unparsed
    }

    /// Decodes leniently. A record with no materials used to arrive as `{}` —
    /// an object claiming to be materials while missing every field — and the
    /// strict synthesised initialiser threw, which failed the decode of the
    /// whole list and emptied the Drafts screen. One malformed row should cost
    /// its own contents, not everything alongside it.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coverLetter = try container.decodeIfPresent(String.self, forKey: .coverLetter) ?? ""
        resumeSummary = try container.decodeIfPresent(String.self, forKey: .resumeSummary) ?? ""
        resumeBullets = try container.decodeIfPresent([String].self, forKey: .resumeBullets) ?? []
        gaps = try container.decodeIfPresent([String].self, forKey: .gaps) ?? []
        unparsed = try container.decodeIfPresent(Bool.self, forKey: .unparsed) ?? false
    }

    public init(coverLetter: String = "", resumeSummary: String = "",
                resumeBullets: [String] = [], gaps: [String] = [],
                unparsed: Bool = false) {
        self.coverLetter = coverLetter
        self.resumeSummary = resumeSummary
        self.resumeBullets = resumeBullets
        self.gaps = gaps
        self.unparsed = unparsed
    }

    /// True when there's nothing worth showing, however it arrived.
    public var isEmpty: Bool {
        coverLetter.isEmpty && resumeSummary.isEmpty && resumeBullets.isEmpty && gaps.isEmpty
    }
}


/// Payload for starting a bulk prepare run.
public struct PrepareRequest: Codable, Sendable {
    public var postingIds: [Int]
}

/// Progress of a bulk prepare run. `results` fills in as each posting finishes,
/// so the UI can show which ones are done rather than one opaque spinner.
public struct PrepareJob: Codable, Equatable, Sendable, Identifiable {
    public struct Result: Codable, Equatable, Sendable {
        public var postingId: Int
        public var ok: Bool
        public var detail: String
        public var applicationId: Int?
    }

    public var id: String
    public var state: String
    public var total: Int
    public var done: Int
    public var results: [Result]

    public var isFinished: Bool { state == "finished" }
    public var failures: [Result] { results.filter { !$0.ok } }
}
