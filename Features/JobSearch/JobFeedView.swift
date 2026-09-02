import JobSearchCore
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Postings pushed in by the Apify scrapers, ranked best-fit first by the
/// server. Tap "Select" to tick several and prepare them all at once — that
/// writes tailored materials, queues each as an application, and mirrors them
/// into the Google Sheet.
struct JobFeedView: View {
    let client: JobSearchAPIClient
    let onUnauthorized: () -> Void

    @State private var postings: [IngestedPosting] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var applyingID: Int?

    @State private var isSelecting = false
    @State private var selection: Set<Int> = []
    @State private var job: PrepareJob?
    @State private var isPreparing = false

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
                        isSelecting: isSelecting,
                        isSelected: selection.contains(posting.id),
                        isApplying: applyingID == posting.id,
                        onToggle: { toggle(posting) },
                        onApply: { Task { await applyTo(posting) } },
                        onSignIn: { openSignIn(posting) }
                    )
                }
                .listStyle(.inset)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelecting { selectionBar }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isSelecting ? "Done" : "Select") {
                    isSelecting.toggle()
                    if !isSelecting { selection.removeAll() }
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: Bulk prepare

    @ViewBuilder
    private var selectionBar: some View {
        VStack(spacing: 8) {
            if let job, !job.isFinished {
                ProgressView(value: Double(job.done), total: Double(max(job.total, 1))) {
                    Text("Preparing \(job.done) of \(job.total)…")
                        .font(.footnote)
                }
                .padding(.horizontal)
            } else if let job, job.isFinished {
                Text(summary(for: job))
                    .font(.footnote)
                    .foregroundStyle(job.failures.isEmpty ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
            }

            HStack(spacing: 12) {
                Button(selection.count == postings.count ? "Clear" : "Select all") {
                    if selection.count == postings.count {
                        selection.removeAll()
                    } else {
                        selection = Set(postings.map(\.id))
                    }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)

                Button {
                    Task { await prepareSelected() }
                } label: {
                    if isPreparing {
                        ProgressView()
                    } else {
                        Text("Prepare \(selection.count)")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
                .disabled(selection.isEmpty || isPreparing)
                .accessibilityLabel("Prepare \(selection.count) applications")
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(.bar)
    }

    private func summary(for job: PrepareJob) -> String {
        let ready = job.results.filter(\.ok).count
        if job.failures.isEmpty {
            return "\(ready) ready to submit. Check the Applications tab or your sheet."
        }
        return "\(ready) ready, \(job.failures.count) couldn't be queued: "
            + job.failures.map(\.detail).joined(separator: " ")
    }

    private func toggle(_ posting: IngestedPosting) {
        if selection.contains(posting.id) {
            selection.remove(posting.id)
        } else {
            selection.insert(posting.id)
        }
    }

    private func prepareSelected() async {
        isPreparing = true
        defer { isPreparing = false }
        do {
            var current = try await client.prepareApplications(postingIDs: Array(selection))
            job = current
            // Generation runs ~40s per posting server-side, so poll rather than
            // holding one request open for the length of the whole batch.
            while !current.isFinished {
                try await Task.sleep(for: .seconds(3))
                current = try await client.prepareStatus(jobID: current.id)
                job = current
            }
            selection.removeAll()
            await load()
        } catch JobSearchAPIError.notAuthenticated {
            onUnauthorized()
        } catch {
            errorMessage = "Couldn't prepare those: \(error)"
        }
    }

    // MARK: Loading

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

    /// One tap does the whole thing: write the materials if they're missing,
    /// track the application, then open the employer's portal. Generating takes
    /// about 40 seconds the first time, which is why the row shows progress
    /// rather than appearing to hang.
    private func applyTo(_ posting: IngestedPosting) async {
        applyingID = posting.id
        defer { applyingID = nil }
        do {
            var job = try await client.prepareApplications(postingIDs: [posting.id])
            while !job.isFinished {
                try await Task.sleep(for: .seconds(3))
                job = try await client.prepareStatus(jobID: job.id)
            }
            if let failure = job.failures.first {
                errorMessage = failure.detail
            }
            if let link = posting.bestApplyLink {
                openURL(link)
            }
            postings.removeAll { $0.id == posting.id }
        } catch JobSearchAPIError.notAuthenticated {
            onUnauthorized()
        } catch {
            errorMessage = "Couldn't prepare \(posting.title): \(error)"
        }
    }

    private func openSignIn(_ posting: IngestedPosting) {
        if let link = posting.signInLink { openURL(link) }
    }

    private func openURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }
}

private struct PostingRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let posting: IngestedPosting
    let isSelecting: Bool
    let isSelected: Bool
    let isApplying: Bool
    let onToggle: () -> Void
    let onApply: () -> Void
    let onSignIn: () -> Void

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
        HStack(alignment: .top, spacing: 12) {
            if isSelecting {
                // Shape carries the state, not just colour (CLAUDE.md §3.2):
                // a filled check versus an empty circle reads without colour.
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(posting.score)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(scoreColor)
                        .accessibilityLabel("Match score \(posting.score) out of 100")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(posting.title).font(.headline)
                        HStack(spacing: 6) {
                            if !posting.companyName.isEmpty {
                                Text(posting.companyName).font(.subheadline).foregroundStyle(.secondary)
                            }
                            if posting.requiresAccount, !isSelecting {
                                accountBadge
                            }
                        }
                    }
                }

                if !posting.scoreReasons.isEmpty {
                    Text(posting.scoreReasons.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Per-row actions would compete with the checkbox for the same
                // tap, so they're hidden while selecting.
                if !isSelecting { actions }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { if isSelecting { onToggle() } }
        .accessibilityElement(children: isSelecting ? .combine : .contain)
        .accessibilityAddTraits(isSelecting && isSelected ? [.isSelected] : [])
        .accessibilityHint(isSelecting ? "Double tap to select for bulk apply" : "")
    }

    // Three buttons side by side clip at accessibility text sizes
    // (CLAUDE.md §3.2 treats truncation as a bug), so stack them there.
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

    /// Tapping the badge goes straight to the portal's sign-in page, because
    /// these platforms won't show the application form to a stranger — landing
    /// on the job post from a phone is a dead end otherwise.
    private var accountBadge: some View {
        Button(action: onSignIn) {
            Label(posting.platform.isEmpty ? "Account needed" : "\(posting.platform) account",
                  systemImage: "person.badge.key.fill")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.orange)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel("\(posting.platform.isEmpty ? "This employer" : posting.platform) needs an account first. Opens the sign-in page.")
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: onApply) {
            if isApplying {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Writing your materials…")
                }
            } else {
                Label("Apply", systemImage: "arrow.up.right.square")
            }
        }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .disabled(isApplying)
        .accessibilityLabel(isApplying
            ? "Preparing your application for \(posting.title)"
            : "Apply to \(posting.title). Writes your cover letter and resume, saves it to the tracker, then opens the employer's form.")
    }
}
