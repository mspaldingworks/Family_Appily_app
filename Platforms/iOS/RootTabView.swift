import FamilyCore
import SwiftData
import SwiftUI

/// The app-wide tab bar. "Home" contains the existing, unmodified Profile
/// picker → Child chart → Family rotation flow. "Job Search" is new and
/// adult-facing, so it sits behind the same inline Face ID/PIN gate the rest
/// of the app uses for adult actions — not a separate login system.
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var seedingError: Error?

    var body: some View {
        TabView {
            ProfilePickerView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            // Deliberately not behind the adult gate. This is her own job search
            // on her own phone — the point is to open the app and see options at
            // a glance, and a Face ID prompt every time defeats that. (AdultGate
            // still exists for reward redemption in Phase 5, which is genuinely
            // adult-only and lives on the shared iPad.)
            JobSearchTabView()
                .tabItem { Label("Job Search", systemImage: "briefcase.fill") }
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
