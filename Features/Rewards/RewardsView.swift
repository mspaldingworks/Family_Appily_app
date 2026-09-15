import FamilyCore
import SwiftData
import SwiftUI

/// One child's ticket economy on a single screen: the reward chart (balance at
/// rest, per §3.7), the "HOW TO EARN" catalog, and the "HOW TO SPEND" tiers —
/// the digital twin of the child's physical earn/spend sheet.
///
/// Roles (CLAUDE.md §4): a child marks their own chores complete on the weekly
/// chart and each one auto-earns a ticket. Awarding a *behavioural* ticket
/// (polite, tried new food…) and redeeming a reward are adult judgement calls,
/// so both are gated with Face ID / passcode inline at the moment of the action
/// — never a login wall. A child tapping "Redeem" simply surfaces that prompt,
/// which is their "request reward redemption" path.
struct RewardsView: View {
    let child: Child

    @Environment(\.modelContext) private var modelContext
    @Query private var earnItems: [EarnItem]
    @Query private var spendTiers: [SpendTier]
    @Query private var ticketEntries: [TicketLedgerEntry]

    @StateObject private var gate = AdultGate()
    @State private var flash: String?

    private var theme: ChildTheme { ChildTheme.theme(for: child.childID ?? .finley) }
    private var balance: Int { TicketService.balance(for: child.id, in: ticketEntries) }
    private var chart: TicketsContract.RewardChart? { try? BundledContractSource().loadTickets().rewardChart }

    /// Earn items for this child's *own* profile: the shared household items plus
    /// this child's own — which includes their private, health-adjacent items.
    /// That is allowed here because §7.7/§5 permit a child's own profile (and
    /// adults) to see private items; shared/family surfaces must not.
    private var visibleEarnItems: [EarnItem] {
        earnItems
            .filter { $0.childID == nil || $0.childID == child.id }
            .sorted { lhs, rhs in
                (lhs.childID == nil ? 0 : 1, lhs.label) < (rhs.childID == nil ? 0 : 1, rhs.label)
            }
    }

    private var sortedTiers: [SpendTier] { spendTiers.sorted { $0.cost < $1.cost } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let chart {
                    RewardChartView(theme: theme, balance: balance, chart: chart)
                }
                earnSection
                spendSection
            }
            .padding()
        }
        .navigationTitle("\(child.name)'s tickets")
        .overlay(alignment: .bottom) { flashBanner }
        .task(id: flash) {
            // Confirmation lingers well past the 5s floor in §3.5 — nothing here
            // punishes slowness — then clears itself.
            guard flash != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            flash = nil
        }
    }

    // MARK: Earn

    private var earnSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("How to earn tickets", systemImage: "plus.circle.fill")
            ForEach(visibleEarnItems) { item in
                catalogRow(
                    label: item.label,
                    systemImage: item.sfSymbol,
                    isPrivate: item.isPrivate,
                    trailing: {
                        Button {
                            award(item)
                        } label: {
                            Label("Give 1", systemImage: "plus")
                                .labelStyle(.titleAndIcon)
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.dotFill)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Give \(child.name) one ticket for \(item.label)")
                    }
                )
            }
        }
    }

    // MARK: Spend

    private var spendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("How to spend tickets", systemImage: "cart.fill")
            ForEach(sortedTiers) { tier in
                let affordable = TicketService.canAfford(cost: tier.cost, balance: balance)
                catalogRow(
                    label: tier.label,
                    systemImage: tier.sfSymbol,
                    isPrivate: false,
                    trailing: {
                        Button {
                            redeem(tier)
                        } label: {
                            Text("\(tier.cost) 🎟")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(theme.dotFill)
                        .frame(minHeight: 44)
                        .disabled(!affordable)
                        .accessibilityLabel("Redeem \(tier.label) for \(tier.cost) tickets")
                        .accessibilityHint(affordable ? "Requires an adult" : "Not enough tickets yet")
                    }
                )
                .opacity(affordable ? 1 : 0.5)
            }
        }
    }

    // MARK: Building blocks

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.dotFill)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(SharedTokens.ink)
        }
    }

    private func catalogRow(
        label: String,
        systemImage: String,
        isPrivate: Bool,
        @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(SharedTokens.ink)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .foregroundStyle(SharedTokens.ink)
                if isPrivate {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(SharedTokens.inkSecondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(12)
        .frame(minHeight: 60)
        .background(RoundedRectangle(cornerRadius: 14).fill(SharedTokens.paper).shadow(radius: 1))
    }

    @ViewBuilder
    private var flashBanner: some View {
        if let flash {
            Text(flash)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(theme.dotFill))
                .padding(.bottom, 16)
                .shadow(radius: 3)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: Actions

    private func award(_ item: EarnItem) {
        Task {
            guard await gate.requestAccess(reason: "Award a ticket to \(child.name)") else { return }
            modelContext.insert(TicketLedgerEntry(childID: child.id, amount: 1, kind: .earn, referenceID: item.id))
            try? modelContext.save()
            flash = "+1 ticket · \(item.label)"
        }
    }

    private func redeem(_ tier: SpendTier) {
        Task {
            guard TicketService.canAfford(cost: tier.cost, balance: balance) else { return }
            guard await gate.requestAccess(reason: "Redeem \(tier.label) for \(child.name)") else { return }
            modelContext.insert(TicketLedgerEntry(childID: child.id, amount: -tier.cost, kind: .spend, referenceID: tier.id))
            try? modelContext.save()
            flash = "Redeemed · \(tier.label)"
        }
    }
}
