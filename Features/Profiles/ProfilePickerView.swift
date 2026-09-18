import FamilyCore
import SwiftData
import SwiftUI
import WidgetKit
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

    @Query private var familySettings: [FamilySettings]
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = false

    // Family-wide settings now live in a synced FamilySettings record (D4), not
    // per-device @AppStorage, so they match across the family's devices. Kept
    // under the same names so the rest of the view is unchanged.
    private var settings: FamilySettings? { familySettings.first }
    private var rotationEpochISO8601: String { settings?.rotationEpochISO8601 ?? "" }
    private var weeklyChoreTicketValue: Int { settings?.weeklyChoreTicketValue ?? 5 }
    private var rotationName: String { settings?.rotationName ?? "Rotation" }
    private var rotationIcon: String { settings?.rotationIcon ?? "arrow.triangle.2.circlepath" }

    /// Per-child counter that fires the +N ticket burst when a weekly chore is
    /// completed. Keyed by `ChildID.rawValue`; incrementing it plays the burst.
    @State private var burstTrigger: [String: Int] = [:]

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
                    section("Today") {
                        ForEach(children) { child in
                            kidRow(child, chores: todayChores(child, from: board),
                                   weekly: weeklyChore(child, from: rotation),
                                   burst: burstTrigger[child.childID?.rawValue ?? ""] ?? 0)
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) { rotationToolbarLink }
            }
            // Keep the home-screen/lock-screen widgets in step with the family's
            // chores and tickets. Writes a small snapshot to the shared App Group
            // and asks WidgetKit to reload (see FamilyWidgetSharing).
            .task { writeWidgetSnapshot() }
            .onChange(of: completions.count) { _, _ in writeWidgetSnapshot() }
            .onChange(of: ticketEntries.count) { _, _ in writeWidgetSnapshot() }
            .onChange(of: children.count) { _, _ in writeWidgetSnapshot() }
        }
    }

    /// The rotation entry, moved up beside the "Family" header. Its name and icon
    /// are parent-customisable (Parents ▸ Family rotation).
    private var rotationToolbarLink: some View {
        NavigationLink {
            FamilyRotationView()
        } label: {
            Label(rotationName, systemImage: rotationIcon)
        }
        .accessibilityLabel(rotationName)
        .accessibilityHint("Opens the shared family chore rotation")
    }

    // MARK: Sections

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded).weight(.bold))
            content()
        }
    }

    // MARK: One kid's row

    private func kidRow(_ child: Child, chores dashes: [DashChore], weekly: DashChore?, burst: Int? = nil) -> some View {
        let theme = ChildTheme.theme(for: child)
        return VStack(spacing: 10) {
            // The weekly (rotation) chore is anchored to the top of the card,
            // with a white glow, and vanishes the moment it's checked off — a
            // +5 ticket burst erupts from the bar in its place.
            if let weekly {
                WeeklyChoreButton(dash: weekly, childName: child.name) { toggleWeekly(weekly) }
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
        // The +5 burst plays over the top of the card, where the weekly bar sits.
        .overlay(alignment: .top) {
            if let burst {
                TicketBurst(trigger: burst, tint: theme.dotFill, value: weeklyChoreTicketValue)
                    .padding(.top, 6)
                    .allowsHitTesting(false)
            }
        }
    }

    private func kidBadge(_ child: Child) -> some View {
        NavigationLink {
            WeeklyChartView(child: child)
        } label: {
            VStack(spacing: 4) {
                ChildAvatarView(child: child, size: 48)
                Text(child.name)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                if child.age > 0 {
                    Text("Age \(child.age)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
            rotationContract: rotationContract,
            weeklyTicketValue: weeklyChoreTicketValue
        ).map(withCardStyle)
    }

    /// The child's weekly (rotation) chore for the week, if any — deduped to the
    /// earliest slot. Nil when the rotation isn't set up. Never "held over": a
    /// weekly chore can be done anytime this week. Once completed it returns nil
    /// so the bar disappears (undo is available from the weekly chart, §3.5).
    private func weeklyChore(_ child: Child, from rotation: [ChoreOccurrence]) -> DashChore? {
        guard rotationEpoch != nil, let cid = child.childID,
              let first = rotation.filter({ $0.childID == cid }).min(by: { $0.date < $1.date }) else { return nil }
        let done = doneKeys.contains(WeeklyChoreBoard.key(childID: cid.rawValue, choreID: first.choreID, date: first.date))
        if done { return nil }
        return DashChore(occurrence: first, isDone: false, isHeldOver: false)
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

    /// Completing a weekly chore: award its tickets, then fire the +5 burst from
    /// the bar (which the data change simultaneously removes). Weekly chores are
    /// only ever shown when not-done, so this always awards.
    private func toggleWeekly(_ dash: DashChore) {
        let occ = dash.occurrence
        let nowComplete = ChoreCompletion.toggle(
            childID: occ.childID.rawValue, choreID: occ.choreID, date: occ.date,
            ticketValue: occ.ticketValue, completions: completions,
            ticketEntries: ticketEntries, context: modelContext
        )
        if nowComplete {
            burstTrigger[occ.childID.rawValue, default: 0] += 1
            playFeedback()
        }
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

    /// Builds the glanceable per-kid summary from the same board the home screen
    /// shows and hands it to the widgets. Reuses the existing computed data, so
    /// it's cheap and always consistent with what's on screen.
    private func writeWidgetSnapshot() {
        let board = WeeklyChoreBoard.build(
            occurrences: weekOccurrences.filter { !$0.isRotationResolved },
            doneKeys: doneKeys, today: today
        )
        let kids = children.map { child -> WidgetSnapshot.Kid in
            let todays = todayChores(child, from: board)
            return WidgetSnapshot.Kid(
                id: child.id,
                name: child.name,
                colorHex: ChildTheme.identityHex(for: child),
                emblemSymbol: child.childID == nil ? child.avatarSymbol : "",
                choresToday: todays.count,
                choresDone: todays.filter(\.isDone).count,
                tickets: balance(for: child)
            )
        }
        FamilyWidgetSharing.write(WidgetSnapshot(kids: kids))
        WidgetCenter.shared.reloadAllTimelines()
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
/// chore tiles. It only ever renders while incomplete — checking it off removes
/// it entirely (and fires a +5 ticket burst); undo lives on the weekly chart.
private struct WeeklyChoreButton: View {
    let dash: DashChore
    let childName: String
    let onToggle: () -> Void

    private var occ: ChoreOccurrence { dash.occurrence }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.bold))
                Text(occ.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption2)
                    Text("\(occ.ticketValue)").font(.caption).fontWeight(.semibold)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.20)))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
            )
            .shadow(color: Color.white.opacity(0.8), radius: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly chore: \(occ.label) for \(childName), \(occ.ticketValue) ticket\(occ.ticketValue == 1 ? "" : "s")")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Marks the weekly chore done and awards \(occ.ticketValue) tickets")
    }
}

/// The +5 ticket burst that erupts from the weekly bar when a weekly chore is
/// completed (§3.7). Five stars fly outward and fade while a "+5" pops up; under
/// Reduce Motion it collapses to a still "+5 ⭐️" cross-fade with no motion.
/// Purely decorative — hidden from VoiceOver, non-interactive.
private struct TicketBurst: View {
    let trigger: Int
    let tint: Color
    let value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fire = false
    @State private var visible = false

    private let starCount = 5

    var body: some View {
        ZStack {
            if visible {
                if reduceMotion {
                    label.opacity(fire ? 0 : 1)
                } else {
                    ForEach(0..<starCount, id: \.self) { i in
                        let angle = Double(i) / Double(starCount) * 2 * .pi - .pi / 2
                        Image(systemName: "star.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.yellow)
                            .shadow(color: .orange.opacity(0.6), radius: 2)
                            .scaleEffect(fire ? 0.5 : 1)
                            .opacity(fire ? 0 : 1)
                            .offset(x: fire ? CGFloat(cos(angle)) * 62 : 0,
                                    y: fire ? CGFloat(sin(angle)) * 40 : 0)
                    }
                    label
                        .offset(y: fire ? -28 : 0)
                        .scaleEffect(fire ? 1.15 : 0.7)
                        .opacity(fire ? 0 : 1)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0 else { return }
            let duration = reduceMotion ? 0.3 : 0.45
            fire = false
            visible = true
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: duration)) { fire = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) { visible = false }
        }
    }

    private var label: some View {
        HStack(spacing: 2) {
            Text("+\(value)")
            Image(systemName: "star.fill").font(.caption)
        }
        .font(.system(.title3, design: .rounded).weight(.heavy))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(.ultraThinMaterial))
    }
}
