import FamilyCore
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// Seven day cards, four in the top row and three in the bottom, week
/// beginning Sunday — preserved on iPad/Mac, collapsing to a vertical list
/// only on iPhone and at accessibility Dynamic Type sizes, per CLAUDE.md §7.2.
public struct WeeklyChartView: View {
    let child: Child

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Query private var assignments: [ChoreAssignment]
    @Query private var chores: [Chore]
    @Query private var completions: [Completion]
    @Query private var rotationChores: [RotationChore]
    @Query private var ticketEntries: [TicketLedgerEntry]
    @Query private var choreCards: [ChoreCard]

    @Environment(\.modelContext) private var modelContext

    private var ticketBalance: Int { TicketService.balance(for: child.id, in: ticketEntries) }

    @AppStorage("rotationEpochISO8601") private var rotationEpochISO8601: String = ""
    @AppStorage("weeklyChoreTicketValue") private var weeklyChoreTicketValue = 5
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = false
    @State private var showingRotationSetup = false

    public init(child: Child) {
        self.child = child
    }

    private var rotationEpoch: Date? {
        guard !rotationEpochISO8601.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: rotationEpochISO8601)
    }

    private var rotationContract: RotationContract? {
        try? BundledContractSource().loadRotation()
    }

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var completedIDsToday: Set<String> {
        let childIDRaw = child.id
        return Set(completions.filter { $0.childID == childIDRaw && Calendar.current.isDate($0.date, inSameDayAs: today) }.map(\.choreID))
    }

    private var useVerticalList: Bool {
        horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize
    }

    public var body: some View {
        ScrollView {
            if rotationEpoch == nil {
                RotationSetupPrompt(onSet: setRotationEpoch)
                    .padding(.bottom)
            }

            if useVerticalList {
                VStack(spacing: 16) {
                    ForEach(Weekday.allCases, id: \.self) { weekday in
                        dayCard(for: weekday)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Weekday.allCases.prefix(4), id: \.self) { weekday in
                            dayCard(for: weekday)
                        }
                    }
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Weekday.allCases.suffix(3), id: \.self) { weekday in
                            dayCard(for: weekday)
                        }
                    }
                }
            }
        }
        .padding()
        .navigationTitle(child.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    RewardsView(child: child)
                } label: {
                    Label("\(ticketBalance) tickets", systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                }
                .accessibilityLabel("\(child.name) has \(ticketBalance) tickets. Open reward chart.")
            }
        }
    }

    @ViewBuilder
    private func dayCard(for weekday: Weekday) -> some View {
        if let rotationContract, let childID = child.childID {
            let resolved = ChoreResolver.chores(
                for: childID, weekday: weekday, assignments: assignments, chores: chores,
                rotationEpoch: rotationEpoch, rotationContract: rotationContract,
                weeklyTicketValue: weeklyChoreTicketValue
            ).map(withCardColor)
            DayCardFrame(child: child, weekday: weekday, chores: resolved, completedChoreIDs: completedIDsToday) { chore in
                toggle(chore: chore)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Attaches the per-kid card's colour to a resolved chore so the chart tile
    /// matches the card. Rotation slots (which have no card) keep nil and fall
    /// back to a default colour in `ChoreRow`.
    private func withCardColor(_ chore: ResolvedChore) -> ResolvedChore {
        let token = choreCards.first { $0.childID == child.id && $0.choreID == chore.id }?.colorToken
        return ResolvedChore(
            id: chore.id, label: chore.label, sfSymbol: chore.sfSymbol,
            isRotationResolved: chore.isRotationResolved, ticketValue: chore.ticketValue, colorToken: token
        )
    }

    private func toggle(chore: ResolvedChore) {
        let nowComplete = ChoreCompletion.toggle(
            childID: child.id, choreID: chore.id, date: today,
            ticketValue: chore.ticketValue, completions: completions,
            ticketEntries: ticketEntries, context: modelContext
        )
        if nowComplete { playCompletionFeedback() }
    }

    /// Haptic + optional sound on completion, per §3.7 — each independently
    /// mutable in the Parents settings. iOS-only; a no-op elsewhere.
    private func playCompletionFeedback() {
        #if os(iOS)
        if hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if soundEnabled {
            AudioServicesPlaySystemSound(SystemSoundID(1057))
        }
        #endif
    }

    private func setRotationEpoch(_ date: Date) {
        rotationEpochISO8601 = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
    }
}

private struct RotationSetupPrompt: View {
    let onSet: (Date) -> Void
    @State private var selectedDate = Date.now

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One-time setup")
                .font(.headline)
            Text("Which Sunday did Week 1 of the family rotation begin? This fills in the \"Weekly Chore\" slots automatically from then on.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            DatePicker("Week 1 start", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
            Button("Save") { onSet(selectedDate) }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: 44)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.yellow.opacity(0.15)))
    }
}
