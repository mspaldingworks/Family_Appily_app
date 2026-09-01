import JobSearchCore
import SwiftUI

/// Postings pushed in by the Apify scrapers, ranked best-fit first by the
/// server. "Save" promotes one into the tracker; "Apply" opens the employer's
/// actual application form.
struct JobFeedView: View {
    let client: JobSearchAPIClient
    let onUnauthorized: () -> Void

    @State private var postings: [IngestedPosting] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var promotingID: Int?
    @State private var materialsFor: IngestedPosting?

    var body: some View {
        Group {
            if isLoading && postings.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if postings.isEmpty {
                ContentUnavailableView(
                    "No postings yet",
                    systemImage: "tray",
                    description: Text("Scraped postings will show up here, best match first.")
                )
            } else {
                List(postings) { posting in
                    PostingRow(
                        posting: posting,
                        isPromoting: promotingID == posting.id,
                        onSave: { Task { await promote(posting) } },
                        onGenerate: { materialsFor = posting }
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
        .sheet(item: $materialsFor) { posting in
            MaterialsView(client: client, posting: posting)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            postings = try await client.fetchIngestedPostings(status: .new)
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
    @Environment(\.dynamicTypeSize) private var typeSize

    let posting: IngestedPosting
    let isPromoting: Bool
    let onSave: () -> Void
    let onGenerate: () -> Void

    /// Green / amber / grey rather than a number alone, so the strength of a
    /// match reads at a glance without parsing digits.
    private var scoreColor: Color {
        switch posting.score {
        case 80...: return .green
        case 55..<80: return .orange
        default: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(posting.score)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(scoreColor)
                    .accessibilityLabel("Match score \(posting.score) out of 100")

                VStack(alignment: .leading, spacing: 2) {
                    Text(posting.title).font(.headline)
                    if !posting.companyName.isEmpty {
                        Text(posting.companyName).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }

            if !posting.scoreReasons.isEmpty {
                Text(posting.scoreReasons.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Three buttons side by side clip at accessibility text sizes
            // (CLAUDE.md §3.2 treats truncation as a bug), so stack them there.
            actions
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var actions: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) { actionButtons }
        } else {
            HStack(spacing: 10) {
                actionButtons
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
                if let link = posting.bestApplyLink {
                    Link(destination: link) {
                        Label("Apply", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                }

                Button(action: onSave) {
                    if isPromoting {
                        ProgressView()
                    } else {
                        Label("Save to tracker", systemImage: "tray.and.arrow.down")
                    }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .disabled(isPromoting)
                .accessibilityLabel("Save \(posting.title) to tracker")

                Button(action: onGenerate) {
                    Label("Write for me", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
                .accessibilityLabel("Generate a tailored cover letter and resume for \(posting.title)")
    }
}
