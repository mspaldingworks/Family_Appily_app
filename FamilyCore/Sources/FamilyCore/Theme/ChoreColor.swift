import SwiftUI

/// The parent-chosen colour palette for chore definitions (CLAUDE.md §4 admin
/// surface). This is a **new, adult-facing** palette — deliberately separate
/// from `ChildTheme`, which is the legend-locked, per-child identity system and
/// must never be recoloured. These colours only ever tint the chore cards an
/// adult manages; they never touch a child's chart.
///
/// Every entry is a mid-deep, saturated fill paired with an `onColor` that
/// clears AA on that fill, so the icon and the big ticket number stay legible
/// (CLAUDE.md §3.2). Colour is never the sole signal on a card — the icon, the
/// name, and the numeric ticket value all repeat the meaning — so these are safe to
/// use as a friendly, colourful ground.
public enum ChoreColor: String, CaseIterable, Identifiable, Sendable {
    case red
    case orange
    case yellow
    case green
    case teal
    case blue
    case purple
    case pink

    public var id: String { rawValue }

    /// The tile fill.
    public var fill: Color { Color(hex: hex) }

    /// A foreground (icon + number + name) that clears AA contrast on `fill`.
    /// Every fill here is dark enough for white except the sunny yellow, which
    /// takes the fixed dark ink instead.
    public var onColor: Color { self == .yellow ? SharedTokens.ink : .white }

    /// Human label shown in the card and read by VoiceOver ("Color: Red").
    public var displayName: String {
        switch self {
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .teal: return "Teal"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        }
    }

    private var hex: String {
        switch self {
        case .red: return "#C0392B"
        case .orange: return "#CF6A1A"
        case .yellow: return "#F2C94C"
        case .green: return "#2E8B57"
        case .teal: return "#12808F"
        case .blue: return "#2C6FB5"
        case .purple: return "#7A4DA8"
        case .pink: return "#C2508A"
        }
    }

    /// A stable default colour for a chore that has never been assigned one,
    /// derived from its id so the same chore is always the same colour across
    /// launches (a hash seeded per-process would flicker; scalar sum does not).
    public static func `default`(forID id: String) -> ChoreColor {
        let all = ChoreColor.allCases
        let sum = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return all[sum % all.count]
    }
}

public extension Chore {
    /// The chore's resolved colour: the adult's pick if set, otherwise a stable
    /// default so a chore is never colourless.
    var choreColor: ChoreColor {
        colorToken.flatMap(ChoreColor.init(rawValue:)) ?? .default(forID: id)
    }
}
