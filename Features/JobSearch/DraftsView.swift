import JobSearchCore
import SwiftUI

/// Stage two of the pipeline. Materials are written; she reads them, edits if
/// she wants, and approves. Approving moves the application to Approvals — it
/// sends nothing.
///
/// Tap a row to read the whole draft, or approve straight from the list once
/// she's happy.
struct DraftsView: View {
    let client: JobSearchAPIClient
    let onUnauthorized: () -> Void

    @State private var applications: [Application] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var reviewing: Application?
    @State private var approvingID: Int?
    @State private var showingAddSheet = false
    @State private var companies: [Company] = []

    private var drafts: [Application] { applications.filter(\.isDraft) }

    var body: some View {
        Group {
            if isLoading && applications.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if drafts.isEmpty {
                ContentUnavailableView(
                    "No drafts waiting",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Tap Apply on a job in the feed and its draft lands here for review.")
                )
            } else {
                List(drafts) { application in
                    DraftRow(
                        application: application,
                        isApproving: approvingID == application.id,
                        onRead: { reviewing = application },
                        onApprove: { Task { await approve(application) } }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add application", systemImage: "plus")
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Add an application you found elsewhere")
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showingAddSheet) {
            AddApplicationView(client: client, companies: companies) {
                Task { await load() }
            }
        }
        .sheet(item: $reviewing) { application in
            DraftReviewView(client: client, application: application) { updated in
                if let index = applications.firstIndex(where: { $0.id == updated.id }) {
                    applications[index] = updated
                }
            }
        }
    }

    /// Approve without opening the draft. Sends nothing — it moves the
    /// application to the Approvals stage, where submitting happens.
    private func approve(_ application: Application) async {
        approvingID = application.id
        defer { approvingID = nil }
        do {
            _ = try await client.approveApplication(id: application.id)
            applications.removeAll { $0.id == application.id }
        } catch {
            errorMessage = "Couldn't approve \(application.roleTitle): \(error)"
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await client.fetchApplications()
            companies = (try? await client.fetchCompanies()) ?? companies
            errorMessage = nil
        } catch JobSearchAPIError.notAuthenticated {
            onUnauthorized()
        } catch {
            errorMessage = "Couldn't load your drafts: \(error)"
        }
    }
}

private struct DraftRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    let application: Application
    let isApproving: Bool
    let onRead: () -> Void
    let onApprove: () -> Void

    private var hasMaterials: Bool {
        !(application.generatedMaterials?.isEmpty ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(application.roleTitle).font(.headline)
                    Text(application.companyName).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                StatusChip(status: application.status)
            }

            if let materials = application.generatedMaterials, !materials.gaps.isEmpty {
                Label("\(materials.gaps.count) gaps to prepare for",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            actions
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var actions: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) { buttons }
        } else {
            HStack(spacing: 10) { buttons; Spacer() }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button(action: onRead) {
            Label("Read draft", systemImage: "doc.text.magnifyingglass")
        }
        .buttonStyle(.bordered)
        .frame(minHeight: 44)
        .accessibilityLabel("Read the draft for \(application.roleTitle)")

        Button(action: onApprove) {
            if isApproving {
                ProgressView()
            } else {
                Label("Approve", systemImage: "checkmark.seal")
            }
        }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .disabled(isApproving || !hasMaterials)
        .accessibilityLabel(hasMaterials
            ? "Approve \(application.roleTitle) and move it to Approvals"
            : "\(application.roleTitle) has no draft to approve yet")
    }
}

/// Status shown as text plus shape, never colour alone (CLAUDE.md §3.2).
struct StatusChip: View {
    let status: Application.Status

    private var symbol: String {
        switch status {
        case .approved: return "checkmark.seal.fill"
        case .applied: return "paperplane.fill"
        default: return "pencil.circle"
        }
    }

    private var tint: Color {
        switch status {
        case .approved: return .green
        case .applied: return .blue
        default: return .secondary
        }
    }

    var body: some View {
        Label(status.label, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .labelStyle(.titleAndIcon)
            .accessibilityLabel("Status: \(status.label)")
    }
}
