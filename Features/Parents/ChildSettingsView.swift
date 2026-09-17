import FamilyCore
import SwiftData
import SwiftUI

/// One child's editable settings for an adult: their display name, a manual
/// ticket adjustment (the "award or revoke rewards" power from CLAUDE.md §4,
/// logged to the same append-only ledger so the balance stays auditable and
/// can't drift), and a jump to their reward chart.
struct ChildSettingsView: View {
    @Bindable var child: Child

    @Environment(\.modelContext) private var modelContext
    @Query private var ticketEntries: [TicketLedgerEntry]

    private var theme: ChildTheme { ChildTheme.theme(for: child.childID ?? .finley) }
    private var balance: Int { TicketService.balance(for: child.id, in: ticketEntries) }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $child.name)
            }

            Section {
                LabeledContent("Balance") {
                    Label("\(balance) tickets", systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(theme.dotFill)
                        .fontWeight(.semibold)
                }
                HStack(spacing: 10) {
                    adjustButton(-5)
                    adjustButton(-1)
                    adjustButton(1)
                    adjustButton(5)
                }
            } header: {
                Text("Tickets")
            } footer: {
                Text("Manual changes are logged like every other ticket, so the running total always matches its history. A revoke can't push the balance below zero.")
            }

            Section {
                NavigationLink {
                    RewardsView(child: child)
                } label: {
                    Label("Open reward chart", systemImage: "chart.bar.doc.horizontal")
                }
                .frame(minHeight: 44)
            }
        }
        .navigationTitle(child.name)
    }

    private func adjustButton(_ delta: Int) -> some View {
        Button {
            adjust(delta)
        } label: {
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(theme.dotFill)
        .disabled(delta < 0 && balance <= 0)
        .accessibilityLabel(delta > 0 ? "Give \(delta) tickets" : "Take back \(-delta) tickets")
    }

    private func adjust(_ delta: Int) {
        // Clamp a revoke so a manual adjustment can never drive the balance negative.
        let applied = max(delta, -balance)
        guard applied != 0 else { return }
        modelContext.insert(TicketLedgerEntry(childID: child.id, amount: applied, kind: .adultAward, referenceID: "manual-adjust"))
        try? modelContext.save()
    }
}
