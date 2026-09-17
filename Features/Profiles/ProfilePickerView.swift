import FamilyCore
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// The app's entry point (CLAUDE.md §3.4/§4): compact, photo-based child buttons
/// to switch identity, over a family chore board. The board shows what's due
/// **today** — including anything **held over** from earlier this week that
/// hasn't been checked off — and the rest of the week by day. Any chore can be
/// checked off right here; completion + tickets go through the same
/// `ChoreCompletion` path as the weekly chart, so the two never disagree.
public struct ProfilePickerView: View {
    @Query(sort: \Child.name) private var children: [Child]
    @Query private var ticketEntries: [TicketLedgerEntry]
    @Query private var assignments: [ChoreAssignment]
    @Query private var chores: [Chore]
    @Query private var choreCards: [ChoreCard]
    @Query private var completions: [Completion]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("rotationEpochISO8601") private var rotationEpochISO8601 = ""
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    kidGrid
                    choreBoardView
                }
                .padding()
            }
            .navigationTitle("Family")
        }
    }

    // MARK: Kid buttons (compact)

    private var kidGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104, maximum: 150), spacing: 12)], spacing: 12) {
            ForEach(children) { child in
                NavigationLink {
                    WeeklyChartView(child: child)
                } label: {
                    ProfileCard(child: child, ticketBalance: balance(for: child))
                }
                .buttonStyle(.plain)
            }
            NavigationLink {
                FamilyRotationView()
            } label: {
                FamilyRotationCard()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Chore board

    @ViewBuilder private var choreBoardView: some View {
        let board = board
        if !board.today.isEmpty {
            boardSection("Today") {
                ForEach(board.today) { checkRow($0) }
            }
        }
        ForEach(board.upcoming) { group in
            boardSection(dayHeader(group.date)) {
                ForEach(group.chores) { checkRow($0) }
            }
        }
    }

    private func boardSection<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 2)
            content()
        }
    }

    private func checkRow(_ dash: DashChore) -> some View {
        ChoreCheckRow(dash: dash, childName: childName(dash.occurrence.childID)) {
            toggle(dash)
        }
    }

    // MARK: Board data

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var rotationEpoch: Date? { rotationEpochISO8601.isEmpty ? nil : ISO8601DateFormatter().date(from: rotationEpochISO8601) }
    private var rotationContract: RotationContract? { try? BundledContractSource().loadRotation() }

    private var weekInterval: DateInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: today)
        let weekdayIndex = calendar.component(.weekday, from: start) - 1 // 0 = Sunday
        let sunday = calendar.date(byAdding: .day, value: -weekdayIndex, to: start) ?? start
        let saturday = calendar.date(byAdding: .day, value: 6, to: sunday) ?? start
        return DateInterval(start: sunday, end: saturday)
    }

    private var board: ChoreBoard {
        let occurrences = ChoreCalendarProjector.occurrences(
            in: weekInterval,
            children: children.compactMap(\.childID),
            assignments: assignments,
            chores: chores,
            rotationEpoch: rotationEpoch,
            rotationContract: rotationContract
        ).map(withCardStyle)
        return WeeklyChoreBoard.build(occurrences: occurrences, doneKeys: doneKeys, today: today)
    }

    private var doneKeys: Set<String> {
        Set(completions.map { WeeklyChoreBoard.key(childID: $0.childID, choreID: $0.choreID, date: $0.date) })
    }

    private func withCardStyle(_ occ: ChoreOccurrence) -> ChoreOccurrence {
        guard let card = choreCards.first(where: { $0.childID == occ.childID.rawValue && $0.choreID == occ.choreID }) else { return occ }
        return ChoreOccurrence(
            id: occ.id, childID: occ.childID, choreID: occ.choreID, label: occ.label,
            sfSymbol: occ.sfSymbol, date: occ.date, isRotationResolved: occ.isRotationResolved,
            ticketValue: card.ticketValue, colorToken: card.colorToken
        )
    }

    private func toggle(_ dash: DashChore) {
        let occ = dash.occurrence
        let nowComplete = ChoreCompletion.toggle(
            childID: occ.childID.rawValue, choreID: occ.choreID, date: occ.date,
            ticketValue: occ.ticketValue, completions: completions,
            ticketEntries: ticketEntries, context: modelContext
        )
        if nowComplete { playFeedback() }
    }

    private func playFeedback() {
        #if os(iOS)
        if hapticsEnabled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        if soundEnabled { AudioServicesPlaySystemSound(SystemSoundID(1057)) }
        #endif
    }

    // MARK: Helpers

    private func balance(for child: Child) -> Int {
        ticketEntries.filter { $0.childID == child.id }.reduce(0) { $0 + $1.amount }
    }

    private func childName(_ id: ChildID) -> String {
        children.first { $0.childID == id }?.name ?? id.rawValue.capitalized
    }

    private func dayHeader(_ date: Date) -> String {
        Calendar.current.isDateInTomorrow(date) ? "Tomorrow" : Self.dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter
    }()
}

/// A compact child button: mascot on a light chip, name, ticket count, on a
/// semi-transparent tint of the child's identity colour.
private struct ProfileCard: View {
    let child: Child
    let ticketBalance: Int

    private var theme: ChildTheme { ChildTheme.theme(for: child.childID ?? .finley) }

    var body: some View {
        VStack(spacing: 6) {
            Image(child.primaryAvatar)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .padding(7)
                .background(Circle().fill(SharedTokens.paper).shadow(radius: 1))
                .accessibilityHidden(true)
            Text(child.name)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
            HStack(spacing: 3) {
                Image(systemName: "star.fill").font(.caption2).accessibilityHidden(true)
                Text("\(ticketBalance)").font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60, minHeight: 60)
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(theme.dotFill.opacity(0.20)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(theme.dotFill.opacity(0.45), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(child.name), \(ticketBalance) tickets")
        .accessibilityHint("Opens \(child.name)'s weekly chore chart")
    }
}

private struct FamilyRotationCard: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 30))
                .foregroundStyle(.primary)
                .frame(width: 50, height: 50)
                .padding(7)
                .accessibilityHidden(true)
            Text("Rotation")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
            Text(" ")
                .font(.caption)
                .accessibilityHidden(true)
        }
        .frame(minWidth: 60, minHeight: 60)
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.secondary.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.secondary.opacity(0.30), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Family Rotation")
        .accessibilityHint("Opens the shared family chore rotation")
    }
}

/// A checkable chore row on the family board: a checkbox, the mini card tile, the
/// child and label (with a "held over" flag), and the ticket value. The whole row
/// is the toggle, so the tap target is comfortably over the 60pt child minimum.
private struct ChoreCheckRow: View {
    let dash: DashChore
    let childName: String
    let onToggle: () -> Void

    private var occ: ChoreOccurrence { dash.occurrence }
    private var color: ChoreColor { occ.colorToken.flatMap(ChoreColor.init(rawValue:)) ?? .default(forID: occ.choreID) }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: dash.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(dash.isDone ? Color.green : Color.secondary)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.fill)
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: occ.sfSymbol).font(.footnote).foregroundStyle(color.onColor))
                    .opacity(dash.isDone ? 0.5 : 1)

                VStack(alignment: .leading, spacing: 1) {
                    Text(occ.label)
                        .font(.body)
                        .strikethrough(dash.isDone, color: .secondary)
                        .opacity(dash.isDone ? 0.55 : 1)
                    HStack(spacing: 6) {
                        Text(childName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if dash.isHeldOver {
                            Label("held over", systemImage: "clock.arrow.circlepath")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2)
                    Text("\(occ.ticketValue)").font(.subheadline).fontWeight(.semibold)
                }
                .foregroundStyle(.secondary)
                .opacity(dash.isDone ? 0.5 : 1)
            }
            .padding(.vertical, 8)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(occ.label) for \(childName), \(occ.ticketValue) ticket\(occ.ticketValue == 1 ? "" : "s")\(dash.isHeldOver ? ", held over" : "")")
        .accessibilityValue(dash.isDone ? "Done" : "Not done")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Marks the chore \(dash.isDone ? "not done" : "done")")
    }
}
