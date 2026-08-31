import Foundation
import Testing
@testable import JobSearchCore

struct DecodingTests {
    /// A real response captured from the Django backend (see Famiy_Appily_api's
    /// tracker/serializers.py) — guards against the snake_case/date-format
    /// assumptions baked into JobSearchAPIClient's decoder configuration.
    @Test func decodesApplicationFromDjangoPayload() throws {
        let json = """
        {
            "id": 1, "company": 1, "company_name": "Acme Corp", "role_title": "Staff Engineer",
            "job_url": "https://example.com/job/1", "status": "saved", "source": "ingested",
            "applied_date": null, "salary_notes": "", "resume": null, "cover_letter": null,
            "notes": "Promoted from ingested posting.",
            "created_at": "2026-08-31T20:04:47.073558Z", "updated_at": "2026-08-31T20:04:47.073558Z",
            "events": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "bad date")
            }
            return date
        }

        let application = try decoder.decode(Application.self, from: json)
        #expect(application.companyName == "Acme Corp")
        #expect(application.roleTitle == "Staff Engineer")
        #expect(application.status == .saved)
        #expect(application.source == .ingested)
        #expect(application.appliedDate == nil)
    }

    @Test func newApplicationEncodesToSnakeCase() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let payload = NewApplication(company: 1, roleTitle: "Staff Engineer", jobUrl: "https://example.com")
        let data = try encoder.encode(payload)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["role_title"] as? String == "Staff Engineer")
        #expect(object["job_url"] as? String == "https://example.com")
    }
}
