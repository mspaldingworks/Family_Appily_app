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
    @Environment(\.dismiss) private var dismiss
    @Query private var ticketEntries: [TicketLedgerEntry]
    @State private var showDeleteConfirm = false

    private var theme: ChildTheme { ChildTheme.theme(for: child) }
    private var balance: Int { TicketService.balance(for: child.id, in: ticketEntries) }
    private var isCustomKid: Bool { child.childID == nil }

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $child.name)
            }

            Section("Age") {
                Stepper(value: $child.age, in: 0...25) {
                    Text(child.age == 0 ? "Age: not set" : "Age: \(child.age)")
                }
                .frame(minHeight: 44)
            }

            if isCustomKid {
                Section {
                    colorPicker
                } header: {
                    Text("Colour")
                } footer: {
                    Text("This child's colour everywhere they appear.")
                }
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

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Remove \(child.name)", systemImage: "trash")
                }
                .frame(minHeight: 44)
            } footer: {
                Text("Removes this child and all of their chores, cards, and tickets. This can't be undone.")
            }
        }
        .navigationTitle(child.name)
        .confirmationDialog("Remove \(child.name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Remove \(child.name)", role: .destructive) {
                FamilyRoster.deleteChild(child, context: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes their chores, cards, and tickets. It can't be undone.")
        }
    }

    /// Swatches from `KidPalette`; each a 44pt tap target with a check on the
    /// current pick (never colour-alone, §3.2). Only shown for parent-added kids.
    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(KidPalette.colors, id: \.self) { hex in
                let selected = child.colorHex == hex
                Circle()
                    .fill(ChildTheme.custom(hex: hex).dotFill)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().strokeBorder(Color.primary.opacity(selected ? 0.9 : 0.15), lineWidth: 2))
                    .overlay(selected ? Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white) : nil)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .onTapGesture { child.colorHex = hex }
                    .accessibilityLabel("Colour option")
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
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
