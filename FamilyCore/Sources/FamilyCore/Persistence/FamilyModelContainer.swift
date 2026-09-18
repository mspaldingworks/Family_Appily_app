import Foundation
import SwiftData

/// Local-first storage synced across the family's devices via their own
/// iCloud, per CLAUDE.md D4/§5: no server, no accounts, no third-party
/// infrastructure. `.private(...)` scopes this to the CloudKit **private**
/// database only — never shared or public — so completions, ticket entries,
/// and the private earn items never leave the family's own iCloud account.
public enum FamilyModelContainer {
    /// Whether the CloudKit-backed container was created (i.e. syncing is on).
    /// The seed guard only waits for an initial import when this is true.
    public private(set) static var isCloudActive = false

    private static var schema: Schema {
        Schema([
            Child.self,
            Chore.self,
            ChoreAssignment.self,
            ChoreCard.self,
            Completion.self,
            RotationChore.self,
            EarnItem.self,
            SpendTier.self,
            TicketLedgerEntry.self,
            SeedMarker.self,
            FamilySettings.self,
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
        let localConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        // 1) CloudKit — syncs the family's data across their devices. Now that the
        //    schema is CloudKit-compatible (no `.unique`, every attribute
        //    defaulted) this succeeds when signed into iCloud, instead of the old
        //    behaviour where it silently threw and fell back to local-only.
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
            isCloudActive = true
            return container
        }
        // 2) Local only — no iCloud account, Simulator, etc. Offline-first still works.
        if let container = try? ModelContainer(for: schema, configurations: [localConfiguration]) {
            return container
        }
        // 3) Both failed to open the on-disk store — almost certainly an
        //    incompatible schema left by an older build (e.g. the `.unique`
        //    constraints removed for CloudKit). Reset the store so the app always
        //    launches; it reseeds from the bundled contracts on next seed.
        resetLocalStore()
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
            isCloudActive = true
            return container
        }
        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("Failed to create FamilyCore ModelContainer, even after reset: \(error)")
        }
    }

    /// Deletes the default on-disk SwiftData store so a fresh container can be
    /// created when an older, incompatible schema can't be migrated. Only reached
    /// when both the CloudKit and local containers fail to open the existing store.
    private static func resetLocalStore() {
        let fileManager = FileManager.default
        guard let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return }
        for name in ["default.store", "default.store-wal", "default.store-shm"] {
            try? fileManager.removeItem(at: appSupport.appendingPathComponent(name))
        }
    }
}
