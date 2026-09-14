import FamilyCore
import SwiftData
import SwiftUI

/// The app's root. Hosts the Profile picker → Child chart → Family rotation
/// flow and kicks off the one-time seed of family data.
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var seedingError: Error?

    var body: some View {
        ProfilePickerView()
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
