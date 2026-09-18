import FamilyCore
import SwiftData
import SwiftUI

/// The adults' control room. On iOS it lives behind an `AdultGated` wall in the
/// Parents tab (the shared-device gate from CLAUDE.md §3.5); on the Mac it is
/// shown directly, since that is her own already-unlocked machine. Everything a
/// child must never touch — chore definitions, ticket balances, the rotation
/// start date, feedback — is changed here, in one place.
///
/// This is an admin surface, not a child-facing one, so it uses a standard
/// adaptive `Form` and *system* colours (which follow Light/Dark Mode), rather
/// than the fixed ink-on-white "paper" of the kids' charts.
struct ParentDashboardView: View {
    @Query(sort: \Child.name) private var children: [Child]
    @Query private var ticketEntries: [TicketLedgerEntry]
    @Query private var assignments: [ChoreAssignment]
    @Query private var chores: [Chore]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("rotationEpochISO8601") private var rotationEpochISO8601 = ""
    @AppStorage("weeklyChoreTicketValue") private var weeklyChoreTicketValue = 5
    @AppStorage("rotationName") private var rotationName = "Rotation"
    @AppStorage("rotationIcon") private var rotationIcon = "arrow.triangle.2.circlepath"
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = false
    @AppStorage("familyCalendar.writeThrough") private var writeChoresToCalendars = false

    @State private var draftEpoch = Date.now
    @State private var calendarService = EventKitCalendarService()

    var body: some View {
        Form {
            rotationSection
            childrenSection
            choresSection
            calendarSyncSection
            feedbackSection
            aboutSection
        }
        .navigationTitle("Parents")
        .onAppear { if let existing = storedEpoch { draftEpoch = existing } }
    }

    private var storedEpoch: Date? {
        rotationEpochISO8601.isEmpty ? nil : ISO8601DateFormatter().date(from: rotationEpochISO8601)
    }

    private var rotationSection: some View {
        Section {
            HStack(spacing: 12) {
                settingsIcon(rotationIcon, .purple)
                TextField("Rotation name", text: $rotationName)
                Menu {
                    Picker("Icon", selection: $rotationIcon) {
                        ForEach(rotationIconChoices, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol).tag(symbol)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 44)
            DatePicker("Week 1 started", selection: $draftEpoch, displayedComponents: .date)
            Button("Save rotation start") {
                rotationEpochISO8601 = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: draftEpoch))
            }
            .frame(minHeight: 44)
            Stepper(value: $weeklyChoreTicketValue, in: 1...20) {
                Label("Weekly chore tickets: \(weeklyChoreTicketValue)", systemImage: "star.fill")
                    .labelStyle(.titleAndIcon)
            }
            .frame(minHeight: 44)
            .accessibilityValue("\(weeklyChoreTicketValue) tickets")
        } header: {
            Text("Family rotation")
        } footer: {
            Text("Name the rotation and pick its icon — it shows beside the Family header on the home screen.\n\n"
            + (storedEpoch.map {
                "The Weekly Chore slots fill from the rotation that began \($0.formatted(date: .abbreviated, time: .omitted)). Change this only if Week 1 on the wall chart was a different Sunday."
            } ?? "Set the Sunday your family rotation's Week 1 began. This fills every child's Weekly Chore slot automatically — you never type it in weekly.")
            + "\n\nEvery weekly (rotation) chore is worth this many tickets when a child checks it off. Applies to all kids.")
        }
    }

    private let rotationIconChoices = [
        "arrow.triangle.2.circlepath", "arrow.2.circlepath", "repeat",
        "person.3.fill", "house.fill", "star.fill", "calendar", "sparkles",
    ]

    private var childrenSection: some View {
        Section {
            ForEach(children) { child in
                NavigationLink {
                    ChildSettingsView(child: child)
                } label: {
                    HStack(spacing: 12) {
                        ChildAvatarView(child: child, size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(child.name)
                            if child.age > 0 {
                                Text("Age \(child.age)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Label("\(TicketService.balance(for: child.id, in: ticketEntries))", systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(ChildTheme.theme(for: child).dotFill)
                            .fontWeight(.semibold)
                    }
                }
                .frame(minHeight: 44)
            }
            Button {
                let child = FamilyRoster.addChild(context: modelContext, existing: children)
                _ = child
            } label: {
                Label("Add child", systemImage: "plus.circle.fill")
            }
            .frame(minHeight: 44)
        } header: {
            Text("Children")
        } footer: {
            Text("Add your kids and set their names and ages. Tap a child to edit them or remove them. New children get a colour you pick; the original three keep their wall-chart look.")
        }
    }

    private var choresSection: some View {
        Section("Chores") {
            NavigationLink {
                ChoreSettingsView()
            } label: {
                HStack(spacing: 12) {
                    settingsIcon("checklist", .orange)
                    Text("Chore definitions")
                }
            }
            .frame(minHeight: 44)
        }
    }

    /// A friendly, iOS-Settings-style coloured glyph. Decorative and always
    /// paired with a text label, so it never carries meaning by colour alone
    /// (CLAUDE.md §3.2); `ChoreColor.onColor` keeps the glyph AA-legible.
    private func settingsIcon(_ symbol: String, _ color: ChoreColor) -> some View {
        Image(systemName: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color.onColor)
            .frame(width: 28, height: 28)
            .background(color.fill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }

    private var calendarSyncSection: some View {
        Section {
            HStack(spacing: 12) {
                settingsIcon("calendar", .blue)
                Toggle("Add chores to each kid's calendar", isOn: $writeChoresToCalendars)
            }
            .frame(minHeight: 44)
            if writeChoresToCalendars {
                Button("Update calendars now") { syncChoresToCalendars() }
                    .frame(minHeight: 44)
            }
        } header: {
            Text("Calendar")
        } footer: {
            Text("Adds each child's chores to their own calendar (matched by name) as weekly events, so they show in Google Calendar and on every family device. Needs calendar access (grant it on the Calendar tab) and a calendar named for each child on this device. Turn off to remove them.")
        }
        .onChange(of: writeChoresToCalendars) { _, _ in syncChoresToCalendars() }
    }

    /// Pushes the current chore assignments to (or, when off, clears them from)
    /// each kid's calendar. Only ever touches events the app tagged.
    private func syncChoresToCalendars() {
        guard calendarService.access == .granted else { return }
        _ = calendarService.syncFixedChoreEvents(
            desired: writeChoresToCalendars ? ChoreEventPlanner.fixedEvents(assignments: assignments, chores: chores) : []
        )
    }

    private var feedbackSection: some View {
        Section {
            Toggle("Vibrate when a chore is done", isOn: $hapticsEnabled)
            Toggle("Play a sound when a chore is done", isOn: $soundEnabled)
        } header: {
            Text("Feedback")
        } footer: {
            Text("Completing a chore can buzz and chime as it's marked done. Turn either off here.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
