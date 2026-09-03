import FamilyCore
import SwiftData
import SwiftUI

/// Family Appily on the Mac — the same app as the phone, not a cut-down one.
///
/// Household data comes from the same CloudKit container as iOS, so the chore
/// chart and rewards are one set of data seen from two places rather than two
/// copies. No adult Face ID gate at launch: this is her own Mac, which she
/// unlocked to get here, unlike the shared iPad the gate exists for.
@main
struct FamilyAppilyMacApp: App {
    let modelContainer = FamilyModelContainer.make()

    var body: some Scene {
        WindowGroup {
            FamilyAppilyMacRootView()
                .frame(minWidth: 900, minHeight: 560)
        }
        .modelContainer(modelContainer)
        .commands {
            // CLAUDE.md §3.8 asks for a real menu bar on Mac, not a stub.
            CommandGroup(replacing: .newItem) {}
            SidebarCommands()
        }
    }
}
