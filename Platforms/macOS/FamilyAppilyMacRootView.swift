import FamilyCore
import JobSearchCore
import SwiftData
import SwiftUI

/// Sidebar + detail, the idiomatic Mac shape. Household on top, the job-search
/// pipeline below it, in the order the pipeline actually runs.
struct FamilyAppilyMacRootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var client = JobSearchConfigBridge.makeClient()
    @State private var selection: Item? = .home
    @State private var isConnecting = false
    @State private var seedingError: Error?

    enum Item: String, CaseIterable, Identifiable {
        case home = "Home"
        case rotation = "Family Rotation"
        case jobFeed = "Job Feed"
        case drafts = "Drafts"
        case approvals = "Approvals"
        case applied = "Applied"
        case identity = "Identity"

        var id: String { rawValue }

        var isHousehold: Bool { self == .home || self == .rotation }

        var systemImage: String {
            switch self {
            case .home: return "house.fill"
            case .rotation: return "arrow.triangle.2.circlepath"
            case .jobFeed: return "tray.and.arrow.down"
            case .drafts: return "doc.text.magnifyingglass"
            case .approvals: return "checkmark.seal"
            case .applied: return "paperplane"
            case .identity: return "person.text.rectangle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Household") {
                    ForEach(Item.allCases.filter(\.isHousehold)) { item in
                        Label(item.rawValue, systemImage: item.systemImage).tag(item)
                    }
                }
                Section("Job Search") {
                    ForEach(Item.allCases.filter { !$0.isHousehold }) { item in
                        Label(item.rawValue, systemImage: item.systemImage).tag(item)
                    }
                }
            }
            .navigationTitle("Family Appily")
            .listStyle(.sidebar)
        } detail: {
            detail
        }
        .toolbar {
            if JobSearchConfigBridge.needsToken {
                ToolbarItem(placement: .primaryAction) {
                    Button("Connect Job Search") { isConnecting = true }
                }
            }
        }
        .sheet(isPresented: $isConnecting) {
            JobSearchSetupView { token in
                JobSearchKeychain.saveToken(token)
                client = JobSearchConfigBridge.makeClient()
                isConnecting = false
            }
            .frame(minWidth: 420, minHeight: 260)
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
        case .jobFeed:
            JobFeedView(client: client, onUnauthorized: { isConnecting = true })
                .navigationTitle("Job Feed")
        case .drafts:
            DraftsView(client: client, onUnauthorized: { isConnecting = true })
                .navigationTitle("Drafts")
        case .approvals:
            ApprovalsView(client: client, onUnauthorized: { isConnecting = true })
                .navigationTitle("Approvals")
        case .applied:
            AppliedView(client: client, onUnauthorized: { isConnecting = true })
                .navigationTitle("Applied")
        case .identity:
            IdentityView(client: client, onUnauthorized: { isConnecting = true })
                .navigationTitle("Identity")
        case nil:
            ContentUnavailableView("Pick a section", systemImage: "sidebar.left")
        }
    }
}

/// Thin indirection so the Mac root doesn't reach into JobSearchConfig's
/// internals; keeps the token-resolution rules in one place.
enum JobSearchConfigBridge {
    static func makeClient() -> JobSearchAPIClient { JobSearchConfig.makeClient() }
    static var needsToken: Bool { JobSearchConfig.resolvedToken == nil }
}
