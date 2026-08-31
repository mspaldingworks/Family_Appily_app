import JobSearchCore
import SwiftUI

struct ApplicationsBoardView: View {
    let client: JobSearchAPIClient
    let onUnauthorized: () -> Void

    @State private var applications: [Application] = []
    @State private var companies: [Company] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddSheet = false

    var body: some View {
        Group {
            if isLoading && applications.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Application.Status.allCases, id: \.self) { status in
                        let items = applications.filter { $0.status == status }
                        if !items.isEmpty {
                            Section(status.label) {
                                ForEach(items) { application in
                                    ApplicationRow(application: application)
                                }
                            }
                        }
                    }
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
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddApplicationView(client: client, companies: companies) {
                Task { await load() }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let applicationsTask = client.fetchApplications()
            async let companiesTask = client.fetchCompanies()
            applications = try await applicationsTask
            companies = try await companiesTask
            errorMessage = nil
        } catch JobSearchAPIError.notAuthenticated {
            onUnauthorized()
        } catch {
            errorMessage = "Couldn't load applications: \(error)"
        }
    }
}

private struct ApplicationRow: View {
    let application: Application

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(application.roleTitle)
                .font(.headline)
            Text(application.companyName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !application.jobUrl.isEmpty, let url = URL(string: application.jobUrl) {
                Link("View posting", destination: url)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct AddApplicationView: View {
    let client: JobSearchAPIClient
    let companies: [Company]
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var companyName = ""
    @State private var roleTitle = ""
    @State private var jobURL = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Company", text: $companyName)
                TextField("Role title", text: $roleTitle)
                TextField("Job URL (optional)", text: $jobURL)
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Add Application")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(companyName.isEmpty || roleTitle.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let company: Company
            if let existing = companies.first(where: { $0.name.caseInsensitiveCompare(companyName) == .orderedSame }) {
                company = existing
            } else {
                company = try await client.createCompany(NewCompany(name: companyName))
            }
            _ = try await client.createApplication(NewApplication(company: company.id, roleTitle: roleTitle, jobUrl: jobURL))
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Couldn't save: \(error)"
        }
    }
}
