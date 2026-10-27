import Foundation

/// Spanish formatting rules shared with the Flutter app: "1.234,56 €" with a
/// non-breaking space and a true minus sign.
enum Money {
    static let minus = "−"
    private static let nbsp = "\u{00A0}"

    enum Display { case plain, signed, absolute }

    static func format(_ cents: Int, _ display: Display = .plain) -> String {
        let formatted = "\(decimal(abs(cents)))\(nbsp)€"
        if display == .absolute || cents == 0 { return formatted }
        if cents < 0 { return minus + formatted }
        return display == .signed ? "+" + formatted : formatted
    }

    static func grouped(_ units: Int) -> String {
        let digits = Array(String(units))
        var out = ""
        for (i, digit) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { out.append(".") }
            out.append(digit)
        }
        return out
    }

    /// Cents from what someone typed: "12", "12,5", "1.234,56" or "12.50". Nil when empty or invalid.
    static func parse(_ text: String) -> Int? {
        var cleaned = text.replacingOccurrences(of: "€", with: "").filter { !$0.isWhitespace }
        guard !cleaned.isEmpty else { return nil }
        if cleaned.contains(",") {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        } else if cleaned.filter({ $0 == "." }).count > 1 {
            cleaned = cleaned.replacingOccurrences(of: ".", with: "")
        }
        guard let value = Double(cleaned), value >= 0, value < 100_000_000 else { return nil }
        return Int((value * 100).rounded())
    }

    /// Editable form of an amount: "1234,5" without grouping or symbol; whole euros drop the decimals.
    static func input(_ cents: Int) -> String {
        let euros = cents / 100, fraction = cents % 100
        if fraction == 0 { return "\(euros)" }
        return "\(euros),\(fraction < 10 ? "0" : "")\(fraction)"
    }

    private static func decimal(_ absoluteCents: Int) -> String {
        let fraction = absoluteCents % 100
        return "\(grouped(absoluteCents / 100)),\(fraction < 10 ? "0" : "")\(fraction)"
    }
}

enum CarliDate {
    static let weekdays = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    static let months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
                         "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    static let monthsShort = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]

    static var calendar: Calendar { Calendar(identifier: .gregorian) }

    /// "Martes, 27 de octubre"
    static func long(_ date: Date) -> String {
        let c = calendar.dateComponents([.weekday, .day, .month], from: date)
        return "\(weekdays[c.weekday! - 1].capitalizedFirst), \(c.day!) de \(months[c.month! - 1])"
    }

    /// "27 oct"
    static func short(_ date: Date) -> String {
        let c = calendar.dateComponents([.day, .month], from: date)
        return "\(c.day!) \(monthsShort[c.month! - 1])"
    }

    static func greeting(_ date: Date) -> String {
        switch calendar.component(.hour, from: date) {
        case 6..<14: "Buenos días"
        case 14..<21: "Buenas tardes"
        default: "Buenas noches"
        }
    }

    /// Parses "2026-10-27" (or a full ISO timestamp's date part) as a local calendar day.
    static func day(_ iso: String) -> Date? {
        let parts = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func instant(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)
    }

    /// "ahora", "hace 5 min", "hace 3 h", "ayer", "27 oct"
    static func relative(_ date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 60 { return "ahora" }
        if seconds < 3600 { return "hace \(Int(seconds / 60)) min" }
        if calendar.isDate(date, inSameDayAs: now) { return "hace \(Int(seconds / 3600)) h" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "ayer"
        }
        return short(date)
    }

    static func isoDay(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

enum Plural {
    static func daysLeft(_ days: Int) -> String {
        days <= 0 ? "último día" : days == 1 ? "queda 1 día" : "quedan \(days) días"
    }

    static func percent(basisPoints: Int?) -> String {
        guard let basisPoints else { return "—" }
        return "\(Int((Double(basisPoints) / 100).rounded())) %"
    }

    /// Habit numbers drop a trailing ",0": 8 → "8", 1.5 → "1,5".
    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }
}
