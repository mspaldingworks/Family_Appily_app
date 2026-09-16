import Foundation

/// All ticket math in one place. A child's balance is always the signed sum of
/// their ledger entries — never a stored counter (see `TicketLedgerEntry`), so
/// it can't drift from its own history — and the reward-chart geometry is
/// derived from that same balance, so the chart on the wall and the chart in
/// the app can never disagree.
///
/// Reward-chart reading (resolves the open question in tickets.json): each row
/// is **five earnable ticket slots plus one milestone star** in the last
/// column. That is the reading the printed chart implies — rows of six against
/// spend tiers of 5/10/15/20, where a full row (5 tickets) buys the cheapest
/// reward. The star is a free milestone marker, not a spendable ticket. A
/// 5×6 chart therefore holds 25 tickets; anything beyond that overflows into
/// the Vault.
public enum TicketService {

    /// Signed balance for one child: earn/award (+) minus spend (−).
    public static func balance(for childID: String, in entries: [TicketLedgerEntry]) -> Int {
        entries.reduce(0) { $0 + ($1.childID == childID ? $1.amount : 0) }
    }

    // MARK: Reward-chart geometry

    /// Earnable ticket slots per row — every column except the trailing star.
    public static func ticketColumns(_ chart: TicketsContract.RewardChart) -> Int {
        max(0, chart.slotsPerRow - 1)
    }

    /// How many tickets the printed chart can hold before the Vault (rows ×
    /// earnable columns). 25 for the standard 5×6 chart.
    public static func ticketCapacity(_ chart: TicketsContract.RewardChart) -> Int {
        chart.rows * ticketColumns(chart)
    }

    /// Tickets held beyond a full chart — rendered as "in the Vault".
    public static func vaultBalance(_ balance: Int, chart: TicketsContract.RewardChart) -> Int {
        max(0, balance - ticketCapacity(chart))
    }

    /// Milestone stars reached — one for each fully-filled row.
    public static func starsEarned(_ balance: Int, chart: TicketsContract.RewardChart) -> Int {
        let columns = ticketColumns(chart)
        guard columns > 0 else { return 0 }
        return min(min(max(balance, 0), ticketCapacity(chart)) / columns, chart.rows)
    }

    /// Whether a child can afford a spend tier right now.
    public static func canAfford(cost: Int, balance: Int) -> Bool {
        balance >= cost
    }

    /// One cell of the reward chart, laid out row-major across `slotsPerRow`
    /// columns. `.ticket` cells fill as tickets are earned; the trailing
    /// `.star` in each row lights when that row is complete.
    public enum RewardCell: Equatable, Sendable {
        case ticket(filled: Bool)
        case star(earned: Bool)
    }

    /// The full chart as cells, in reading order (top-left to bottom-right).
    public static func cells(balance: Int, chart: TicketsContract.RewardChart) -> [RewardCell] {
        let columns = chart.slotsPerRow
        let ticketCols = ticketColumns(chart)
        let clamped = max(balance, 0)

        return (0..<chart.totalSlots).map { index in
            let row = index / columns
            let col = index % columns
            if col == columns - 1 {
                return .star(earned: clamped >= (row + 1) * ticketCols)
            }
            let ticketIndex = row * ticketCols + col   // 0-based earnable slot
            return .ticket(filled: ticketIndex < clamped)
        }
    }
}
