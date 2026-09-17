import FamilyCore
import SwiftUI

/// One chore in the weekly chart, tappable to toggle complete. It now carries
/// the per-kid card's identity directly: a mini coloured tile (the chore's
/// colour + icon, a small echo of the card) and the ticket value it earns.
/// Completion still changes three things at once per CLAUDE.md §7.3 — the text
/// fades, the hand-drawn mark draws on, and the row's background responds — so
/// colour is never the sole signal.
struct ChoreRow: View {
    let chore: ResolvedChore
    let isComplete: Bool
    let childTheme: ChildTheme
    let onToggle: () -> Void

    private var choreColor: ChoreColor {
        chore.colorToken.flatMap(ChoreColor.init(rawValue:)) ?? .default(forID: chore.id)
    }

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .leading) {
                HStack(spacing: 10) {
                    choreTile
                        .opacity(isComplete ? 0.45 : 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chore.label)
                            .font(.system(.body, design: .default))
                            // Fixed ink, never `.primary`: the card is always
                            // white, so `.primary` would be invisible in the dark.
                            .foregroundStyle(SharedTokens.ink)
                            .opacity(isComplete ? 0.45 : 1)
                        if chore.isRotationResolved {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(childTheme.dotFill)
                                    .frame(width: 8, height: 8)
                                Text("Family rotation")
                                    .font(.caption)
                                    .foregroundStyle(childTheme.textInk)
                            }
                        }
                    }
                    Spacer()
                    ticketBadge
                        .opacity(isComplete ? 0.45 : 1)
                }
                // Clear of the completion-mark zone on the right.
                .padding(.trailing, 64)

                HStack {
                    Spacer()
                    CompletionMark(isComplete: isComplete)
                        .frame(width: 60, height: 52)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .frame(minHeight: 60)
        .background(isComplete ? Color.green.opacity(0.12) : Color.clear)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isComplete ? .green.opacity(0.4) : .clear, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isComplete ? "Completed" : "Not completed")
        .accessibilityAddTraits(.isButton)
    }

    /// A miniature of the chore's card tile: the icon on its colour. `onColor`
    /// keeps the icon legible on every palette colour (unlike tinting a bare
    /// glyph, which would fail on the pale yellow against white paper).
    private var choreTile: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(choreColor.fill)
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: chore.sfSymbol)
                    .font(.callout)
                    .foregroundStyle(choreColor.onColor)
            )
            .accessibilityHidden(true)
    }

    private var ticketBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text("\(chore.ticketValue)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        // Fixed muted ink: always legible on the white paper card, regardless of
        // the chore's colour (which the tile already carries).
        .foregroundStyle(SharedTokens.inkSecondary)
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        let tickets = "\(chore.ticketValue) ticket\(chore.ticketValue == 1 ? "" : "s")"
        return "\(chore.label), \(tickets)"
    }
}

#Preview {
    VStack {
        ChoreRow(chore: ResolvedChore(id: "1", label: "Empty Dishwasher", sfSymbol: "dishwasher.fill", isRotationResolved: false, ticketValue: 3, colorToken: ChoreColor.blue.rawValue), isComplete: false, childTheme: .finley, onToggle: {})
        ChoreRow(chore: ResolvedChore(id: "2", label: "Wipe down sinks + Vacuum Living Room", sfSymbol: "sink.fill", isRotationResolved: true, ticketValue: 2, colorToken: ChoreColor.green.rawValue), isComplete: true, childTheme: .arthur, onToggle: {})
    }
    .padding()
    .background(SharedTokens.paper)
}

#Preview("AX5", traits: .sizeThatFitsLayout) {
    ChoreRow(chore: ResolvedChore(id: "1", label: "Empty Dishwasher", sfSymbol: "dishwasher.fill", isRotationResolved: false, ticketValue: 3, colorToken: ChoreColor.red.rawValue), isComplete: false, childTheme: .finley, onToggle: {})
        .dynamicTypeSize(.accessibility5)
        .padding()
        .background(SharedTokens.paper)
}

#Preview("Dark mode") {
    ChoreRow(chore: ResolvedChore(id: "1", label: "Empty Dishwasher", sfSymbol: "dishwasher.fill", isRotationResolved: false, ticketValue: 4, colorToken: ChoreColor.yellow.rawValue), isComplete: true, childTheme: .maryn, onToggle: {})
        .padding()
        .background(SharedTokens.paper)
        .preferredColorScheme(.dark)
}
