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

            AdultGated(reason: "Unlock Job Search") {
                JobSearchTabView()
            }
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
