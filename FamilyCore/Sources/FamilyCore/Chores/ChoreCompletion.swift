import Foundation
import SwiftData

/// The single place a chore's completion is toggled, keeping the append-only
/// ticket ledger in step (insert a `Completion` + an earn entry, or remove both).
/// Shared by the weekly chart and the family board so the two can never disagree
/// or double-award. Completion is keyed to a specific `date` — the chore's own
/// day — so a chore held over to a later day still records against the day it
/// was due, and completing the same chore on either screen is idempotent.
public enum ChoreCompletion {
    /// Toggles completion for (child, chore) on `date`. Returns true if the chore
    /// is now complete (so the caller can play its haptic/sound feedback).
    @discardableResult
    public static func toggle(
        childID: String,
        choreID: String,
        date: Date,
        ticketValue: Int,
        completions: [Completion],
        ticketEntries: [TicketLedgerEntry],
        context: ModelContext,
        calendar: Calendar = .current
    ) -> Bool {
        if let existing = completions.first(where: {
            $0.childID == childID && $0.choreID == choreID && calendar.isDate($0.date, inSameDayAs: date)
        }) {
            context.delete(existing)
            // Take back the ticket this completion earned, matched to the same
            // child/chore/day so un-checking is fully reversible (§3.5).
            if let earned = ticketEntries.first(where: {
                $0.childID == childID && $0.referenceID == choreID
                    && $0.kind == TicketLedgerKind.earn.rawValue
                    && calendar.isDate($0.occurredAt, inSameDayAs: date)
            }) {
                context.delete(earned)
            }
            try? context.save()
            return false
        } else {
            context.insert(Completion(childID: childID, choreID: choreID, date: date))
            context.insert(TicketLedgerEntry(childID: childID, amount: max(1, ticketValue), kind: .earn, referenceID: choreID, occurredAt: date))
            try? context.save()
            return true
        }
    }
}
