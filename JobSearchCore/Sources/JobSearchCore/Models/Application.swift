import Foundation

public struct Application: Codable, Identifiable, Equatable, Sendable {
    public enum Status: String, Codable, CaseIterable, Sendable {
        case saved
        case applied
        case phoneScreen = "phone_screen"
        case interview
        case offer
        case rejected
        case withdrawn

        public var label: String {
            switch self {
            case .saved: return "Saved"
            case .applied: return "Applied"
            case .phoneScreen: return "Phone screen"
            case .interview: return "Interview"
            case .offer: return "Offer"
            case .rejected: return "Rejected"
            case .withdrawn: return "Withdrawn"
            }
        }
    }

    public enum Source: String, Codable, Sendable {
        case manual
        case ingested
    }

    public let id: Int
    public var company: Int
    public var companyName: String
    public var roleTitle: String
    public var jobUrl: String
    public var status: Status
    public var source: Source
    public var appliedDate: String?
    public var salaryNotes: String
    public var notes: String
    public let createdAt: Date
    public let updatedAt: Date
    public var events: [ApplicationEvent]

    public init(
        id: Int,
        company: Int,
        companyName: String,
        roleTitle: String,
        jobUrl: String = "",
        status: Status = .saved,
        source: Source = .manual,
        appliedDate: String? = nil,
        salaryNotes: String = "",
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        events: [ApplicationEvent] = []
    ) {
        self.id = id
        self.company = company
        self.companyName = companyName
        self.roleTitle = roleTitle
        self.jobUrl = jobUrl
        self.status = status
        self.source = source
        self.appliedDate = appliedDate
        self.salaryNotes = salaryNotes
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.events = events
    }
}

public struct ApplicationEvent: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public var application: Int
    public var note: String
    public let occurredAt: Date
}

/// Payload for creating an application — omits server-assigned fields.
public struct NewApplication: Encodable, Sendable {
    public var company: Int
    public var roleTitle: String
    public var jobUrl: String

    public init(company: Int, roleTitle: String, jobUrl: String = "") {
        self.company = company
        self.roleTitle = roleTitle
        self.jobUrl = jobUrl
    }
}

public struct NewCompany: Encodable, Sendable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}
