import JobSearchCore
import SwiftUI

/// Sidebar + detail, the idiomatic Mac shape — same three sections as the
/// iOS tab (Applications / Job Feed / Identity), same views underneath.
struct JobSearchMacRootView: View {
    @State private var client: JobSearchAPIClient?
    @State private var selection: Section? = .applications

    enum Section: String, CaseIterable, Identifiable {
        case applications = "Applications"
        case jobFeed = "Job Feed"
        case identity = "Identity"

        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .applications: return "list.bullet.rectangle"
            case .jobFeed: return "tray.and.arrow.down"
            case .identity: return "person.text.rectangle"
            }
        }
    }

    var body: some View {
        Group {
            if let client {
                NavigationSplitView {
                    List(Section.allCases, selection: $selection) { section in
                        Label(section.rawValue, systemImage: section.systemImage)
                    }
                    .navigationTitle("Job Search")
                    .listStyle(.sidebar)
                } detail: {
                    switch selection {
                    case .applications:
                        ApplicationsBoardView(client: client, onUnauthorized: signOut)
                            .navigationTitle("Applications")
                    case .jobFeed:
                        JobFeedView(client: client, onUnauthorized: signOut)
                            .navigationTitle("Job Feed")
                    case .identity:
                        IdentityView(client: client, onUnauthorized: signOut)
                            .navigationTitle("Identity")
                    case nil:
                        ContentUnavailableView("Select a section", systemImage: "sidebar.left")
                    }
                }
            } else {
                JobSearchSetupView { token in
                    JobSearchKeychain.saveToken(token)
                    client = JobSearchConfig.makeClient()
                }
            }
        }
        .task {
            client = JobSearchConfig.makeClient()
        }
    }

    /// The stored token was rejected — clear it and drop back to setup rather
    /// than getting stuck showing errors with no way to fix it in-app.
    private func signOut() {
        JobSearchKeychain.clearToken()
        client = nil
    }
}
