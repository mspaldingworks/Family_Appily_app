import FamilyCore
import SwiftData
import SwiftUI

/// Adult editing of chore definitions (CLAUDE.md §4), revamped as colourful
/// cards. Each chore is a card: a saturated tile previews its icon + ticket
/// value exactly as they'll read at a glance, and the fields beside it edit the
/// icon, colour, ticket value, and an optional due date. Edits autosave to the
/// shared store and show up on the children's charts.
///
/// This is an adult admin surface, so the *fields* use system colours that
/// follow Light/Dark Mode. Only the coloured tile pins a fixed foreground, and
/// there `ChoreColor` guarantees an AA-clearing `onColor` (CLAUDE.md §3.2).
/// Colour is never the sole signal: every card repeats itself as icon, name,
/// numeric ticket value, and a written colour name.
struct ChoreSettingsView: View {
    @Query(sort: \Chore.defaultLabel) private var chores: [Chore]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(chores) { chore in
                    ChoreDefinitionCard(chore: chore)
                }
            }
            .padding(16)
        }
        .navigationTitle("Chores")
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #endif
    }
}

/// One chore-definition card. `@Bindable` so the fields write straight through
/// to the model; SwiftData autosaves on the main context (matching the previous
/// form-based editor, which also relied on autosave).
struct ChoreDefinitionCard: View {
    @Bindable var chore: Chore

    var body: some View {
        // Side-by-side like the mockup when there's room; stacks when Dynamic
        // Type grows, so nothing clips at AX5 (CLAUDE.md §3.2).
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                previewTile
                fields
            }
            VStack(alignment: .leading, spacing: 16) {
                previewTile
                fields
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(chore.choreColor.fill.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(chore.choreColor.fill.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: The coloured preview tile (icon over big ticket count)

    private var previewTile: some View {
        let color = chore.choreColor
        return VStack(spacing: 8) {
            Image(systemName: displaySymbol)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(color.onColor)
            Text("\(chore.ticketValue)")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .foregroundStyle(color.onColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .padding(16)
        .frame(minWidth: 108, minHeight: 108)
        .background(color.fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(color.onColor.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                .padding(5)
        )
        // The tile is a live preview of the fields below, which carry the
        // semantics — don't read it out twice to VoiceOver.
        .accessibilityHidden(true)
    }

    // MARK: The editable fields (the mockup's legend, made interactive)

    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
            labelled("Name") {
                TextField("Chore name", text: $chore.defaultLabel)
                    .textFieldStyle(.roundedBorder)
            }

            labelled("Icon") {
                HStack(spacing: 8) {
                    Image(systemName: displaySymbol)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    TextField("SF Symbol name", text: $chore.sfSymbol)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    fieldLabel("Color")
                    Spacer()
                    Text(chore.choreColor.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                colorPicker
            }

            VStack(alignment: .leading, spacing: 4) {
                Stepper(value: $chore.ticketValue, in: 1...20) {
                    Label("Tickets: \(chore.ticketValue)", systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                }
                Text("Earned when a child checks this chore off, added to their reward chart.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Give it a due date", isOn: hasDueDate)
                if chore.dueDate != nil {
                    DatePicker("Due date", selection: dueDateBinding, displayedComponents: .date)
                        #if os(iOS)
                        .datePickerStyle(.compact)
                        #endif
                }
            }

            if chore.choreType == .rotationResolved {
                Text("Filled by the family rotation — this label only shows before the rotation is set up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var colorPicker: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 44), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(ChoreColor.allCases) { color in
                swatch(color)
            }
        }
    }

    private func swatch(_ color: ChoreColor) -> some View {
        let isSelected = color == chore.choreColor
        return Button {
            chore.colorToken = color.rawValue
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.fill)
                .frame(width: 44, height: 44)
                .overlay {
                    if isSelected {
                        // Selection shown by a ring AND a check, never colour alone.
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(SharedTokens.ink, lineWidth: 3)
                        Image(systemName: "checkmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(color.onColor)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Helpers

    private var displaySymbol: String {
        chore.sfSymbol.isEmpty ? "questionmark.square.dashed" : chore.sfSymbol
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func labelled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(title)
            content()
        }
    }

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { chore.dueDate != nil },
            set: { chore.dueDate = $0 ? (chore.dueDate ?? Calendar.current.startOfDay(for: .now)) : nil }
        )
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { chore.dueDate ?? Calendar.current.startOfDay(for: .now) },
            set: { chore.dueDate = $0 }
        )
    }
}

// MARK: Previews (default / AX5 / dark, per CLAUDE.md §8)

private func previewChores() -> [Chore] {
    [
        Chore(id: "make-bed", type: .fixed, defaultLabel: "Make the bed",
              sfSymbol: "bed.double.fill", category: "bedroom", note: nil,
              ticketValue: 4, colorToken: ChoreColor.red.rawValue),
        Chore(id: "dishwasher", type: .fixed, defaultLabel: "Empty the dishwasher",
              sfSymbol: "dishwasher.fill", category: "kitchen", note: nil,
              ticketValue: 2, colorToken: ChoreColor.blue.rawValue),
        Chore(id: "weekly", type: .rotationResolved, defaultLabel: "Weekly Chore",
              sfSymbol: "arrow.triangle.2.circlepath", category: nil, note: nil, ticketValue: 3),
    ]
}

#Preview("Chore cards") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(previewChores()) { ChoreDefinitionCard(chore: $0) }
        }
        .padding()
    }
}

#Preview("AX5") {
    ScrollView {
        ChoreDefinitionCard(chore: previewChores()[0])
            .padding()
    }
    .dynamicTypeSize(.accessibility5)
}

#Preview("Dark mode") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(previewChores()) { ChoreDefinitionCard(chore: $0) }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
