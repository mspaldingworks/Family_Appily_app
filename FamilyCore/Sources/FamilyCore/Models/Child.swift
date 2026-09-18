import Foundation
import SwiftData

@Model
public final class Child {
    // No `.unique` and all-defaulted: CloudKit (see FamilyModelContainer) rejects
    // unique constraints and requires every attribute optional-or-defaulted.
    // Uniqueness of `id` is upheld in app logic (seeders fetch-then-insert).
    public var id: String = ""
    public var name: String = ""
    public var motif: String = ""
    public var cardFrame: String = ""
    public var primaryAvatar: String = ""
    public var alternateAvatar: String?
    public var topCornerMotif: String = ""
    public var bottomCornerMotif: String = ""
    public var titleColorToken: String = ""
    /// Adult-set age. 0 = unset (kept as a defaulted Int for CloudKit).
    public var age: Int = 0
    /// A parent-added child's chosen identity colour (hex). Empty for the three
    /// legend-locked originals, whose colour comes from `ChildTheme`/`childID`.
    public var colorHex: String = ""
    /// A parent-added child's emblem — an SF Symbol shown in their colour as a
    /// mascot stand-in. Empty falls back to a monogram of their name.
    public var avatarSymbol: String = ""

    /// Non-nil only for the three legend originals (id == a `ChildID` case).
    /// A parent-added child has a fresh slug id, so this is nil — which is how
    /// the app knows to give them a colour + monogram and no rotation slot.
    public var childID: ChildID? { ChildID(rawValue: id) }

    public init(
        id: String,
        name: String,
        motif: String,
        cardFrame: String,
        primaryAvatar: String,
        alternateAvatar: String?,
        topCornerMotif: String,
        bottomCornerMotif: String,
        titleColorToken: String,
        age: Int = 0,
        colorHex: String = "",
        avatarSymbol: String = ""
    ) {
        self.id = id
        self.name = name
        self.motif = motif
        self.cardFrame = cardFrame
        self.primaryAvatar = primaryAvatar
        self.alternateAvatar = alternateAvatar
        self.topCornerMotif = topCornerMotif
        self.bottomCornerMotif = bottomCornerMotif
        self.titleColorToken = titleColorToken
        self.age = age
        self.colorHex = colorHex
        self.avatarSymbol = avatarSymbol
    }
}
