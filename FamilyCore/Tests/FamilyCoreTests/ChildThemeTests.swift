import Testing
@testable import FamilyCore

struct ChildThemeTests {
    /// Regression guard for the dotFill/textInk split: none of the
    /// decorative-only mascot hex values (which fail AA contrast) may ever
    /// match a child's canonical dotFill or textInk value.
    @Test func decorativeColorsNeverMatchIdentityColors() {
        let decorativeHex: Set<String> = [
            "#F0B440", "#D98A4E", "#C4372F", "#2E3A80", "#4E7A3A", // Finley mascot
            "#7CAD48", "#8ABB55", "#D18B4A", // Arthur mascot
            "#9ED2EE", "#DCF0FA", "#E08A5A", "#F2A9A4", // Maryn mascot
        ]

        for (_, hexPair) in ChildTheme.referenceHex {
            #expect(!decorativeHex.contains(hexPair.dotFill))
            #expect(!decorativeHex.contains(hexPair.textInk))
        }
    }

    @Test func matchesTokensJSONExactly() {
        #expect(ChildTheme.referenceHex[.finley]?.dotFill == "#1B4F9C")
        #expect(ChildTheme.referenceHex[.finley]?.textInk == "#1B4F9C")
        #expect(ChildTheme.referenceHex[.arthur]?.dotFill == "#5CB85C")
        #expect(ChildTheme.referenceHex[.arthur]?.textInk == "#3E7D36")
        #expect(ChildTheme.referenceHex[.maryn]?.dotFill == "#E04E2C")
        #expect(ChildTheme.referenceHex[.maryn]?.textInk == "#BF3A1E")
    }
}
