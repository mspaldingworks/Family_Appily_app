import FamilyCore
import SwiftData
import SwiftUI

/// The app's root. A Family tab — the profile picker → child chart → family
/// rotation flow the app still opens into (§3.5) — and a Parents tab, gated
/// behind Face ID / passcode so a child can't reach chore definitions,
/// balances, or settings. Also kicks off the one-time seed of family data.
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var seedingError: Error?

    var body: some View {
        TabView {
            ProfilePickerView()
                .tabItem { Label("Family", systemImage: "house.fill") }

            NavigationStack {
                AdultGated(reason: "Open the parents area to change chores, tickets, and settings") {
                    ParentDashboardView()
                }
            }
            .tabItem { Label("Parents", systemImage: "gearshape.fill") }
        }
        .task {
            do {
                try FamilySeeder.seedIfNeeded(context: modelContext)
            } catch {
                seedingError = error
            }
        }
        .alert("Couldn't load family data", isPresented: .constant(seedingError != nil)) {
            Button("OK") { seedingError = nil }
        } message: {
            Text(seedingError?.localizedDescription ?? "")
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Child.self, Chore.self, ChoreAssignment.self, Completion.self, RotationChore.self, EarnItem.self, SpendTier.self, TicketLedgerEntry.self], inMemory: true)
}
