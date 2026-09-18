import SwiftUI

/// One child's identity, from `family-hub-assets/design/tokens.json`.
///
/// Only `dotFill` and `textInk` are exposed here, and they are the only colors
/// this type can produce — that split is load-bearing. `dotFill` matches the
/// physical chart's legend exactly and is safe for shape fills only; several
/// children's `dotFill` values fail AA contrast for text. `textInk` is a
/// separately-chosen, contrast-passing color for text/labels/stateful UI.
/// Decorative mascot-palette colors (pizza gold, bamboo greens, etc.) are a
/// deliberately different type, `DecorativeAccent`, so a view reaching for
/// "Finley's color" to tint text can't accidentally grab a decorative value —
/// see `RotationEngineTests` and `ChildThemeTests` for the regression guard.
public struct ChildTheme: Equatable, Sendable {
    /// The legend child this theme belongs to, or nil for a parent-added child's
    /// custom colour (which isn't one of the three wall-chart originals).
    public let id: ChildID?
    public let dotFill: Color
    public let textInk: Color
    public let titleColor: Color

    private init(id: ChildID?, dotFill: String, textInk: String, titleColor: String) {
        self.id = id
        self.dotFill = Color(hex: dotFill)
        self.textInk = Color(hex: textInk)
        self.titleColor = Color(hex: titleColor)
    }

    public static let finley = ChildTheme(
        id: .finley,
        dotFill: "#1B4F9C",
        textInk: "#1B4F9C",
        titleColor: SharedTokens.chartTitleGreenHex
    )

    public static let arthur = ChildTheme(
        id: .arthur,
        dotFill: "#5CB85C",
        textInk: "#3E7D36",
        titleColor: SharedTokens.chartTitleGreenHex
    )

    public static let maryn = ChildTheme(
        id: .maryn,
        dotFill: "#E04E2C",
        textInk: "#BF3A1E",
        titleColor: SharedTokens.chartTitleRedHex
    )

    public static func theme(for id: ChildID) -> ChildTheme {
        switch id {
        case .finley: return .finley
        case .arthur: return .arthur
        case .maryn: return .maryn
        }
    }

    /// The theme for any child: the legend theme for the three originals, or a
    /// custom colour for a parent-added child (§7.1 keeps the originals locked;
    /// this only ever colours *new* kids). Falls back to a stable palette colour
    /// if a new child hasn't been given one yet.
    public static func theme(for child: Child) -> ChildTheme {
        if let id = child.childID { return theme(for: id) }
        let hex = child.colorHex.isEmpty ? KidPalette.color(for: child.id) : child.colorHex
        return custom(hex: hex)
    }

    /// A single-colour theme for a parent-added child. `dotFill` == `textInk` so
    /// the chosen colour both fills and labels; `KidPalette` keeps the choices
    /// legible so this stays AA-safe (§3.2).
    public static func custom(hex: String) -> ChildTheme {
        ChildTheme(id: nil, dotFill: hex, textInk: hex, titleColor: hex)
    }

    /// A child's identity colour as a hex string — the legend colour for the
    /// three originals, the chosen (or default) palette colour for others. Used
    /// where a `Color` can't cross a boundary, e.g. the widget snapshot.
    public static func identityHex(for child: Child) -> String {
        if let id = child.childID { return referenceHex[id]?.dotFill ?? "#3A6EA5" }
        return child.colorHex.isEmpty ? KidPalette.color(for: child.id) : child.colorHex
    }

    /// Raw hex values, exposed only for unit-testing the theme against tokens.json —
    /// not for use in views. Use `dotFill`/`textInk` (Color) in view code.
    public static let referenceHex: [ChildID: (dotFill: String, textInk: String)] = [
        .finley: ("#1B4F9C", "#1B4F9C"),
        .arthur: ("#5CB85C", "#3E7D36"),
        .maryn: ("#E04E2C", "#BF3A1E"),
    ]
}

public enum ChildID: String, CaseIterable, Codable, Sendable {
    case finley
    case arthur
    case maryn
}

/// Identity colours a parent can assign to a child who isn't one of the three
/// legend-locked originals (§7.1). Chosen to stay legible both as a fill and as
/// text on the light paper card, so `ChildTheme.custom` stays AA-safe. The three
/// originals never use these — their colours come from the wall-chart legend.
public enum KidPalette {
    public static let colors: [String] = [
        "#1B4F9C", // blue
        "#5CB85C", // green
        "#E04E2C", // red-orange
        "#7A4FC0", // purple
        "#0E8C86", // teal
        "#C0397B", // magenta
        "#B8791B", // amber
        "#3A6EA5", // steel
    ]

    /// A deterministic default colour for a child that hasn't been given one,
    /// derived from their id so it's stable across launches (String.hashValue
    /// is not — a scalar fold is).
    public static func color(for id: String) -> String {
        guard !colors.isEmpty else { return "#3A6EA5" }
        let fold = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[fold % colors.count]
    }
}

/// Emblems a parent can give a child who isn't one of the three legend originals
/// — a friendly SF Symbol shown in the child's colour as a mascot stand-in. All
/// exist on the iOS 17 / macOS 14 minimum. An empty choice means "use a monogram
/// of the name" instead.
public enum KidEmblem {
    public static let symbols: [String] = [
        "star.fill", "heart.fill", "pawprint.fill", "soccerball", "bicycle",
        "airplane", "leaf.fill", "tortoise.fill", "hare.fill", "bird.fill",
        "fish.fill", "gamecontroller.fill", "paintbrush.fill", "music.note",
        "sun.max.fill", "moon.fill", "sparkles", "flame.fill",
    ]
}

/// Decorative-only colors from the mascot artwork. FAIL text contrast on white
/// per tokens.json and must only be used as illustration fill — never as text
/// color, tint, or the sole indicator of state. Kept in a separate type from
/// `ChildTheme` on purpose so text/tint call sites never reach for these.
public struct DecorativeAccent {
    public let hex: String
    public var color: Color { Color(hex: hex) }

    public enum Finley {
        public static let cheese = DecorativeAccent(hex: "#F0B440")
        public static let crust = DecorativeAccent(hex: "#D98A4E")
        public static let pepperoni = DecorativeAccent(hex: "#C4372F")
        public static let capNavy = DecorativeAccent(hex: "#2E3A80")
        public static let hoodieGreen = DecorativeAccent(hex: "#4E7A3A")
    }

    public enum Arthur {
        public static let bambooMid = DecorativeAccent(hex: "#7CAD48")
        public static let bambooLight = DecorativeAccent(hex: "#8ABB55")
        public static let hatOrange = DecorativeAccent(hex: "#D18B4A")
    }

    public enum Maryn {
        public static let ice = DecorativeAccent(hex: "#9ED2EE")
        public static let iceLight = DecorativeAccent(hex: "#DCF0FA")
        public static let beak = DecorativeAccent(hex: "#E08A5A")
        public static let blush = DecorativeAccent(hex: "#F2A9A4")
    }
}

public enum SharedTokens {
    static let chartTitleGreenHex = "#3F6B2B"
    static let chartTitleRedHex = "#CE3626"

    /// Body text, outlines, character linework. 15.8:1 on white.
    public static let ink = Color(hex: "#1F1F26")
    /// Muted body text on paper — captions, secondary labels, "N tickets".
    /// Fixed (not the system `.secondary`) so it stays readable on the
    /// always-light paper card in Dark Mode, where `.secondary` would resolve
    /// to near-white and disappear. ~6.5:1 on white.
    public static let inkSecondary = Color(hex: "#55555E")
    /// Card/chart background. Deliberately light in both appearances — the
    /// chart reads like a sheet of paper on the wall, not an inverted panel.
    /// Anything drawn on top of it must use `ink`/`inkSecondary` or a child's
    /// `textInk`, never `.primary`/`.secondary`, which flip to white in the dark.
    public static let paper = Color(hex: "#FFFFFF")
    /// Card/chart background, dark mode. A warm charcoal, not inverted grey.
    public static let paperDark = Color(hex: "#1C1C1E")
    /// The hand-drawn checkmark. Always full-opacity black — never inherits the
    /// completed chore text's opacity fade (see CompletionMark).
    public static let completionMark = Color(hex: "#1F1F26")
}
