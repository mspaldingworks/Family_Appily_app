import JobSearchCore
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Tailored cover letter and resume for one posting, generated server-side.
/// Read-and-copy, deliberately: nothing here is submitted anywhere. The gaps
/// section is shown as prominently as the letter, because knowing what a
/// screener will probe is worth as much as the polished prose.
struct MaterialsView: View {
    let client: JobSearchAPIClient
    let posting: IngestedPosting

    @Environment(\.dismiss) private var dismiss
    @State private var materials: ApplicationMaterials?
    @State private var isLoading = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Group {
                if let materials {
                    content(materials)
                } else if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Writing your letter and resume…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        message ?? "Nothing generated yet",
                        systemImage: "doc.text",
                        description: Text(message == nil
                            ? "Generate a cover letter and resume tailored to this posting."
                            : "")
                    )
                }
            }
            .navigationTitle("Application materials")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(materials == nil ? "Generate" : "Redo") {
                        Task { await load(refresh: materials != nil) }
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task { await load(refresh: false) }
    }

    @ViewBuilder
    private func content(_ materials: ApplicationMaterials) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if materials.unparsed {
                    Label("Formatting was off, so this is the raw output.", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                block("Cover letter", text: materials.coverLetter)

                if !materials.resumeSummary.isEmpty {
                    block("Resume summary", text: materials.resumeSummary)
                }

                if !materials.resumeBullets.isEmpty {
                    block(
                        "Resume bullets",
                        text: materials.resumeBullets.map { "• \($0)" }.joined(separator: "\n")
                    )
                }

                if !materials.gaps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Gaps they'll probe")
                            .font(.headline)
                        ForEach(materials.gaps, id: \.self) { gap in
                            Text(gap)
                                .font(.callout)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
        }
    }

    private func block(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button {
                    copy(text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                }
                .frame(minHeight: 44)
                .accessibilityLabel("Copy \(title)")
            }
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }

    private func load(refresh: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            materials = try await client.generateMaterials(postingID: posting.id, refresh: refresh)
            message = nil
        } catch JobSearchAPIError.unavailable(let detail) {
            message = detail
        } catch {
            message = "Couldn't generate materials: \(error)"
        }
    }
}
