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

    /// A parent-added child (id isn't a `ChildID` case) resolves to a custom
    /// colour theme with a nil id; an original resolves to its legend theme.
    @Test func customKidGetsOwnColorOriginalStaysLegendLocked() {
        let newKid = Child(id: "kid-abc123", name: "Sam", motif: "", cardFrame: "",
                           primaryAvatar: "", alternateAvatar: nil, topCornerMotif: "",
                           bottomCornerMotif: "", titleColorToken: "", age: 8, colorHex: "#7A4FC0")
        let newTheme = ChildTheme.theme(for: newKid)
        #expect(newTheme.id == nil)
        #expect(newTheme == ChildTheme.custom(hex: "#7A4FC0"))

        let finley = Child(id: "finley", name: "Finley", motif: "pizza", cardFrame: "book",
                           primaryAvatar: "finley", alternateAvatar: nil, topCornerMotif: "cap",
                           bottomCornerMotif: "hoodie", titleColorToken: "green")
        #expect(ChildTheme.theme(for: finley) == ChildTheme.finley)
    }

    /// A new kid without a chosen colour still gets a stable, valid palette colour.
    @Test func defaultColorIsStableAndFromPalette() {
        let kid = Child(id: "kid-xyz789", name: "Jo", motif: "", cardFrame: "",
                        primaryAvatar: "", alternateAvatar: nil, topCornerMotif: "",
                        bottomCornerMotif: "", titleColorToken: "")
        let a = KidPalette.color(for: kid.id)
        let b = KidPalette.color(for: kid.id)
        #expect(a == b)
        #expect(KidPalette.colors.contains(a))
    }

    @Test func kidEmblemsAvailable() {
        #expect(!KidEmblem.symbols.isEmpty)
        #expect(KidEmblem.symbols.contains("star.fill"))
    }
}
