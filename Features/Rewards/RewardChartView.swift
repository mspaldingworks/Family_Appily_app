import FamilyCore
import SwiftUI

/// One child's reward chart: five rows of six, a milestone star at the end of
/// each row, and a Vault for anything past a full chart — the digital twin of
/// the printed REWARD CHART. Per CLAUDE.md §3.7 the balance is visible at rest
/// here; per §3.2/§7.4 every state is carried by symbol + number + fixed ink,
/// never colour alone, and everything sits on the always-light paper card so
/// it stays legible in Dark Mode.
struct RewardChartView: View {
    let theme: ChildTheme
    let balance: Int
    let chart: TicketsContract.RewardChart

    private var stars: Int { TicketService.starsEarned(balance, chart: chart) }
    private var vault: Int { TicketService.vaultBalance(balance, chart: chart) }
    private var capacity: Int { TicketService.ticketCapacity(chart) }
    private var cells: [TicketService.RewardCell] { TicketService.cells(balance: balance, chart: chart) }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: chart.slotsPerRow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(theme.dotFill)
                    .accessibilityHidden(true)
                Text("\(balance) tickets")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(SharedTokens.ink)
                Spacer()
                Text("\(stars)★")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(SharedTokens.inkSecondary)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    slot(cell)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "archivebox.fill")
                    .foregroundStyle(theme.dotFill)
                    .accessibilityHidden(true)
                Text("Vault")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(SharedTokens.ink)
                Spacer()
                Text("\(vault) saved")
                    .font(.subheadline)
                    .foregroundStyle(SharedTokens.inkSecondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(theme.dotFill.opacity(0.12)))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(SharedTokens.paper).shadow(radius: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reward chart: \(balance) tickets, \(stars) of \(chart.rows) stars, \(vault) in the vault")
    }

    @ViewBuilder
    private func slot(_ cell: TicketService.RewardCell) -> some View {
        switch cell {
        case .ticket(let filled):
            Image(systemName: filled ? "ticket.fill" : "ticket")
                .font(.title3)
                .foregroundStyle(filled ? theme.dotFill : SharedTokens.inkSecondary.opacity(0.5))
                .frame(minWidth: 28, minHeight: 28)
                .accessibilityHidden(true)
        case .star(let earned):
            Image(systemName: earned ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(earned ? theme.dotFill : SharedTokens.inkSecondary.opacity(0.5))
                .frame(minWidth: 28, minHeight: 28)
                .accessibilityHidden(true)
        }
    }
}

#Preview("Mid-chart") {
    if let chart = try? BundledContractSource().loadTickets().rewardChart {
        RewardChartView(theme: .finley, balance: 13, chart: chart)
            .padding()
    }
}

#Preview("Overflowing, dark") {
    if let chart = try? BundledContractSource().loadTickets().rewardChart {
        RewardChartView(theme: .maryn, balance: 31, chart: chart)
            .padding()
            .preferredColorScheme(.dark)
    }
}
