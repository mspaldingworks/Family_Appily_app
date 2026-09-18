import Foundation
import SwiftData

/// Family-wide settings that must be identical on every device — the rotation
/// start date (the §11 blocker a second device needs), the weekly-chore ticket
/// value, and the rotation's display name + icon. Kept in SwiftData (not
/// per-device `@AppStorage`) so they sync through the same CloudKit private
/// store as the rest of the family's data (D4). One row per family; genuinely
/// device-local prefs (haptics, sound, calendar visibility) stay `@AppStorage`.
///
/// No `.unique` and all-defaulted, per the CloudKit rules the rest of the schema
/// follows; the singleton is upheld in code (`ensure`, and a migrating create in
/// `FamilySeeder`).
@Model
public final class FamilySettings {
    public var id: String = "family-settings"
    public var rotationEpochISO8601: String = ""
    public var weeklyChoreTicketValue: Int = 5
    public var rotationName: String = "Rotation"
    public var rotationIcon: String = "arrow.triangle.2.circlepath"

    public init(
        id: String = "family-settings",
        rotationEpochISO8601: String = "",
        weeklyChoreTicketValue: Int = 5,
        rotationName: String = "Rotation",
        rotationIcon: String = "arrow.triangle.2.circlepath"
    ) {
        self.id = id
        self.rotationEpochISO8601 = rotationEpochISO8601
        self.weeklyChoreTicketValue = weeklyChoreTicketValue
        self.rotationName = rotationName
        self.rotationIcon = rotationIcon
    }

    /// The single family-settings row, creating a default one if none exists yet.
    /// Fetches from the context directly (not a `@Query`) so repeated calls in the
    /// same tick can't race into duplicate rows.
    @discardableResult
    public static func ensure(in context: ModelContext) -> FamilySettings {
        if let existing = try? context.fetch(FetchDescriptor<FamilySettings>()).first {
            return existing
        }
        let created = FamilySettings()
        context.insert(created)
        try? context.save()
        return created
    }
}
