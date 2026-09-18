import Foundation
import SwiftData

/// Seeds SwiftData from the bundled contracts on first launch. Idempotent —
/// safe to call every launch; it only inserts what's missing so an adult's
/// local edits (once editing exists, in a later phase) are never clobbered.
public enum FamilySeeder {
    /// Bump when the bundled contracts change enough to warrant a re-seed on
    /// devices that already carry an older seed marker.
    private static let currentSeedVersion = 1

    /// Seeds the family data once per family, guarded by a synced `SeedMarker`
    /// so a second device doesn't duplicate everyone (SwiftData + CloudKit can't
    /// enforce uniqueness). A fresh local store on a CloudKit device briefly
    /// waits for the initial import to deliver an existing marker before seeding.
    public static func seedIfNeeded(
        context: ModelContext,
        source: ContractSource = BundledContractSource(),
        cloudActive: Bool = FamilyModelContainer.isCloudActive
    ) async throws {
        let hasLocalData = try !context.fetch(FetchDescriptor<Child>()).isEmpty
        let markerAlreadyPresent = try hasSeedMarker(context: context)

        // A fresh local store on a CloudKit device may just be awaiting the
        // initial import. Give it a brief window to deliver an existing marker
        // (and the family-settings row) before we create anything, so a
        // newly-added device doesn't duplicate the family. Skipped when this
        // device already has data or CloudKit isn't active.
        if cloudActive && !hasLocalData && !markerAlreadyPresent {
            for _ in 0..<5 {
                try await Task.sleep(for: .seconds(1))
                if try hasSeedMarker(context: context) { break }
            }
        }

        // Family-wide settings: move them off per-device UserDefaults into a
        // synced row, once. Runs BEFORE the marker early-return so an
        // already-seeded device (which has a marker but no settings row yet)
        // still migrates its saved rotation start / ticket value / name / icon
        // instead of losing them.
        try migrateFamilySettingsIfNeeded(context: context)

        // Already seeded here, or a marker has synced in from another device.
        if try hasSeedMarker(context: context) { return }

        try seedChildrenAndChores(context: context, source: source)
        try seedRotationChores(context: context, source: source)
        try seedTicketsCatalog(context: context, source: source)
        try seedChoreCardsIfNeeded(context: context)
        try setSeedMarker(context: context)
    }

    /// Creates the single `FamilySettings` row if absent, carrying over any values
    /// the family had already set in the old per-device `@AppStorage` keys so the
    /// upgrade preserves their rotation start, ticket value, name, and icon.
    private static func migrateFamilySettingsIfNeeded(context: ModelContext) throws {
        guard try context.fetch(FetchDescriptor<FamilySettings>()).isEmpty else { return }
        let defaults = UserDefaults.standard
        context.insert(FamilySettings(
            rotationEpochISO8601: defaults.string(forKey: "rotationEpochISO8601") ?? "",
            weeklyChoreTicketValue: (defaults.object(forKey: "weeklyChoreTicketValue") as? Int) ?? 5,
            rotationName: defaults.string(forKey: "rotationName") ?? "Rotation",
            rotationIcon: defaults.string(forKey: "rotationIcon") ?? "arrow.triangle.2.circlepath"
        ))
        try context.save()
    }

    private static func hasSeedMarker(context: ModelContext) throws -> Bool {
        try context.fetch(FetchDescriptor<SeedMarker>()).contains { $0.version >= currentSeedVersion }
    }

    private static func setSeedMarker(context: ModelContext) throws {
        guard try !hasSeedMarker(context: context) else { return }
        context.insert(SeedMarker(id: "family-seed", version: currentSeedVersion, seededAt: .now))
        try context.save()
    }

    /// Backfills a per-kid `ChoreCard` for each (child, fixed-chore) pair that
    /// has assignments but no card yet — non-destructive and idempotent (creates
    /// cards, deletes nothing), so existing installs gain cards on first launch.
    private static func seedChoreCardsIfNeeded(context: ModelContext) throws {
        let assignments = try context.fetch(FetchDescriptor<ChoreAssignment>())
        let chores = try context.fetch(FetchDescriptor<Chore>())
        let choreByID = Dictionary(chores.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        struct Aggregate { var childID: String; var chore: Chore; var mask: Int; var label: String }
        var byCard: [String: Aggregate] = [:]
        for assignment in assignments {
            guard let chore = choreByID[assignment.choreID], chore.choreType != .rotationResolved else { continue }
            let key = ChoreCard.id(childID: assignment.childID, choreID: assignment.choreID)
            let bit = 1 << assignment.weekday
            if var aggregate = byCard[key] {
                aggregate.mask |= bit
                byCard[key] = aggregate
            } else {
                byCard[key] = Aggregate(
                    childID: assignment.childID,
                    chore: chore,
                    mask: bit,
                    label: assignment.displayLabelOverride ?? chore.defaultLabel
                )
            }
        }

        for (key, aggregate) in byCard {
            let descriptor = FetchDescriptor<ChoreCard>(predicate: #Predicate { $0.id == key })
            guard try context.fetch(descriptor).isEmpty else { continue }
            context.insert(ChoreCard(
                id: key,
                childID: aggregate.childID,
                choreID: aggregate.chore.id,
                label: aggregate.label,
                sfSymbol: aggregate.chore.sfSymbol,
                colorToken: aggregate.chore.colorToken,
                ticketValue: aggregate.chore.ticketValue,
                scheduleIsRecurring: true,
                weekdaysMask: aggregate.mask,
                dueDate: nil
            ))
        }
        try context.save()
    }

    private static func seedChildrenAndChores(context: ModelContext, source: ContractSource) throws {
        let family = try source.loadFamily()

        for childContract in family.children {
            let descriptor = FetchDescriptor<Child>(predicate: #Predicate { $0.id == childContract.id })
            if try context.fetch(descriptor).isEmpty {
                context.insert(Child(
                    id: childContract.id,
                    name: childContract.name,
                    motif: childContract.motif,
                    cardFrame: childContract.cardFrame,
                    primaryAvatar: childContract.avatars.primary,
                    alternateAvatar: childContract.avatars.alternate,
                    topCornerMotif: childContract.decorations.topCorners,
                    bottomCornerMotif: childContract.decorations.bottomCorners,
                    titleColorToken: childContract.titleColorToken
                ))
            }
        }

        for choreContract in family.chores {
            let descriptor = FetchDescriptor<Chore>(predicate: #Predicate { $0.id == choreContract.id })
            if try context.fetch(descriptor).isEmpty {
                context.insert(Chore(
                    id: choreContract.id,
                    type: ChoreType(rawValue: choreContract.type) ?? .fixed,
                    defaultLabel: choreContract.defaultLabel,
                    sfSymbol: choreContract.sfSymbol,
                    category: choreContract.category,
                    note: choreContract.note
                ))
            }
        }

        for (childID, weekSchedule) in family.schedule {
            for (weekdayKey, choreIDs) in weekSchedule {
                guard let weekday = Weekday(jsonKey: weekdayKey) else { continue }
                for choreID in choreIDs {
                    let weekdayRaw = weekday.rawValue
                    let descriptor = FetchDescriptor<ChoreAssignment>(predicate: #Predicate {
                        $0.childID == childID && $0.choreID == choreID && $0.weekday == weekdayRaw
                    })
                    if try context.fetch(descriptor).isEmpty {
                        let choreContract = family.chores.first { $0.id == choreID }
                        let labelOverride = choreContract?.childLabels?[childID]
                        context.insert(ChoreAssignment(
                            childID: childID,
                            choreID: choreID,
                            weekday: weekday,
                            displayLabelOverride: labelOverride
                        ))
                    }
                }
            }
        }

        try context.save()
    }

    private static func seedRotationChores(context: ModelContext, source: ContractSource) throws {
        let rotation = try source.loadRotation()
        for choreContract in rotation.chores {
            let descriptor = FetchDescriptor<RotationChore>(predicate: #Predicate { $0.id == choreContract.id })
            if try context.fetch(descriptor).isEmpty {
                context.insert(RotationChore(
                    id: choreContract.id,
                    label: choreContract.label,
                    offset: choreContract.offset,
                    sfSymbol: choreContract.sfSymbol
                ))
            }
        }
        try context.save()
    }

    private static func seedTicketsCatalog(context: ModelContext, source: ContractSource) throws {
        let tickets = try source.loadTickets()

        for tier in tickets.spendTiers.tiers {
            let descriptor = FetchDescriptor<SpendTier>(predicate: #Predicate { $0.id == tier.id })
            if try context.fetch(descriptor).isEmpty {
                context.insert(SpendTier(id: tier.id, cost: tier.cost, label: tier.label, sfSymbol: tier.sfSymbol))
            }
        }

        for item in tickets.earnCatalog.shared {
            try insertEarnItemIfNeeded(item, childID: nil, context: context)
        }
        for (childID, items) in tickets.earnCatalog.perChild {
            for item in items {
                try insertEarnItemIfNeeded(item, childID: childID, context: context)
            }
        }

        try context.save()
    }

    private static func insertEarnItemIfNeeded(
        _ item: TicketsContract.EarnCatalog.EarnItemContract,
        childID: String?,
        context: ModelContext
    ) throws {
        // Composite id so the same catalog id (e.g. "practice-dance") can exist
        // both shared and per-child without colliding.
        let compositeID = childID.map { "\($0):\(item.id)" } ?? item.id
        let descriptor = FetchDescriptor<EarnItem>(predicate: #Predicate { $0.id == compositeID })
        if try context.fetch(descriptor).isEmpty {
            context.insert(EarnItem(
                id: compositeID,
                label: item.label,
                sfSymbol: item.sfSymbol,
                isPrivate: item.isPrivate,
                childID: childID
            ))
        }
    }
}
