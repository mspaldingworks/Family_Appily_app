import Foundation

/// The curated set of chore icons an adult scrolls through when defining a
/// chore, instead of typing an SF Symbol name. Each entry pairs an SF Symbol
/// with a plain-language label so VoiceOver reads "Bed", not "bed.double.fill"
/// (CLAUDE.md §3.3). All symbols exist on the iOS 17 / macOS 14 minimum.
public enum ChoreIconCatalog {
    public struct Icon: Identifiable, Hashable, Sendable {
        public let symbol: String
        public let label: String
        public var id: String { symbol }
        public init(symbol: String, label: String) {
            self.symbol = symbol
            self.label = label
        }
    }

    /// Grouped loosely by room so scrolling feels ordered, not random.
    public static let all: [Icon] = [
        // Bedroom / living
        Icon(symbol: "bed.double.fill", label: "Bed"),
        Icon(symbol: "sofa.fill", label: "Tidy room"),
        Icon(symbol: "teddybear.fill", label: "Toys"),
        Icon(symbol: "lightbulb.fill", label: "Lights"),
        // Kitchen
        Icon(symbol: "fork.knife", label: "Dishes"),
        Icon(symbol: "sink.fill", label: "Sink"),
        Icon(symbol: "dishwasher.fill", label: "Dishwasher"),
        Icon(symbol: "refrigerator.fill", label: "Fridge"),
        Icon(symbol: "oven.fill", label: "Oven"),
        Icon(symbol: "microwave.fill", label: "Microwave"),
        Icon(symbol: "cup.and.saucer.fill", label: "Cups"),
        Icon(symbol: "cart.fill", label: "Groceries"),
        Icon(symbol: "waterbottle.fill", label: "Water"),
        // Laundry / clothes
        Icon(symbol: "washer.fill", label: "Laundry"),
        Icon(symbol: "dryer.fill", label: "Dryer"),
        Icon(symbol: "hanger", label: "Hang clothes"),
        Icon(symbol: "tshirt.fill", label: "Clothes"),
        Icon(symbol: "shoe.fill", label: "Shoes"),
        // Bathroom
        Icon(symbol: "shower.fill", label: "Shower"),
        Icon(symbol: "bathtub.fill", label: "Bath"),
        Icon(symbol: "toilet.fill", label: "Bathroom"),
        // Cleaning / trash
        Icon(symbol: "trash.fill", label: "Trash"),
        Icon(symbol: "arrow.3.trianglepath", label: "Recycling"),
        Icon(symbol: "sparkles", label: "Tidy up"),
        Icon(symbol: "bubbles.and.sparkles.fill", label: "Clean"),
        // Pets / plants
        Icon(symbol: "pawprint.fill", label: "Pet"),
        Icon(symbol: "dog.fill", label: "Dog"),
        Icon(symbol: "cat.fill", label: "Cat"),
        Icon(symbol: "leaf.fill", label: "Plants"),
        Icon(symbol: "drop.fill", label: "Watering"),
        // School / out / other
        Icon(symbol: "book.fill", label: "Read"),
        Icon(symbol: "backpack.fill", label: "Backpack"),
        Icon(symbol: "graduationcap.fill", label: "School"),
        Icon(symbol: "gamecontroller.fill", label: "Screen time"),
        Icon(symbol: "car.fill", label: "Car"),
        Icon(symbol: "bicycle", label: "Bike"),
        Icon(symbol: "trophy.fill", label: "Reward"),
        Icon(symbol: "star.fill", label: "Star"),
        Icon(symbol: "checklist", label: "Checklist"),
        Icon(symbol: "calendar", label: "Calendar"),
    ]

    /// The friendly label for a symbol, falling back to the raw name for a
    /// chore whose current symbol isn't in the catalog (e.g. a seeded one).
    public static func label(for symbol: String) -> String {
        all.first { $0.symbol == symbol }?.label ?? symbol
    }
}
