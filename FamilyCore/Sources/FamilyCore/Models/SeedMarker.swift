import Foundation
import SwiftData

/// A single synced record marking that the family data has been seeded. It is
/// the cross-device seed guard: once any device seeds and this marker syncs via
/// CloudKit, other devices see it and skip seeding, so the family isn't
/// duplicated (SwiftData + CloudKit can't enforce uniqueness, so we guard in
/// app logic instead). `version` lets a future contract change force a re-seed.
@Model
public final class SeedMarker {
    public var id: String = ""
    public var version: Int = 0
    public var seededAt: Date = Date.distantPast

    public init(id: String, version: Int, seededAt: Date) {
        self.id = id
        self.version = version
        self.seededAt = seededAt
    }
}
