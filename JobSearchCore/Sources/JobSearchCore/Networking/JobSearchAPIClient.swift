import Foundation

public enum JobSearchAPIError: Error, Equatable, Sendable {
    case notAuthenticated
    case notFound
    case badStatus(Int)
    case decodingFailed
    case transport
}

/// Talks to the Job Search API (see Famiy_Appily_api's `api/` Django service).
/// Uses DRF TokenAuthentication — a single long-lived token stored in the
/// Keychain, not a login flow, consistent with the rest of Family Appily
/// having no accounts. This is the only part of the app that makes network
/// calls; everything else (chores, rotation, tickets) is local/CloudKit.
public actor JobSearchAPIClient {
    public struct Configuration: Sendable {
        public var baseURL: URL
        public var token: String

        public init(baseURL: URL, token: String) {
            self.baseURL = baseURL
            self.token = token
        }
    }

    private let configuration: Configuration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(configuration: Configuration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = JobSearchAPIClient.fractionalFormatter.date(from: string) { return date }
            if let date = JobSearchAPIClient.formatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
        }
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: Applications

    public func fetchApplications() async throws -> [Application] {
        try await request("api/tracker/applications/")
    }

    public func createApplication(_ new: NewApplication) async throws -> Application {
        try await request("api/tracker/applications/", method: "POST", body: new)
    }

    // MARK: Companies

    public func fetchCompanies() async throws -> [Company] {
        try await request("api/tracker/companies/")
    }

    public func createCompany(_ new: NewCompany) async throws -> Company {
        try await request("api/tracker/companies/", method: "POST", body: new)
    }

    // MARK: Ingestion (RSS job feed)

    public func fetchIngestedPostings() async throws -> [IngestedPosting] {
        try await request("api/ingestion/postings/")
    }

    public func promotePosting(id: Int) async throws -> Application {
        try await request("api/ingestion/postings/\(id)/promote/", method: "POST")
    }

    // MARK: Identity

    public func fetchProfiles() async throws -> [ProfessionalProfile] {
        try await request("api/identity/profile/")
    }

    public func fetchSkills() async throws -> [Skill] {
        try await request("api/identity/skills/")
    }

    public func fetchLinks() async throws -> [ProfileLink] {
        try await request("api/identity/links/")
    }

    public func fetchResumes() async throws -> [ResumeVersion] {
        try await request("api/identity/resumes/")
    }

    // MARK: Request plumbing

    private func request<T: Decodable>(_ path: String, method: String = "GET", body: (some Encodable)? = Optional<Int>.none) async throws -> T {
        var urlRequest = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        urlRequest.httpMethod = method
        urlRequest.setValue("Token \(configuration.token)", forHTTPHeaderField: "Authorization")

        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw JobSearchAPIError.transport
        }

        guard let http = response as? HTTPURLResponse else { throw JobSearchAPIError.transport }
        switch http.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw JobSearchAPIError.notAuthenticated
        case 404:
            throw JobSearchAPIError.notFound
        default:
            throw JobSearchAPIError.badStatus(http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw JobSearchAPIError.decodingFailed
        }
    }
}
