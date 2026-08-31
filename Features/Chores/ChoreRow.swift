import FamilyCore
import SwiftUI

/// One chore, tappable to toggle complete. Completion changes three things at
/// once per CLAUDE.md §7.3: the text opacity fades (~45%), the completion
/// mark draws on, and the card's own background/border responds — the mark is
/// never the sole signal. The rotation-resolved chore also gets a colored dot
/// + "rotation" text label (never color alone) per §7.1.
struct ChoreRow: View {
    let chore: ResolvedChore
    let isComplete: Bool
    let childTheme: ChildTheme
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .leading) {
                HStack(spacing: 8) {
                    Image(systemName: chore.sfSymbol)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chore.label)
                            .font(.system(.body, design: .default))
                            .foregroundStyle(isComplete ? .secondary : .primary)
                            .opacity(isComplete ? 0.45 : 1)
                        if chore.isRotationResolved {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(childTheme.dotFill)
                                    .frame(width: 8, height: 8)
                                Text("Family rotation")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.trailing, 44)

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

    private var accessibilityLabel: String {
        "Mark \(chore.label) complete"
    }
}

#Preview {
    VStack {
        ChoreRow(chore: ResolvedChore(id: "1", label: "Empty Dishwasher", sfSymbol: "dishwasher", isRotationResolved: false), isComplete: false, childTheme: .finley, onToggle: {})
        ChoreRow(chore: ResolvedChore(id: "2", label: "Collect Trash & Take Out", sfSymbol: "trash", isRotationResolved: true), isComplete: true, childTheme: .arthur, onToggle: {})
    }
    .padding()
}

#Preview("AX5", traits: .sizeThatFitsLayout) {
    ChoreRow(chore: ResolvedChore(id: "1", label: "Empty Dishwasher", sfSymbol: "dishwasher", isRotationResolved: false), isComplete: false, childTheme: .finley, onToggle: {})
        .dynamicTypeSize(.accessibility5)
        .padding()
}

#Preview("Dark mode") {
    ChoreRow(chore: ResolvedChore(id: "1", label: "Empty Dishwasher", sfSymbol: "dishwasher", isRotationResolved: false), isComplete: true, childTheme: .maryn, onToggle: {})
        .padding()
        .preferredColorScheme(.dark)
}
