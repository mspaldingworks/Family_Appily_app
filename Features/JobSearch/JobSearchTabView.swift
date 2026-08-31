import JobSearchCore
import SwiftUI

/// Root of the Job Search tab. No client until an adult has entered the API
/// token once (Keychain-backed, no login flow) — see JobSearchConfig.
public struct JobSearchTabView: View {
    @State private var client: JobSearchAPIClient?
    @State private var selectedSection = Section.applications

    enum Section: String, CaseIterable, Identifiable {
        case applications = "Applications"
        case jobFeed = "Job Feed"
        case identity = "Identity"
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if let client {
                    VStack(spacing: 0) {
                        Picker("Section", selection: $selectedSection) {
                            ForEach(Section.allCases) { section in
                                Text(section.rawValue).tag(section)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        switch selectedSection {
                        case .applications:
                            ApplicationsBoardView(client: client, onUnauthorized: signOut)
                        case .jobFeed:
                            JobFeedView(client: client, onUnauthorized: signOut)
                        case .identity:
                            IdentityView(client: client, onUnauthorized: signOut)
                        }
                    }
                } else {
                    JobSearchSetupView { token in
                        JobSearchKeychain.saveToken(token)
                        client = JobSearchConfig.makeClient()
                    }
                }
            }
            .navigationTitle("Job Search")
        }
        .task {
            client = JobSearchConfig.makeClient()
        }
    }

    /// The stored token was rejected (wrong, revoked, or never valid) — clear
    /// it and drop back to setup rather than getting stuck showing errors
    /// forever with no way to fix it from within the app.
    private func signOut() {
        JobSearchKeychain.clearToken()
        client = nil
    }
}
