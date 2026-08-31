import JobSearchCore
import SwiftUI

/// Postings pushed in by the n8n RSS-ingestion webhook, for triage. "Save to
/// tracker" calls the promote endpoint, which the original web app only
/// exposed as a Django admin action — this is the native equivalent.
struct JobFeedView: View {
    let client: JobSearchAPIClient
    let onUnauthorized: () -> Void

    @State private var postings: [IngestedPosting] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var promotingID: Int?

    var body: some View {
        Group {
            if isLoading && postings.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if postings.isEmpty {
                ContentUnavailableView(
                    "No postings yet",
                    systemImage: "tray",
                    description: Text("RSS-sourced postings pushed in by your automation will show up here.")
                )
            } else {
                List(postings) { posting in
                    PostingRow(
                        posting: posting,
                        isPromoting: promotingID == posting.id,
                        onSave: { Task { await promote(posting) } }
                    )
                }
                .listStyle(.inset)
            }
        }
        .overlay(alignment: .bottom) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .padding(8)
                    .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            postings = try await client.fetchIngestedPostings().filter { $0.status == .new }
            errorMessage = nil
        } catch JobSearchAPIError.notAuthenticated {
            onUnauthorized()
        } catch {
            errorMessage = "Couldn't load the job feed: \(error)"
        }
    }

    private func promote(_ posting: IngestedPosting) async {
        promotingID = posting.id
        defer { promotingID = nil }
        do {
            _ = try await client.promotePosting(id: posting.id)
            postings.removeAll { $0.id == posting.id }
        } catch {
            errorMessage = "Couldn't save \(posting.title): \(error)"
        }
    }
}

private struct PostingRow: View {
    let posting: IngestedPosting
    let isPromoting: Bool
    let onSave: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(posting.title).font(.headline)
                if !posting.companyName.isEmpty {
                    Text(posting.companyName).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(posting.source).font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            Button(action: onSave) {
                if isPromoting {
                    ProgressView()
                } else {
                    Text("Save")
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(minWidth: 44, minHeight: 44)
            .disabled(isPromoting)
            .accessibilityLabel("Save \(posting.title) to tracker")
        }
        .padding(.vertical, 4)
    }
}
