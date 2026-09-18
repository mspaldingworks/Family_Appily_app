import FamilyCore
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct ChoresEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct ChoresProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChoresEntry {
        ChoresEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChoresEntry) -> Void) {
        let snap = context.isPreview ? .sample : (FamilyWidgetSharing.read() ?? .sample)
        completion(ChoresEntry(date: .now, snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChoresEntry>) -> Void) {
        // The app reloads timelines whenever chores/tickets change; this hourly
        // policy is just a fallback so a rarely-opened widget still refreshes.
        let snap = FamilyWidgetSharing.read() ?? .sample
        let entry = ChoresEntry(date: .now, snapshot: snap)
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct ChoresWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FamilyAppilyChores", provider: ChoresProvider()) { entry in
            ChoresWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Family Chores")
        .description("Today's chores left and tickets for each kid.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Views

struct ChoresWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .containerBackground(for: .widget) {
                switch family {
                case .accessoryRectangular, .accessoryCircular:
                    Color.clear
                default:
                    Color(.systemBackground)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if snapshot.kids.isEmpty {
            emptyState
        } else {
            switch family {
            case .systemSmall:      SmallView(snapshot: snapshot)
            case .systemMedium:     MediumView(snapshot: snapshot)
            case .accessoryRectangular: RectangularView(snapshot: snapshot)
            case .accessoryCircular:    CircularView(snapshot: snapshot)
            default:                MediumView(snapshot: snapshot)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "checklist").font(.title2)
            Text("Open Family Appily").font(.caption2).multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
    }
}

/// A kid's colour disc with their emblem symbol or initial — the widget's
/// stand-in for the mascot (kept lightweight, no shared art needed).
private struct KidDisc: View {
    let kid: WidgetSnapshot.Kid
    var size: CGFloat = 30

    private var color: Color { ChildTheme.custom(hex: kid.colorHex).dotFill }

    var body: some View {
        ZStack {
            Circle().fill(color)
            if kid.emblemSymbol.isEmpty {
                Text(kid.initial)
                    .font(.system(size: size * 0.44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: kid.emblemSymbol)
                    .font(.system(size: size * 0.46, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct SmallView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Chores", systemImage: "checklist")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            ForEach(snapshot.kids.prefix(3)) { kid in
                HStack(spacing: 6) {
                    KidDisc(kid: kid, size: 24)
                    Text(kid.allDone ? "All done" : "\(kid.remaining) left")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(kid.allDone ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(kid.name): \(kid.allDone ? "all done" : "\(kid.remaining) chores left")")
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MediumView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Today's chores", systemImage: "checklist")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                ForEach(snapshot.kids.prefix(5)) { kid in
                    VStack(spacing: 4) {
                        KidDisc(kid: kid, size: 34)
                        Text(kid.name).font(.caption2).lineLimit(1)
                        Text(kid.choresToday == 0 ? "—" : "\(kid.choresDone)/\(kid.choresToday)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(kid.allDone ? .green : .primary)
                        Label("\(kid.tickets)", systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(kid.name): \(kid.choresDone) of \(kid.choresToday) chores done, \(kid.tickets) tickets")
                }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct RectangularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label("Family chores", systemImage: "checklist").font(.caption2.weight(.bold))
            if snapshot.totalRemaining == 0 {
                Text("All done today 🎉").font(.caption)
            } else {
                Text("\(snapshot.totalRemaining) left today").font(.caption.weight(.semibold))
            }
        }
        .accessibilityLabel("Family chores: \(snapshot.totalRemaining) left today")
    }
}

private struct CircularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text("\(snapshot.totalRemaining)").font(.title2.weight(.bold))
                Image(systemName: "checklist").font(.caption2)
            }
        }
        .accessibilityLabel("\(snapshot.totalRemaining) chores left today")
    }
}

#Preview("Medium", as: .systemMedium) {
    ChoresWidget()
} timeline: {
    ChoresEntry(date: .now, snapshot: .sample)
}

#Preview("Small", as: .systemSmall) {
    ChoresWidget()
} timeline: {
    ChoresEntry(date: .now, snapshot: .sample)
}
