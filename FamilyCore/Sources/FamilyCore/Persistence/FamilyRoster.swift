import Foundation
import SwiftData

/// Adding and removing children. Kept out of the views so the cascade rules live
/// in one place. A parent-added child gets a fresh slug id (never a `ChildID`
/// case), so `Child.childID` stays nil — which is how the rest of the app knows
/// to give them a colour + monogram instead of a mascot, and no rotation slot.
public enum FamilyRoster {
    /// Inserts a new child with a colour that isn't already taken (falling back
    /// to the palette start once every colour is in use). Returns it so the
    /// caller can navigate straight into editing.
    @discardableResult
    public static func addChild(name: String = "New child",
                                context: ModelContext,
                                existing: [Child]) -> Child {
        let used = Set(existing.map(\.colorHex))
        let color = KidPalette.colors.first { !used.contains($0) }
            ?? KidPalette.colors.first ?? "#3A6EA5"
        let child = Child(
            id: "kid-\(UUID().uuidString.prefix(8).lowercased())",
            name: name, motif: "", cardFrame: "", primaryAvatar: "",
            alternateAvatar: nil, topCornerMotif: "", bottomCornerMotif: "",
            titleColorToken: "", age: 0, colorHex: color
        )
        context.insert(child)
        try? context.save()
        return child
    }

    /// Deletes a child and every row keyed to them — assignments, cards,
    /// completions, and ticket-ledger entries — since SwiftData won't cascade
    /// without a declared relationship. Irreversible; the UI gates + confirms it.
    public static func deleteChild(_ child: Child, context: ModelContext) {
        let cid = child.id
        for a in fetch(ChoreAssignment.self, childID: cid, context) { context.delete(a) }
        for c in fetch(ChoreCard.self, childID: cid, context) { context.delete(c) }
        for c in fetch(Completion.self, childID: cid, context) { context.delete(c) }
        for t in fetch(TicketLedgerEntry.self, childID: cid, context) { context.delete(t) }
        context.delete(child)
        try? context.save()
    }

    private static func fetch<T: PersistentModel>(_ type: T.Type, childID cid: String, _ context: ModelContext) -> [T] {
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        return all.filter { ($0 as? ChildKeyed)?.childID == cid }
    }
}

/// Lets `FamilyRoster` delete rows for a child generically. All the per-child
/// models already store the child's id in a `childID` string.
public protocol ChildKeyed { var childID: String { get } }
extension ChoreAssignment: ChildKeyed {}
extension ChoreCard: ChildKeyed {}
extension Completion: ChildKeyed {}
extension TicketLedgerEntry: ChildKeyed {}
