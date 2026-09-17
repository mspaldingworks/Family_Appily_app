import FamilyCore
import SwiftData
import SwiftUI

/// Adult editing of chores (CLAUDE.md §4). Each chore is assigned to one or more
/// kids, and every (kid, chore) pair is its own colourful card with independent
/// icon, colour, ticket value, and schedule — recurring on chosen weekdays, or a
/// single due date. Editing a card derives the recurring `ChoreAssignment` rows
/// that the chart, calendar overlay, and write-through read, so the rest of the
/// app keeps working unchanged. Rotation "Weekly Chore" slots are system-managed
/// and don't appear here.
struct ChoreSettingsView: View {
    @Query private var cards: [ChoreCard]
    @Query private var assignments: [ChoreAssignment]
    @Query(sort: \Chore.defaultLabel) private var chores: [Chore]
    @Query(sort: \Child.name) private var children: [Child]
    @Environment(\.modelContext) private var modelContext

    private var baseChores: [Chore] { chores.filter { $0.choreType != .rotationResolved } }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(baseChores) { base in
                    ChoreGroupView(
                        base: base,
                        children: children,
                        cards: cards.filter { $0.choreID == base.id },
                        isAssigned: { child in cardExists(base, child) },
                        onToggleChild: { child, on in setAssigned(base, child, on) },
                        onEditCard: reconcile
                    )
                }
                Button { addChore() } label: {
                    Label("Add a chore", systemImage: "plus.circle.fill").font(.headline)
                }
                .frame(minHeight: 44)
                .padding(.top, 4)
            }
            .padding(16)
        }
        .navigationTitle("Chores")
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #endif
    }

    // MARK: Assignment / cards

    private func cardExists(_ base: Chore, _ child: Child) -> Bool {
        cards.contains { $0.id == ChoreCard.id(childID: child.id, choreID: base.id) }
    }

    private func setAssigned(_ base: Chore, _ child: Child, _ assigned: Bool) {
        let cardID = ChoreCard.id(childID: child.id, choreID: base.id)
        if assigned {
            guard !cards.contains(where: { $0.id == cardID }) else { return }
            modelContext.insert(ChoreCard(
                id: cardID, childID: child.id, choreID: base.id,
                label: base.defaultLabel, sfSymbol: base.sfSymbol,
                colorToken: base.colorToken, ticketValue: base.ticketValue,
                scheduleIsRecurring: true, weekdaysMask: 0, dueDate: nil
            ))
            try? modelContext.save()
        } else {
            for assignment in assignments where assignment.childID == child.id && assignment.choreID == base.id {
                modelContext.delete(assignment)
            }
            if let card = cards.first(where: { $0.id == cardID }) { modelContext.delete(card) }
            try? modelContext.save()
        }
    }

    private func addChore() {
        let id = "chore-\(UUID().uuidString.prefix(8).lowercased())"
        modelContext.insert(Chore(
            id: id, type: .fixed, defaultLabel: "New chore",
            sfSymbol: "star.fill", category: nil, note: nil, ticketValue: 1
        ))
        try? modelContext.save()
    }

    /// Derives the recurring `ChoreAssignment` rows for a card from its schedule,
    /// stamping this kid's icon and ticket value onto them. A due-date card keeps
    /// no recurring rows (it shows on the calendar on its date instead).
    private func reconcile(_ card: ChoreCard) {
        let desired: Set<Int> = card.scheduleIsRecurring ? Set(card.weekdays.map(\.rawValue)) : []
        let existing = assignments.filter { $0.childID == card.childID && $0.choreID == card.choreID }
        let existingByWeekday = Dictionary(existing.map { ($0.weekday, $0) }, uniquingKeysWith: { first, _ in first })

        for assignment in existing where !desired.contains(assignment.weekday) {
            modelContext.delete(assignment)
        }
        for weekdayRaw in desired {
            if let assignment = existingByWeekday[weekdayRaw] {
                assignment.sfSymbolOverride = card.sfSymbol
                assignment.ticketValueOverride = card.ticketValue
            } else if let weekday = Weekday(rawValue: weekdayRaw) {
                modelContext.insert(ChoreAssignment(
                    childID: card.childID, choreID: card.choreID, weekday: weekday,
                    displayLabelOverride: nil, sfSymbolOverride: card.sfSymbol,
                    ticketValueOverride: card.ticketValue
                ))
            }
        }
        try? modelContext.save()
    }
}

/// One base chore: a rename field, a kid multi-select (each kid toggled on gets
/// their own card), and the per-kid cards beneath.
private struct ChoreGroupView: View {
    @Bindable var base: Chore
    let children: [Child]
    let cards: [ChoreCard]
    let isAssigned: (Child) -> Bool
    let onToggleChild: (Child, Bool) -> Void
    let onEditCard: (ChoreCard) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Chore name", text: $base.defaultLabel)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Assigned to").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(children) { child in kidChip(child) }
                }
            }

            ForEach(cards.sorted { $0.childID < $1.childID }) { card in
                ChoreDefinitionCard(card: card, childName: childName(card.childID)) {
                    onEditCard(card)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.secondary.opacity(0.07)))
    }

    private func kidChip(_ child: Child) -> some View {
        let on = isAssigned(child)
        let theme = ChildTheme.theme(for: child.childID ?? .finley)
        return Button {
            onToggleChild(child, !on)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: on ? "checkmark.circle.fill" : "plus.circle")
                Text(child.name)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(on ? theme.dotFill.opacity(0.18) : Color.secondary.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? theme.dotFill : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(on ? "Assigned to" : "Assign to") \(child.name)")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    private func childName(_ id: String) -> String {
        children.first { $0.id == id }?.name ?? id.capitalized
    }
}

/// One per-kid card: coloured tile preview plus editable icon, colour, tickets,
/// and schedule. Edits mutate the `ChoreCard` (autosaved) and call `onEdit` so
/// the parent re-derives the kid's assignment rows.
struct ChoreDefinitionCard: View {
    @Bindable var card: ChoreCard
    let childName: String
    let onEdit: () -> Void

    private var choreColor: ChoreColor {
        card.colorToken.flatMap(ChoreColor.init(rawValue:)) ?? .default(forID: card.id)
    }
    private var displaySymbol: String {
        card.sfSymbol.isEmpty ? "questionmark.square.dashed" : card.sfSymbol
    }
    private var theme: ChildTheme { ChildTheme.theme(for: ChildID(rawValue: card.childID) ?? .finley) }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) { previewTile; fields }
            VStack(alignment: .leading, spacing: 16) { previewTile; fields }
        }
        .padding(16)
        // Card background is locked to the CHILD's identity colour; only the tile
        // (icon + tickets) uses the per-chore colour the parent picks.
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(theme.dotFill.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(theme.dotFill.opacity(0.32), lineWidth: 1))
        .onChange(of: card.sfSymbol) { _, _ in onEdit() }
        .onChange(of: card.ticketValue) { _, _ in onEdit() }
        .onChange(of: card.weekdaysMask) { _, _ in onEdit() }
        .onChange(of: card.scheduleIsRecurring) { _, isRecurring in
            if !isRecurring, card.dueDate == nil { card.dueDate = Calendar.current.startOfDay(for: .now) }
            onEdit()
        }
    }

    private var previewTile: some View {
        let color = choreColor
        return VStack(spacing: 8) {
            Image(systemName: displaySymbol)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(color.onColor)
            Text("\(card.ticketValue)")
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
        .accessibilityHidden(true)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle().fill(theme.dotFill).frame(width: 14, height: 14)
                Text(childName).font(.headline)
            }

            labelled("Icon") {
                ChoreIconPicker(selection: $card.sfSymbol, tint: choreColor.fill)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    fieldLabel("Color")
                    Spacer()
                    Text(choreColor.displayName).font(.caption).foregroundStyle(.secondary)
                }
                colorPicker
            }

            Stepper(value: $card.ticketValue, in: 1...20) {
                Label("Tickets: \(card.ticketValue)", systemImage: "star.fill").labelStyle(.titleAndIcon)
            }

            labelled("Schedule") {
                Picker("Schedule", selection: $card.scheduleIsRecurring) {
                    Text("Recurring").tag(true)
                    Text("Due date").tag(false)
                }
                .pickerStyle(.segmented)
            }

            if card.scheduleIsRecurring {
                weekdayToggles
            } else {
                DatePicker("Due date", selection: dueDateBinding, displayedComponents: .date)
                    #if os(iOS)
                    .datePickerStyle(.compact)
                    #endif
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekdayToggles: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(Weekday.allCases, id: \.self) { weekday in
                let on = card.isOn(weekday)
                Button {
                    card.setWeekday(weekday, on: !on)
                } label: {
                    Text(String(weekday.shortLabel.prefix(1)))
                        .font(.caption.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(on ? choreColor.fill.opacity(0.25) : Color.secondary.opacity(0.12)))
                        .overlay(Circle().strokeBorder(on ? choreColor.fill : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekday.shortLabel)
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private var colorPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(ChoreColor.allCases) { color in swatch(color) }
        }
    }

    private func swatch(_ color: ChoreColor) -> some View {
        let isSelected = color == choreColor
        return Button {
            card.colorToken = color.rawValue
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color.fill)
                .frame(width: 44, height: 44)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(SharedTokens.ink, lineWidth: 3)
                        Image(systemName: "checkmark").font(.subheadline.bold()).foregroundStyle(color.onColor)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.displayName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func labelled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(title)
            content()
        }
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { card.dueDate ?? Calendar.current.startOfDay(for: .now) },
            set: { card.dueDate = $0 }
        )
    }
}

/// A horizontal, scrollable icon chooser — the adult scrolls through chore icons
/// and taps one, rather than typing an SF Symbol name. Current pick shown by a
/// checkmark badge, a ring, and the tile preview; scrolls to it on appear.
private struct ChoreIconPicker: View {
    @Binding var selection: String
    let tint: Color

    private var icons: [ChoreIconCatalog.Icon] {
        var list = ChoreIconCatalog.all
        if !selection.isEmpty, !list.contains(where: { $0.symbol == selection }) {
            list.insert(ChoreIconCatalog.Icon(symbol: selection, label: ChoreIconCatalog.label(for: selection)), at: 0)
        }
        return list
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(icons) { icon in iconButton(icon).id(icon.symbol) }
                }
                .padding(.vertical, 2)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
        .accessibilityLabel("Chore icon")
    }

    private func iconButton(_ icon: ChoreIconCatalog.Icon) -> some View {
        let isSelected = icon.symbol == selection
        return Button {
            selection = icon.symbol
        } label: {
            Image(systemName: icon.symbol)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(isSelected ? tint.opacity(0.22) : Color.secondary.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(isSelected ? tint : .clear, lineWidth: 2))
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(tint)
                            .background(Circle().fill(.background))
                            .padding(2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: Previews (default / AX5 / dark, per CLAUDE.md §8)

@MainActor private func previewContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: Chore.self, Child.self, ChoreAssignment.self, ChoreCard.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    ctx.insert(Child(id: "finley", name: "Finley", motif: "pizza", cardFrame: "book", primaryAvatar: "finley", alternateAvatar: nil, topCornerMotif: "cap", bottomCornerMotif: "hoodie", titleColorToken: "green"))
    ctx.insert(Child(id: "maryn", name: "Maryn", motif: "penguin", cardFrame: "sign", primaryAvatar: "maryn", alternateAvatar: nil, topCornerMotif: "flower", bottomCornerMotif: "ice", titleColorToken: "red"))
    ctx.insert(Chore(id: "make-bed", type: .fixed, defaultLabel: "Make the bed", sfSymbol: "bed.double.fill", category: nil, note: nil, ticketValue: 4))
    ctx.insert(Chore(id: "dishes", type: .fixed, defaultLabel: "Empty the dishwasher", sfSymbol: "dishwasher.fill", category: nil, note: nil, ticketValue: 2))
    ctx.insert(ChoreCard(id: "finley|make-bed", childID: "finley", choreID: "make-bed", label: "Make the bed", sfSymbol: "bed.double.fill", colorToken: ChoreColor.red.rawValue, ticketValue: 4, scheduleIsRecurring: true, weekdaysMask: 0b0111110))
    ctx.insert(ChoreCard(id: "maryn|make-bed", childID: "maryn", choreID: "make-bed", label: "Make the bed", sfSymbol: "sofa.fill", colorToken: ChoreColor.blue.rawValue, ticketValue: 2, scheduleIsRecurring: false, dueDate: .now))
    return container
}

#Preview("Chores") {
    NavigationStack { ChoreSettingsView() }.modelContainer(previewContainer())
}

#Preview("AX5") {
    NavigationStack { ChoreSettingsView() }.modelContainer(previewContainer()).dynamicTypeSize(.accessibility5)
}

#Preview("Dark mode") {
    NavigationStack { ChoreSettingsView() }.modelContainer(previewContainer()).preferredColorScheme(.dark)
}
