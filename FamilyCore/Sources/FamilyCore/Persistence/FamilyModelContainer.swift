import Foundation
import SwiftData

/// Local-first storage synced across the family's devices via their own
/// iCloud, per CLAUDE.md D4/§5: no server, no accounts, no third-party
/// infrastructure. `.private(...)` scopes this to the CloudKit **private**
/// database only — never shared or public — so completions, ticket entries,
/// and the private earn items never leave the family's own iCloud account.
public enum FamilyModelContainer {
    private static var schema: Schema {
        Schema([
            Child.self,
            Chore.self,
            ChoreAssignment.self,
            Completion.self,
            RotationChore.self,
            EarnItem.self,
            SpendTier.self,
            TicketLedgerEntry.self,
        ])
    }

    /// Falls back to a local-only store (no CloudKit sync) if the CloudKit
    /// container isn't provisioned for this build — e.g. no signed-in iCloud
    /// account, a development build without the container registered yet, or
    /// Simulator without a real Apple Developer team. The app must still work
    /// per CLAUDE.md §3.6 (offline-first); losing sync is degraded, not fatal.
    public static func make() -> ModelContainer {
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.mspaldingworks.FamilyAppily")
        )
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
            return container
        }

        let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("Failed to create FamilyCore ModelContainer, even local-only: \(error)")
        }
    }
}
