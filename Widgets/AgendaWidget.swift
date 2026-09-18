import FamilyCore
import SwiftUI
import WidgetKit

/// "Family Today" — today's calendar events, read from the same App Group
/// snapshot as the chores widget (the app fills in events; the widget never
/// touches EventKit). Reuses `ChoresProvider`/`ChoresEntry` from ChoresWidget.
struct AgendaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FamilyAppilyAgenda", provider: ChoresProvider()) { entry in
            AgendaWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Family Today")
        .description("Today's events across the family's calendars.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct AgendaWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                family == .accessoryRectangular ? Color.clear : Color(.systemBackground)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular: AgendaRectangularView(events: snapshot.events)
        case .systemSmall:          AgendaListView(events: snapshot.events, limit: 3)
        default:                    AgendaListView(events: snapshot.events, limit: 5)
        }
    }
}

private func eventTimeLabel(_ e: WidgetSnapshot.Event) -> String {
    e.isAllDay ? "All day" : e.start.formatted(date: .omitted, time: .shortened)
}

private func eventColor(_ e: WidgetSnapshot.Event) -> Color {
    guard let c = e.color else { return .gray }
    return Color(red: c.red, green: c.green, blue: c.blue).opacity(max(c.alpha, 0.8))
}

private struct AgendaListView: View {
    let events: [WidgetSnapshot.Event]
    let limit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Today", systemImage: "calendar")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            if events.isEmpty {
                Spacer(minLength: 0)
                Text("No events today").font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(events.prefix(limit)) { event in
                    HStack(spacing: 6) {
                        Circle().fill(eventColor(event)).frame(width: 7, height: 7)
                        Text(eventTimeLabel(event))
                            .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                        Text(event.title).font(.caption).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(eventTimeLabel(event)), \(event.title)")
                }
                if events.count > limit {
                    Text("+\(events.count - limit) more").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct AgendaRectangularView: View {
    let events: [WidgetSnapshot.Event]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Today", systemImage: "calendar").font(.caption2.weight(.bold))
            if let next = events.first {
                Text("\(eventTimeLabel(next)) · \(next.title)").font(.caption).lineLimit(1)
                if events.count > 1 {
                    Text("+\(events.count - 1) more today").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                Text("No events today").font(.caption)
            }
        }
        .accessibilityLabel(events.isEmpty ? "No events today" : "Next event: \(events.first!.title)")
    }
}

#Preview("Agenda Medium", as: .systemMedium) {
    AgendaWidget()
} timeline: {
    ChoresEntry(date: .now, snapshot: .sample)
}
