import FamilyCore
import SwiftUI

/// One child's day card, styled per their `cardFrame` from family.json.
/// The frame shape is part of the specification (CLAUDE.md §7.1) — not
/// decoration to be swapped for a generic card.
struct DayCardFrame: View {
    let child: Child
    let weekday: Weekday
    let chores: [ResolvedChore]
    let completedChoreIDs: Set<String>
    let onToggle: (ResolvedChore) -> Void

    private var theme: ChildTheme {
        ChildTheme.theme(for: child.childID ?? .finley)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(weekday.shortLabel)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Group {
                switch child.cardFrame {
                case "open-book":
                    OpenBookFrame(child: child, theme: theme, chores: chores, completedChoreIDs: completedChoreIDs, onToggle: onToggle)
                case "bamboo-fence":
                    BambooFenceFrame(child: child, theme: theme, chores: chores, completedChoreIDs: completedChoreIDs, onToggle: onToggle)
                case "held-sign":
                    HeldSignFrame(child: child, theme: theme, chores: chores, completedChoreIDs: completedChoreIDs, onToggle: onToggle)
                default:
                    PlainFrame(theme: theme, chores: chores, completedChoreIDs: completedChoreIDs, onToggle: onToggle)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct OpenBookFrame: View {
    let child: Child
    let theme: ChildTheme
    let chores: [ResolvedChore]
    let completedChoreIDs: Set<String>
    let onToggle: (ResolvedChore) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                // Two facing pages — one chore per page, per CLAUDE.md §7.1.
                pageView(chore: chores.first)
                pageView(chore: chores.count > 1 ? chores[1] : nil)
            }
            .background(RoundedRectangle(cornerRadius: 16).fill(SharedTokens.paper).shadow(radius: 1))

            // A third chore turns a page below the spread rather than adding a
            // third page — the metaphor caps at two.
            if chores.count > 2 {
                ForEach(chores[2...]) { chore in
                    ChoreRow(chore: chore, isComplete: completedChoreIDs.contains(chore.id), childTheme: theme, onToggle: { onToggle(chore) })
                }
            }
        }
    }

    @ViewBuilder
    private func pageView(chore: ResolvedChore?) -> some View {
        VStack {
            if let chore {
                ChoreRow(chore: chore, isComplete: completedChoreIDs.contains(chore.id), childTheme: theme, onToggle: { onToggle(chore) })
            } else {
                Spacer(minLength: 60)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)
    }
}

private struct BambooFenceFrame: View {
    let child: Child
    let theme: ChildTheme
    let chores: [ResolvedChore]
    let completedChoreIDs: Set<String>
    let onToggle: (ResolvedChore) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                Image(child.primaryAvatar)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            }
            // Chores on the horizontal "rail".
            Rectangle()
                .fill(theme.dotFill.opacity(0.4))
                .frame(height: 3)
            VStack(spacing: 4) {
                ForEach(chores) { chore in
                    ChoreRow(chore: chore, isComplete: completedChoreIDs.contains(chore.id), childTheme: theme, onToggle: { onToggle(chore) })
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(SharedTokens.paper).shadow(radius: 1))
    }
}

private struct HeldSignFrame: View {
    let child: Child
    let theme: ChildTheme
    let chores: [ResolvedChore]
    let completedChoreIDs: Set<String>
    let onToggle: (ResolvedChore) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: 4) {
                ForEach(chores) { chore in
                    ChoreRow(chore: chore, isComplete: completedChoreIDs.contains(chore.id), childTheme: theme, onToggle: { onToggle(chore) })
                }
            }
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.dotFill.opacity(0.5), lineWidth: 3))

            HStack {
                Image(child.primaryAvatar)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Spacer()
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(SharedTokens.paper).shadow(radius: 1))
    }
}

private struct PlainFrame: View {
    let theme: ChildTheme
    let chores: [ResolvedChore]
    let completedChoreIDs: Set<String>
    let onToggle: (ResolvedChore) -> Void

    var body: some View {
        VStack(spacing: 4) {
            ForEach(chores) { chore in
                ChoreRow(chore: chore, isComplete: completedChoreIDs.contains(chore.id), childTheme: theme, onToggle: { onToggle(chore) })
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(SharedTokens.paper).shadow(radius: 1))
    }
}
