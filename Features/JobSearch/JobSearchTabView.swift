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
                            ApplicationsBoardView(client: client)
                        case .jobFeed:
                            JobFeedView(client: client)
                        case .identity:
                            IdentityView(client: client)
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
}

private struct JobSearchSetupView: View {
    let onSave: (String) -> Void
    @State private var token = ""

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "briefcase.fill")
                .font(.system(size: 48))
                .accessibilityHidden(true)
            Text("Connect Job Search")
                .font(.title2.weight(.semibold))
            Text("Enter the API token generated for this device. This is a one-time setup, not an account.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            SecureField("API token", text: $token)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
            Button("Save") { onSave(token) }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                .disabled(token.isEmpty)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
