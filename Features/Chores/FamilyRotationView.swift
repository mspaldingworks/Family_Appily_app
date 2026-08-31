import FamilyCore
import SwiftUI

/// "Family Chore Chart" — 6 shared chores × a week selector, computed from the
/// rotation formula rather than a stored 7-column grid, per rotation.json's
/// keyFinding. Legend uses the sibling dot colors from the printed chart.
public struct FamilyRotationView: View {
    @AppStorage("rotationEpochISO8601") private var rotationEpochISO8601: String = ""
    @State private var selectedWeekOffset = 0
    private let engine = RotationEngine()

    public init() {}

    private var rotationEpoch: Date? {
        guard !rotationEpochISO8601.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: rotationEpochISO8601)
    }

    private var rotationContract: RotationContract? {
        try? BundledContractSource().loadRotation()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                legend

                if let rotationEpoch, let rotationContract {
                    weekPicker
                    let weekIndex = engine.weekIndex(epoch: rotationEpoch, on: .now) + selectedWeekOffset
                    VStack(spacing: 8) {
                        ForEach(rotationContract.chores, id: \.id) { chore in
                            rotationRow(chore: chore, weekIndex: weekIndex)
                        }
                    }
                } else {
                    Text("Set up the rotation start date from any child's weekly chart first.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Family Rotation")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(ChildID.allCases, id: \.self) { childID in
                HStack(spacing: 6) {
                    Circle().fill(ChildTheme.theme(for: childID).dotFill).frame(width: 14, height: 14)
                    Text(childID.rawValue.capitalized)
                        .font(.caption)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var weekPicker: some View {
        HStack {
            Button {
                selectedWeekOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Previous week")

            Spacer()
            Text(selectedWeekOffset == 0 ? "This week" : (selectedWeekOffset > 0 ? "\(selectedWeekOffset) week(s) ahead" : "\(-selectedWeekOffset) week(s) ago"))
                .font(.headline)
            Spacer()

            Button {
                selectedWeekOffset += 1
            } label: {
                Image(systemName: "chevron.right")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Next week")
        }
    }

    private func rotationRow(chore: RotationContract.RotationChoreContract, weekIndex: Int) -> some View {
        let childID = engine.assignee(offset: chore.offset, weekIndex: weekIndex)
        let theme = ChildTheme.theme(for: childID)
        return HStack {
            Image(systemName: chore.sfSymbol)
                .accessibilityHidden(true)
            Text(chore.label)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(theme.dotFill).frame(width: 12, height: 12)
                Text(childID.rawValue.capitalized)
                    .foregroundStyle(theme.textInk)
                    .fontWeight(.semibold)
            }
        }
        .padding(12)
        .frame(minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(SharedTokens.paper).shadow(radius: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(chore.label), assigned to \(childID.rawValue.capitalized)")
    }
}

#Preview {
    NavigationStack { FamilyRotationView() }
}

#Preview("Dark mode") {
    NavigationStack { FamilyRotationView() }
        .preferredColorScheme(.dark)
}
