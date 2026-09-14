import FamilyCore
import SwiftData
import SwiftUI

/// Sidebar + detail, the idiomatic Mac shape. The household surfaces — the
/// profile picker and the family rotation — seen from the desktop.
struct FamilyAppilyMacRootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selection: Item? = .home
    @State private var seedingError: Error?

    enum Item: String, CaseIterable, Identifiable {
        case home = "Home"
        case rotation = "Family Rotation"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .rotation: return "arrow.triangle.2.circlepath"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Household") {
                    ForEach(Item.allCases) { item in
                        Label(item.rawValue, systemImage: item.systemImage).tag(item)
                    }
                }
            }
            .navigationTitle("Family Appily")
            .listStyle(.sidebar)
        } detail: {
            detail
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

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .home:
            ProfilePickerView().navigationTitle("Home")
        case .rotation:
            FamilyRotationView().navigationTitle("Family Rotation")
        case nil:
            ContentUnavailableView("Pick a section", systemImage: "sidebar.left")
        }
    }
}
