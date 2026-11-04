import Foundation
import CoreGraphics

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
    /// What the reminder covers; both missing before body measurements existed.
    var reminderWeight: Bool?
    var reminderBody: Bool?
    var age: Int?

    var remindsWeight: Bool { reminderWeight ?? true }
    var remindsBody: Bool { reminderBody ?? false }

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

// MARK: Medidas del cuerpo

/// Where on the body a site sits; the viewer places its dot from this.
enum BodyZone: String, CaseIterable, Identifiable {
    case neck, shoulders, chest, arm, forearm, wrist, waist, abdomen, hips, thigh, calf, ankle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neck: "Cuello"
        case .shoulders: "Hombros"
        case .chest: "Pecho"
        case .arm: "Brazo"
        case .forearm: "Antebrazo"
        case .wrist: "Muñeca"
        case .waist: "Cintura"
        case .abdomen: "Abdomen"
        case .hips: "Cadera"
        case .thigh: "Muslo"
        case .calf: "Gemelo"
        case .ankle: "Tobillo"
        }
    }

    /// Limbs come in pairs and take a side.
    var paired: Bool {
        switch self {
        case .arm, .forearm, .wrist, .thigh, .calf, .ankle: true
        default: false
        }
    }

    /// Point on the front silhouette, 0…1 across its width and height. The person faces the
    /// viewer, so their left side is drawn on the right.
    func point(side: String?) -> CGPoint {
        let y: CGFloat
        var x: CGFloat = 0.5
        switch self {
        case .neck: y = 0.135
        case .shoulders: y = 0.175
        case .chest: y = 0.24
        case .arm: y = 0.29; x = 0.243
        case .forearm: y = 0.40; x = 0.20
        case .wrist: y = 0.485; x = 0.175
        case .waist: y = 0.39
        case .abdomen: y = 0.33
        case .hips: y = 0.47
        case .thigh: y = 0.60; x = 0.405
        case .calf: y = 0.79; x = 0.415
        case .ankle: y = 0.91; x = 0.42
        }
        if paired && side == "left" { x = 1 - x }
        return CGPoint(x: x, y: y)
    }
}

struct BodySite: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var zone: String
    var side: String?
    var position: Int
    var archived: Bool

    var bodyZone: BodyZone { BodyZone(rawValue: zone) ?? .waist }
}

/// One value taken with the tape.
struct SiteValue: Decodable, Identifiable, Hashable {
    var id: String
    var siteId: String
    var measuredAt: String
    var valueCm: Double

    var date: Date { HealthDate.parse(measuredAt) ?? .distantPast }
}

/// A site on the body viewer: its latest value and the one it is compared with.
struct BodySiteOverview: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var zone: String
    var side: String?
    var position: Int
    var archived: Bool
    var latest: SiteValue?
    var baseline: SiteValue?
    var changeCm: Double?
    var count: Int

    var bodyZone: BodyZone { BodyZone(rawValue: zone) ?? .waist }
    var site: BodySite { BodySite(id: id, name: name, zone: zone, side: side, position: position, archived: archived) }
}

struct BodyOverview: Decodable, Equatable {
    var sites: [BodySiteOverview]
    var lastMeasuredAt: String?
    var measuredToday: Bool
}

/// What the viewer compares the latest values with.
enum BodyCompare: String, CaseIterable, Identifiable {
    case first, month, quarter, year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .first: "Inicio"
        case .month: "1 M"
        case .quarter: "3 M"
        case .year: "1 A"
        }
    }

    var caption: String {
        switch self {
        case .first: "desde la primera medida"
        case .month: "en el último mes"
        case .quarter: "en 3 meses"
        case .year: "en un año"
        }
    }

    /// The `compare` the server takes: "first" or the day to compare with.
    var query: String {
        let calendar = CarliDate.calendar
        let months: Int
        switch self {
        case .first: return "first"
        case .month: months = 1
        case .quarter: months = 3
        case .year: months = 12
        }
        return HealthDate.day(calendar.date(byAdding: .month, value: -months, to: .now) ?? .now)
    }
}

enum BodyFormat {
    static func cm(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "es_ES")))) cm"
    }

    /// "−2,1", "+0,4", "=" (centimetres implied).
    static func change(_ value: Double) -> String {
        if abs(value) < 0.05 { return "=" }
        let number = abs(value).formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "es_ES")))
        return "\(value < 0 ? "−" : "+")\(number)"
    }
}

// MARK: WHOOP

struct WhoopStatus: Decodable, Equatable {
    var configured: Bool
    var account: WhoopAccountInfo?
}

struct WhoopAccountInfo: Decodable, Equatable {
    var email: String?
    var status: String
    var syncedAt: String?
    var lastError: String?

    var needsReconnect: Bool { status == "reconnect" }
}

struct WhoopAuthURL: Decodable {
    var authUrl: String
}

/// One day as WHOOP saw it: the recovery and night that end on it, its strain and steps, and its workouts.
struct WhoopDay: Decodable, Identifiable, Equatable {
    var date: String
    var recovery: WhoopRecovery?
    var sleep: WhoopSleep?
    var napMinutes: Int
    var strain: WhoopStrain?
    var workouts: [WhoopWorkout]

    var id: String { date }
}

struct WhoopRecovery: Decodable, Equatable {
    var state: String
    var calibrating: Bool
    var score: Int?
    var restingHeartRate: Int?
    var hrvMs: Double?
    var spo2: Double?
    var skinTempC: Double?
}

struct WhoopSleep: Decodable, Equatable {
    var state: String
    var startsAt: String
    var endsAt: String
    var asleepMinutes: Int?
    var inBedMinutes: Int?
    var awakeMinutes: Int?
    var lightMinutes: Int?
    var deepMinutes: Int?
    var remMinutes: Int?
    var needMinutes: Int?
    var performance: Int?
    var consistency: Int?
    var efficiency: Double?
    var respiratoryRate: Double?
    var disturbances: Int?
}

struct WhoopStrain: Decodable, Equatable {
    var state: String
    var inProgress: Bool
    var strain: Double?
    var kcal: Int?
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    /// Wake to wake, not midnight to midnight; nil when the band was not worn.
    var steps: Int?
}

struct WhoopWorkout: Decodable, Identifiable, Equatable {
    var id: String
    var state: String
    var sport: String?
    var startsAt: String
    var endsAt: String
    var strain: Double?
    var kcal: Int?
    var averageHeartRate: Int?
    var maxHeartRate: Int?
    var distanceM: Double?
    /// Minutes in heart rate zones 0 to 5.
    var zoneMinutes: [Int]
}
