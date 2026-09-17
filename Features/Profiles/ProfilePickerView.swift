import FamilyCore
import SwiftData
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif

/// The app's entry point (CLAUDE.md §3.4/§4). A full-width Rotation button, then
/// one row per child: a horizontally-scrollable strip of their chore tiles beside
/// their avatar (tap the avatar to open their chart), the whole row tinted in
/// their identity colour. "Today" carries anything held over from earlier this
/// week — those tiles get a red glow — and "This week" lists the chores coming
/// up. Tapping a tile checks it off; completion + tickets run through the shared
/// `ChoreCompletion` path, so this and the weekly chart never disagree.
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
                let occurrences = weekOccurrences
                let rotation = occurrences.filter { $0.isRotationResolved }
                let board = WeeklyChoreBoard.build(
                    occurrences: occurrences.filter { !$0.isRotationResolved },
                    doneKeys: doneKeys, today: today
                )
                VStack(alignment: .leading, spacing: 22) {
                    rotationButton

                    section("Today") {
                        ForEach(children) { child in
                            kidRow(child, chores: todayChores(child, from: board), weekly: weeklyChore(child, from: rotation))
                        }
                    }

                    let hasUpcoming = children.contains { !weekChores($0, from: board).isEmpty }
                    if hasUpcoming {
                        section("This week") {
                            ForEach(children) { child in
                                let week = weekChores(child, from: board)
                                if !week.isEmpty { kidRow(child, chores: week, weekly: nil) }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Family")
        }
    }

    // MARK: Sections

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
            content()
        }
    }

    private var rotationButton: some View {
        NavigationLink {
            FamilyRotationView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3.weight(.semibold))
                Text("Rotation")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.15)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Family Rotation")
        .accessibilityHint("Opens the shared family chore rotation")
    }

    // MARK: One kid's row

    private func kidRow(_ child: Child, chores dashes: [DashChore], weekly: DashChore?) -> some View {
        let theme = ChildTheme.theme(for: child.childID ?? .finley)
        return VStack(spacing: 10) {
            // The weekly (rotation) chore is anchored to the top of the card,
            // with a white glow, and stays until it's checked off.
            if let weekly {
                WeeklyChoreButton(dash: weekly, childName: child.name) { toggle(weekly) }
            }

            HStack(spacing: 12) {
                Group {
                    if dashes.isEmpty {
                        HStack {
                            Spacer()
                            Label("All done", systemImage: "checkmark.seal.fill")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(dashes) { dash in
                                    ChoreTile(dash: dash, childName: child.name) { toggle(dash) }
                                }
                            }
                            .padding(8) // room for the red glow, and breathing space
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 96)

                kidBadge(child)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(theme.dotFill.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(theme.dotFill.opacity(0.4), lineWidth: 1))
    }

    private func kidBadge(_ child: Child) -> some View {
        NavigationLink {
            WeeklyChartView(child: child)
        } label: {
            VStack(spacing: 4) {
                Image(child.primaryAvatar)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .padding(6)
                    .background(Circle().fill(SharedTokens.paper).shadow(radius: 1))
                    .accessibilityHidden(true)
                Text(child.name)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2)
                    Text("\(balance(for: child))").font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .frame(width: 82)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(child.name), \(balance(for: child)) tickets")
        .accessibilityHint("Opens \(child.name)'s weekly chore chart")
    }

    // MARK: Board data (computed once per render, passed down)

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

    private var weekOccurrences: [ChoreOccurrence] {
        ChoreCalendarProjector.occurrences(
            in: weekInterval,
            children: children.compactMap(\.childID),
            assignments: assignments,
            chores: chores,
            rotationEpoch: rotationEpoch,
            rotationContract: rotationContract
        ).map(withCardStyle)
    }

    /// The child's weekly (rotation) chore for the week, if any — deduped to the
    /// earliest slot. Nil when the rotation isn't set up. Never "held over": a
    /// weekly chore can be done anytime this week.
    private func weeklyChore(_ child: Child, from rotation: [ChoreOccurrence]) -> DashChore? {
        guard rotationEpoch != nil, let cid = child.childID,
              let first = rotation.filter({ $0.childID == cid }).min(by: { $0.date < $1.date }) else { return nil }
        let done = doneKeys.contains(WeeklyChoreBoard.key(childID: cid.rawValue, choreID: first.choreID, date: first.date))
        return DashChore(occurrence: first, isDone: done, isHeldOver: false)
    }

    private var doneKeys: Set<String> {
        Set(completions.map { WeeklyChoreBoard.key(childID: $0.childID, choreID: $0.choreID, date: $0.date) })
    }

    private func todayChores(_ child: Child, from board: ChoreBoard) -> [DashChore] {
        guard let cid = child.childID else { return [] }
        return board.today.filter { $0.occurrence.childID == cid }
    }

    /// Upcoming chores this week for one child, each distinct chore once.
    private func weekChores(_ child: Child, from board: ChoreBoard) -> [DashChore] {
        guard let cid = child.childID else { return [] }
        var seen = Set<String>()
        return board.upcoming
            .flatMap(\.chores)
            .filter { $0.occurrence.childID == cid }
            .filter { seen.insert($0.occurrence.choreID).inserted }
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

    private func balance(for child: Child) -> Int {
        ticketEntries.filter { $0.childID == child.id }.reduce(0) { $0 + $1.amount }
    }
}

/// A single chore tile: the chore's colour + icon + ticket value, in the card
/// style. Tap to check off (a green tick appears and it dims). A chore held over
/// from an earlier day gets a red glowing border to flag it as overdue.
private struct ChoreTile: View {
    let dash: DashChore
    let childName: String
    let onToggle: () -> Void

    private var occ: ChoreOccurrence { dash.occurrence }
    private var color: ChoreColor { occ.colorToken.flatMap(ChoreColor.init(rawValue:)) ?? .default(forID: occ.choreID) }

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 2) {
                Image(systemName: occ.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(color.onColor)
                Text("\(occ.ticketValue)")
                    .font(.system(.title, design: .rounded).weight(.heavy))
                    .foregroundStyle(color.onColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
            .frame(width: 78, height: 78)
            .background(color.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(color.onColor.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .padding(5)
            )
            .overlay(alignment: .topTrailing) {
                if dash.isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .padding(3)
                }
            }
            .opacity(dash.isDone ? 0.5 : 1)
            // Red glowing border for a held-over (overdue) chore.
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(dash.isHeldOver ? Color.red : .clear, lineWidth: 2.5)
            )
            .shadow(color: dash.isHeldOver ? Color.red.opacity(0.85) : .clear, radius: dash.isHeldOver ? 7 : 0)
            .frame(minWidth: 60, minHeight: 60)
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

/// The child's weekly (rotation) chore, as a thin button anchored to the top of
/// their card. It carries a **white glow** to set it apart from the regular
/// chore tiles, and stays prominent until it's checked off — once done it dims
/// to a struck-through, glow-less state (still tappable to undo, per §3.5).
private struct WeeklyChoreButton: View {
    let dash: DashChore
    let childName: String
    let onToggle: () -> Void

    private var occ: ChoreOccurrence { dash.occurrence }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: dash.isDone ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.bold))
                Text(occ.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .strikethrough(dash.isDone, color: .secondary)
                Spacer(minLength: 6)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2)
                    Text("\(occ.ticketValue)").font(.caption).fontWeight(.semibold)
                }
            }
            .foregroundStyle(.primary)
            .opacity(dash.isDone ? 0.55 : 1)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.20)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(dash.isDone ? Color.white.opacity(0.15) : Color.white.opacity(0.9), lineWidth: 1.5)
            )
            .shadow(color: dash.isDone ? .clear : Color.white.opacity(0.8), radius: dash.isDone ? 0 : 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly chore: \(occ.label) for \(childName), \(occ.ticketValue) ticket\(occ.ticketValue == 1 ? "" : "s")")
        .accessibilityValue(dash.isDone ? "Done" : "Not done")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Marks the weekly chore \(dash.isDone ? "not done" : "done")")
    }
}
