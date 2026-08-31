import SwiftUI

/// Mac desktop app for Job Search only — the household side (chores, rotation,
/// tickets) is CloudKit/SwiftData-based and deliberately stays out of scope
/// here; this target has no dependency on FamilyCore at all. No adult Face
/// ID/PIN gate either: unlike the shared family iPad, this runs on the user's
/// own personal Mac that they launch themselves.
@main
struct FamilyAppilyJobSearchApp: App {
    var body: some Scene {
        WindowGroup {
            JobSearchMacRootView()
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
