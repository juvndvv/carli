import Foundation

extension Notification.Name {
    /// Posted after a weigh-in is saved or deleted, or the Salud settings change.
    static let healthChanged = Notification.Name("carli.healthChanged")
}

/// One weigh-in: from the scale (with the composition it worked out) or typed by hand.
struct BodyMeasurement: Decodable, Identifiable, Hashable {
    var id: String
    var measuredAt: String
    var weightKg: Double
    var source: String
    var bmi: Double?
    var fatPercent: Double?
    var musclePercent: Double?
    var waterPercent: Double?
    var visceralOrBone: Int?
    var basalKcal: Int?
    var impedances: [Int]?
    var device: String?
    var firmware: String?

    var date: Date { HealthDate.parse(measuredAt) ?? .distantPast }
    var fromScale: Bool { source == "scale" }
    var hasComposition: Bool { fatPercent != nil || musclePercent != nil || waterPercent != nil }

    func value(_ metric: BodyMetric) -> Double? {
        switch metric {
        case .weight: weightKg
        case .fat: fatPercent
        case .muscle: musclePercent
        case .water: waterPercent
        case .bmi: bmi
        }
    }
}

struct HealthSummary: Decodable, Equatable {
    var latest: BodyMeasurement?
    var latestWithMetrics: BodyMeasurement?
    var weekChange: Double?
    var monthChange: Double?
    var goalKg: Double?
    var toGoalKg: Double?
    var weighedToday: Bool
    var profileComplete: Bool
}

/// Profile the scale needs for its composition, and the weigh-in reminder.
struct HealthProfile: Decodable, Equatable {
    var heightCm: Int?
    var birthDate: String?
    var sex: String?
    var goalKg: Double?
    var reminderEnabled: Bool
    var reminderTime: String
    var reminderDays: [Int]
    var age: Int?

    var isComplete: Bool { heightCm != nil && age != nil && sex != nil }

    /// What the scale gets sent; it needs a value, so a missing profile falls back to an average adult.
    var scaleProfile: QNProfile {
        QNProfile(heightCm: heightCm ?? 170, age: age ?? 30, sex: sex == "female" ? .female : .male)
    }
}

enum BodyMetric: String, CaseIterable, Identifiable {
    case weight, fat, muscle, water, bmi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "Peso"
        case .fat: "Grasa"
        case .muscle: "Músculo"
        case .water: "Agua"
        case .bmi: "IMC"
        }
    }

    var unit: String {
        switch self {
        case .weight: "kg"
        case .fat, .muscle, .water: "%"
        case .bmi: ""
        }
    }

    func format(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "es_ES")))
        return unit.isEmpty ? number : unit == "%" ? "\(number) %" : "\(number) \(unit)"
    }
}

/// Chart and list ranges.
enum HealthRange: String, CaseIterable, Identifiable {
    case month, quarter, year, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: "1 M"
        case .quarter: "3 M"
        case .year: "1 A"
        case .all: "Todo"
        }
    }

    var start: Date? {
        let calendar = CarliDate.calendar
        switch self {
        case .month: return calendar.date(byAdding: .month, value: -1, to: .now)
        case .quarter: return calendar.date(byAdding: .month, value: -3, to: .now)
        case .year: return calendar.date(byAdding: .year, value: -1, to: .now)
        case .all: return nil
        }
    }
}

enum HealthDate {
    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()

    static func parse(_ text: String) -> Date? {
        plain.date(from: text) ?? withFraction.date(from: text)
    }

    static func string(_ date: Date) -> String {
        plain.string(from: date)
    }

    /// "2026-10-28" in the phone's time zone, for the `from` filter.
    static func day(_ date: Date) -> String {
        let c = CarliDate.calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

/// Signed change: "−1,2 kg", "+0,4 kg", "=".
enum WeightFormat {
    static func kg(_ value: Double, digits: Int = 1) -> String {
        "\(value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "es_ES")))) kg"
    }

    static func change(_ value: Double) -> String {
        if abs(value) < 0.05 { return "Sin cambios" }
        return "\(value < 0 ? "−" : "+")\(kg(abs(value)))"
    }
}
