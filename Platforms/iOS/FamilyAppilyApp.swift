import FamilyCore
import JobSearchCore
import SwiftData
import SwiftUI

@main
struct FamilyAppilyApp: App {
    let modelContainer = FamilyModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(modelContainer)
    }
}
