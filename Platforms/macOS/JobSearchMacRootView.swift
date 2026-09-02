import JobSearchCore
import SwiftUI

/// Sidebar + detail, the idiomatic Mac shape — the same pipeline as the iOS
/// tab, in the same order: Job Feed → Drafts → Approvals → Applied, with
/// Identity alongside.
struct JobSearchMacRootView: View {
    @State private var client = JobSearchConfig.makeClient()
    @State private var selection: Section? = .jobFeed
    @State private var isConnecting = false

    enum Section: String, CaseIterable, Identifiable {
        case jobFeed = "Job Feed"
        case drafts = "Drafts"
        case approvals = "Approvals"
        case applied = "Applied"
        case identity = "Identity"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
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
            List(Section.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
            }
            .navigationTitle("Job Search")
            .listStyle(.sidebar)
        } detail: {
            detail
        }
        .toolbar {
            // Only when there's nothing to authenticate with; otherwise it's
            // clutter on a window meant for reading jobs.
            if JobSearchConfig.resolvedToken == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Connect") { isConnecting = true }
                }
            }
        }
        .sheet(isPresented: $isConnecting) {
            JobSearchSetupView { token in
                JobSearchKeychain.saveToken(token)
                client = JobSearchConfig.makeClient()
                isConnecting = false
            }
            .frame(minWidth: 420, minHeight: 260)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
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
            ContentUnavailableView("Select a section", systemImage: "sidebar.left")
        }
    }
}
