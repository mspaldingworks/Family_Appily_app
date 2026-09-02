import JobSearchCore
import SwiftUI

/// Drafts waiting on her: materials generated, not yet sent. Tapping one opens
/// the full review, where she can edit the letter, approve it, open the
/// employer's portal, and record that she applied.
struct DraftsView: View {
    let client: JobSearchAPIClient
    let onUnauthorized: () -> Void

    @State private var applications: [Application] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var reviewing: Application?

    private var drafts: [Application] { applications.filter(\.isDraft) }

    var body: some View {
        Group {
            if isLoading && applications.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if drafts.isEmpty {
                ContentUnavailableView(
                    "No drafts waiting",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Pick jobs in the Job Feed and tap Prepare — their drafts land here for review.")
                )
            } else {
                List(drafts) { application in
                    Button {
                        reviewing = application
                    } label: {
                        DraftRow(application: application)
                    }
                    .buttonStyle(.plain)
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
        .sheet(item: $reviewing) { application in
            DraftReviewView(client: client, application: application) { updated in
                if let index = applications.firstIndex(where: { $0.id == updated.id }) {
                    applications[index] = updated
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await client.fetchApplications()
            errorMessage = nil
        } catch JobSearchAPIError.notAuthenticated {
            onUnauthorized()
        } catch {
            errorMessage = "Couldn't load your drafts: \(error)"
        }
    }
}

private struct DraftRow: View {
    let application: Application

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the draft for review")
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
