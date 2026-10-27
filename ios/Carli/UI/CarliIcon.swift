import SwiftUI

/// Maps the backend's icon names (Lucide-style, shared with the Flutter app) to SF Symbols.
enum CarliIcon {
    /// Icons offered when creating or editing a category, in picker order.
    static let categoryChoices = ["house", "key-round", "zap", "droplet", "flame", "wifi", "wrench", "sofa", "bath", "utensils",
        "shopping-cart", "utensils-crossed", "coffee", "pizza", "wine", "beer", "croissant", "apple", "car", "fuel", "bus",
        "train-front", "car-taxi-front", "square-parking", "bike", "plane", "hotel", "map", "party-popper", "clapperboard",
        "popcorn", "ticket", "music", "gamepad-2", "dices", "dumbbell", "trophy", "mountain", "heart-pulse", "pill",
        "stethoscope", "hospital", "syringe", "shield-plus", "repeat", "tv", "app-window", "smartphone", "laptop", "headphones",
        "camera", "shirt", "glasses", "scissors", "gem", "graduation-cap", "book-open", "school", "newspaper", "gift", "cake",
        "baby", "dog", "cat", "paw-print", "landmark", "receipt", "percent", "briefcase", "sparkles", "rotate-ccw", "coins",
        "piggy-bank", "hand-coins", "tree-palm", "circle-ellipsis"]

    static func symbol(_ name: String) -> String {
        map[name] ?? "circle.dashed"
    }

    private static let map: [String: String] = [
        "alert-circle": "exclamationmark.circle", "shield": "shield", "handshake": "person.2", "alert-triangle": "exclamationmark.triangle", "triangle-alert": "exclamationmark.triangle",
        "apple": "apple.logo", "archive": "archivebox", "arrow-left-right": "arrow.left.arrow.right", "award": "rosette",
        "baby": "figure.child", "banknote": "banknote", "bar-chart": "chart.bar", "bar-chart-3": "chart.bar", "bath": "bathtub",
        "bed": "bed.double", "beer": "mug", "bell": "bell", "bike": "bicycle", "book": "book.closed", "book-open": "book",
        "briefcase": "briefcase", "building": "building", "building-2": "building.2", "bus": "bus", "cake": "birthday.cake",
        "calendar": "calendar", "calendar-days": "calendar", "calendar-clock": "calendar.badge.clock", "camera": "camera",
        "car": "car", "cat": "cat", "chart-column": "chart.bar", "chart-line": "chart.xyaxis.line", "chart-pie": "chart.pie",
        "check": "checkmark", "check-circle": "checkmark.circle", "circle-check": "checkmark.circle", "check-square": "checkmark.square",
        "square-check": "checkmark.square", "cigarette": "smoke", "circle": "circle", "circle-dashed": "circle.dashed",
        "clock": "clock", "coffee": "cup.and.saucer", "cog": "gearshape", "coins": "dollarsign.circle", "credit-card": "creditcard",
        "croissant": "takeoutbag.and.cup.and.straw", "dices": "dice", "dog": "dog", "droplet": "drop", "droplets": "drop.fill",
        "dumbbell": "dumbbell", "euro": "eurosign", "film": "film", "flag": "flag", "flame": "flame", "fuel": "fuelpump",
        "gamepad-2": "gamecontroller", "gauge": "gauge.with.dots.needle.50percent", "gem": "diamond", "gift": "gift",
        "glasses": "eyeglasses", "globe": "globe", "graduation-cap": "graduationcap", "hammer": "hammer", "hand": "hand.raised",
        "hand-coins": "hands.and.sparkles", "headphones": "headphones", "heart": "heart", "heart-pulse": "heart.text.square",
        "home": "house", "house": "house", "hospital": "cross.case", "hotel": "bed.double", "hourglass": "hourglass",
        "inbox": "tray", "key-round": "key", "landmark": "building.columns", "laptop": "laptopcomputer",
        "layout-dashboard": "square.grid.2x2", "leaf": "leaf", "lightbulb": "lightbulb", "list": "list.bullet",
        "list-checks": "checklist", "lock": "lock", "mail": "envelope", "map": "map", "moon": "moon", "mountain": "mountain.2",
        "music": "music.note", "newspaper": "newspaper", "notebook-pen": "note.text", "package": "shippingbox",
        "palette": "paintpalette", "party-popper": "party.popper", "paw-print": "pawprint", "pencil": "pencil",
        "percent": "percent", "phone": "phone", "piggy-bank": "banknote", "pill": "pills", "pizza": "fork.knife",
        "plane": "airplane", "plug": "powerplug", "receipt": "receipt", "repeat": "repeat", "running": "figure.run",
        "scale": "scalemass", "school": "graduationcap", "scissors": "scissors", "shirt": "tshirt", "shopping-bag": "bag",
        "shopping-cart": "cart", "smartphone": "iphone", "sofa": "sofa", "sparkles": "sparkles", "star": "star",
        "stethoscope": "stethoscope", "store": "storefront", "sun": "sun.max", "syringe": "syringe", "tag": "tag",
        "target": "target", "ticket": "ticket", "train": "tram", "train-front": "tram", "tree-palm": "tree", "trophy": "trophy",
        "tv": "tv", "umbrella": "umbrella", "user": "person", "users": "person.2", "utensils": "fork.knife",
        "utensils-crossed": "fork.knife", "wallet": "wallet.bifold", "wifi": "wifi", "wine": "wineglass", "wrench": "wrench",
        "zap": "bolt", "notes": "note.text", "sticky-note": "note.text",
        "car-taxi-front": "car.side", "square-parking": "parkingsign", "clapperboard": "movieclapper", "popcorn": "popcorn",
        "shield-plus": "cross.case", "app-window": "macwindow", "rotate-ccw": "arrow.counterclockwise",
        "circle-ellipsis": "ellipsis.circle", "hand-heart": "hands.and.sparkles", "users-round": "person.2",
    ]
}
