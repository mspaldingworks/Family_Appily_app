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
    public let id: ChildID
    public let dotFill: Color
    public let textInk: Color
    public let titleColor: Color

    private init(id: ChildID, dotFill: String, textInk: String, titleColor: String) {
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
    /// Card/chart background, light mode.
    public static let paper = Color(hex: "#FFFFFF")
    /// Card/chart background, dark mode. A warm charcoal, not inverted grey.
    public static let paperDark = Color(hex: "#1C1C1E")
    /// The hand-drawn checkmark. Always full-opacity black — never inherits the
    /// completed chore text's opacity fade (see CompletionMark).
    public static let completionMark = Color(hex: "#1F1F26")
}
