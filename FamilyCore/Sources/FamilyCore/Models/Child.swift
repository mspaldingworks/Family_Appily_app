import Foundation
import SwiftData

@Model
public final class Child {
    @Attribute(.unique) public var id: String
    public var name: String
    public var motif: String
    public var cardFrame: String
    public var primaryAvatar: String
    public var alternateAvatar: String?
    public var topCornerMotif: String
    public var bottomCornerMotif: String
    public var titleColorToken: String

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
        titleColorToken: String
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
    }
}
