import Foundation
import SwiftData

public enum ChoreType: String, Codable, Sendable {
    case fixed
    case rotationResolved = "rotation-resolved"
}

@Model
public final class Chore {
    @Attribute(.unique) public var id: String
    public var type: String
    public var defaultLabel: String
    public var sfSymbol: String
    public var category: String?
    public var note: String?

    public var choreType: ChoreType { ChoreType(rawValue: type) ?? .fixed }

    public init(id: String, type: ChoreType, defaultLabel: String, sfSymbol: String, category: String?, note: String?) {
        self.id = id
        self.type = type.rawValue
        self.defaultLabel = defaultLabel
        self.sfSymbol = sfSymbol
        self.category = category
        self.note = note
    }
}
