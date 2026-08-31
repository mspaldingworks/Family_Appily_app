import Foundation
import SwiftData

/// Seeds SwiftData from the bundled contracts on first launch. Idempotent —
/// safe to call every launch; it only inserts what's missing so an adult's
/// local edits (once editing exists, in a later phase) are never clobbered.
public enum FamilySeeder {
    public static func seedIfNeeded(context: ModelContext, source: ContractSource = BundledContractSource()) throws {
        try seedChildrenAndChores(context: context, source: source)
        try seedRotationChores(context: context, source: source)
        try seedTicketsCatalog(context: context, source: source)
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
