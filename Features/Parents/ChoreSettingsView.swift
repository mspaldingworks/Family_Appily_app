import FamilyCore
import SwiftData
import SwiftUI

/// Adult editing of chore definitions (CLAUDE.md §4). Each chore's label and SF
/// Symbol are editable; edits save straight to the shared store and show up on
/// the children's charts. Rotation-resolved chores are flagged, since their
/// day-to-day label comes from the family rotation rather than being typed here.
struct ChoreSettingsView: View {
    @Query(sort: \Chore.defaultLabel) private var chores: [Chore]

    var body: some View {
        Form {
            ForEach(chores) { chore in
                ChoreEditRow(chore: chore)
            }
        }
        .navigationTitle("Chores")
    }
}

private struct ChoreEditRow: View {
    @Bindable var chore: Chore

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: chore.sfSymbol.isEmpty ? "questionmark.square.dashed" : chore.sfSymbol)
                    .font(.title3)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                TextField("Chore name", text: $chore.defaultLabel)
            }
            LabeledContent("SF Symbol") {
                TextField("symbol", text: $chore.sfSymbol)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }
            if chore.choreType == .rotationResolved {
                Text("Filled by the family rotation — this label only shows before the rotation is set up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
