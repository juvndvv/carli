import Foundation

/// The Qingniu (QN) protocol spoken by the GE CS10G "Fit Plus" scale.
///
/// The scale notifies on FFF1 and takes commands on FFF2 (service FFF0). Every frame is
/// `[opcode, length, protocolType, payload…, checksum]`, where the checksum is the byte sum of
/// everything before it. Layout reimplemented from openScale's QNHandler documentation.
nonisolated enum QN {
    static let service = "FFF0"
    static let notifyCharacteristic = "FFF1"
    static let writeCharacteristic = "FFF2"
    /// Advertised names; the scale also advertises FFE0 before connecting.
    static let names: Set<String> = ["fit plus", "qn-scale"]
    static let advertisedServices: Set<String> = ["FFE0", "FFF0"]
    /// Unix time of the scale's epoch, as the vendor SDK uses it.
    static let epochOffset: TimeInterval = 946_702_800

    static func checksum(_ bytes: some Sequence<UInt8>) -> UInt8 {
        bytes.reduce(0, &+)
    }

    static func sealed(_ body: [UInt8]) -> [UInt8] {
        body + [checksum(body)]
    }

    static func hex(_ bytes: some Sequence<UInt8>) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    static func scaleSeconds(_ date: Date) -> UInt32 {
        UInt32(clamping: Int64(date.timeIntervalSince1970 - epochOffset))
    }

    static func date(scaleSeconds: UInt32) -> Date {
        Date(timeIntervalSince1970: TimeInterval(scaleSeconds) + epochOffset)
    }
}

nonisolated enum QNSex: UInt8, CaseIterable {
    case male = 0, female = 1
}

/// What the scale needs to know about the person before it measures.
nonisolated struct QNProfile: Equatable {
    var heightCm: Int
    var age: Int
    var sex: QNSex
}

/// Frames carli sends to the scale.
nonisolated enum QNCommand {
    /// Unit (kg), height, age and sex. Sent once the scale has said hello with 0x12.
    static func config(protocolType: UInt8, profile: QNProfile) -> [UInt8] {
        let height = UInt8(min(max(profile.heightCm, 60), 220))
        let age = UInt8(min(max(profile.age, 6), 80))
        return QN.sealed([0x13, 0x09, protocolType, 0x01, 0x10, height, age, profile.sex.rawValue])
    }

    /// Bare clock frame that follows the config (no opcode framing, as captured).
    static func clock(_ date: Date) -> [UInt8] {
        [0x02] + le32(QN.scaleSeconds(date))
    }

    /// Answer to 0x14.
    static func timeSync(protocolType: UInt8, date: Date) -> [UInt8] {
        QN.sealed([0x20, 0x08, protocolType] + le32(QN.scaleSeconds(date)))
    }

    /// Acknowledges a stable reading.
    static func stableAck(protocolType: UInt8) -> [UInt8] {
        QN.sealed([0x1F, 0x05, protocolType, 0x10])
    }

    /// Asks for the readings stored on the scale; it answers with 0x23 frames.
    static func historyQuery(protocolType: UInt8) -> [UInt8] {
        QN.sealed([0x22, 0x06, protocolType, 0x00, 0x03])
    }

    /// The two replies some QN scales expect after 0x21.
    static let handshakeReplies: [[UInt8]] = [
        QN.sealed([0xA0, 0x0D, 0x04, 0xFE, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
        QN.sealed([0xA0, 0x0D, 0x02, 0x01, 0x00, 0x08, 0x00, 0x21, 0x06, 0xB8, 0x04, 0x02]),
    ]

    private static func le32(_ value: UInt32) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)]
    }
}

/// A 0x10 frame: the weight while you stand on the scale.
nonisolated struct QNWeight: Equatable {
    var kg: Double
    var state: UInt8
    var isStable: Bool
    var r1: UInt16
    var r2: UInt16

    /// r1 comes in tenths of an ohm on this scale.
    var impedanceOhm: Double { Double(r1) / 10 }
}

/// A 0x23 frame: a reading kept on the scale.
nonisolated struct QNStoredReading: Equatable {
    var date: Date
    var kg: Double
    var r1: UInt16
    var r2: UInt16
}

/// The 8-electrode firmware (V48.0) sends each result as several 20-byte frames: 0x10 for the
/// weigh-in that just ended and 0x23 for those kept on the scale (answer to the history query).
/// Byte 4 is `total << 4 | index` (0x31, 0x32, 0x33 = parts 1–3 of 3).
nonisolated struct QNResultPart: Equatable {
    var index: Int
    var total: Int
    var bytes: [UInt8]
}

/// All parts of one result, checked against the display (137.80 kg, 137.60 kg).
///
/// - 0x10 part 1: header in bytes 2–3, weight in 5–6, values from 7.
/// - 0x23 part 1: header in 1–2, record number in 3, time in 5–8 (little-endian scale seconds),
///   weight in 9–10, values from 11.
/// - Later parts continue the values in bytes 2–3 (0x10) or 1–2 (0x23), then 5–18.
///
/// Weight is big-endian hundredths of a kg. The values are big-endian impedances in tenths of an
/// ohm, in pairs per segment at two frequencies (arms ~250–300 Ω, legs ~200–250 Ω, trunk ~20 Ω);
/// which segment is which is still to be mapped.
nonisolated struct QNResult: Equatable {
    var parts: [[UInt8]]
    /// The 0x24 frame that follows a stored result.
    var metrics: QNMetrics?

    init(parts: [[UInt8]], metrics: QNMetrics? = nil) {
        self.parts = parts
        self.metrics = metrics
    }

    var isStored: Bool { parts.first?.first == 0x23 }

    var date: Date? {
        guard isStored, let first = parts.first, first.count == 20 else { return nil }
        let seconds = UInt32(first[5]) | UInt32(first[6]) << 8 | UInt32(first[7]) << 16 | UInt32(first[8]) << 24
        return QN.date(scaleSeconds: seconds)
    }

    var kg: Double {
        guard let first = parts.first, first.count == 20 else { return 0 }
        let at = isStored ? 9 : 5
        return Double(UInt16(first[at]) << 8 | UInt16(first[at + 1])) / 100
    }

    var impedances: [UInt16] {
        parts.enumerated().flatMap { offset, part -> [UInt16] in
            guard part.count == 20 else { return [] }
            let data: [UInt8]
            switch (offset, isStored) {
            case (0, false): data = Array(part[7...18])
            case (0, true): data = Array(part[11...18])
            case (_, false): data = Array(part[2...3] + part[5...18])
            case (_, true): data = Array(part[1...2] + part[5...18])
            }
            return stride(from: 0, to: data.count - 1, by: 2).map { UInt16(data[$0]) << 8 | UInt16(data[$0 + 1]) }
        }
    }
}

/// 0x24: the body composition the scale worked out for the stored result before it. Positions
/// checked against the display on 2026-10-28 (IMC 45.0, agua 37.4 %, músculo 49.1 %, grasa 48.2 %).
/// Basal metabolism (1910 kcal) is likely; byte 9 is 26, which matched both visceral fat (26) and
/// bone mass (2.6 kg) that day, so it needs a weigh-in where they differ.
nonisolated struct QNMetrics: Equatable {
    var bytes: [UInt8]

    init?(_ bytes: [UInt8]) {
        guard bytes.count >= 19, bytes[0] == 0x24 else { return nil }
        self.bytes = bytes
    }

    private func tenths(_ at: Int) -> Double { Double(UInt16(bytes[at]) << 8 | UInt16(bytes[at + 1])) / 10 }

    var bmi: Double { tenths(3) }
    var waterPercent: Double { tenths(5) }
    var musclePercent: Double { tenths(7) }
    var visceralOrBone: Int { Int(bytes[9]) }
    var basalKcal: Int { Int(UInt16(bytes[11]) << 8 | UInt16(bytes[12])) }
    var fatPercent: Double { tenths(15) }
}

/// Collects result parts until the set is complete.
nonisolated struct QNResultAssembler {
    private var parts: [Int: [UInt8]] = [:]
    private var total = 0

    mutating func add(_ part: QNResultPart) -> QNResult? {
        if part.index == 1 || part.total != total { parts = [:]; total = part.total }
        parts[part.index] = part.bytes
        guard parts.count == total else { return nil }
        let result = QNResult(parts: (1...total).compactMap { parts[$0] })
        parts = [:]
        return result.parts.count == total ? result : nil
    }
}

nonisolated enum QNEvent: Equatable {
    case info(protocolType: UInt8, weightDivisor: Double)
    case weight(QNWeight)
    case resultPart(QNResultPart)
    case metrics(QNMetrics)
    case stored(QNStoredReading)
    /// 0x14: config accepted, wants the time.
    case configAck
    /// 0x21: wants the 0xA0 handshake.
    case handshake
    case other(opcode: UInt8)
}

nonisolated enum QNParser {
    /// `weightDivisor` comes from the last 0x12 frame (100 until then).
    static func parse(_ bytes: [UInt8], weightDivisor: Double) -> QNEvent? {
        guard bytes.count >= 3 else { return nil }
        switch bytes[0] {
        case 0x12:
            guard bytes.count > 10 else { return nil }
            return .info(protocolType: bytes[2], weightDivisor: bytes[10] == 1 ? 100 : 10)
        case 0x10:
            if let part = resultPart(bytes) { return .resultPart(part) }
            return weight(bytes, weightDivisor: weightDivisor).map(QNEvent.weight)
        case 0x23:
            if let part = resultPart(bytes) { return .resultPart(part) }
            guard bytes.count >= 17 else { return nil }
            let seconds = UInt32(bytes[6]) | UInt32(bytes[7]) << 8 | UInt32(bytes[8]) << 16 | UInt32(bytes[9]) << 24
            return .stored(QNStoredReading(date: QN.date(scaleSeconds: seconds),
                                           kg: Double(be16(bytes[10], bytes[11])) / 100,
                                           r1: le16(bytes[13], bytes[14]),
                                           r2: le16(bytes[15], bytes[16])))
        case 0x24: return QNMetrics(bytes).map(QNEvent.metrics)
        case 0x14: return .configAck
        case 0x21: return .handshake
        default: return .other(opcode: bytes[0])
        }
    }

    private static func resultPart(_ b: [UInt8]) -> QNResultPart? {
        guard b.count == 20, b[0] == 0x23 || b[1] == 0x14 else { return nil }
        let total = Int(b[4] >> 4), index = Int(b[4] & 0x0F)
        guard total > 1, (1...total).contains(index) else { return nil }
        return QNResultPart(index: index, total: total, bytes: b)
    }

    /// Two layouts exist. The newer one (this scale) has the state in byte 4 and the weight in
    /// bytes 5–6; only state 2 is final and carries the impedance.
    private static func weight(_ b: [UInt8], weightDivisor: Double) -> QNWeight? {
        let newLayout = b.count > 4 && b[4] <= 0x02 && weightDivisor == 10
        let reading: QNWeight
        if newLayout {
            guard b.count >= 11 else { return nil }
            reading = QNWeight(kg: Double(be16(b[5], b[6])) / weightDivisor, state: b[4], isStable: b[4] == 0x02,
                               r1: be16(b[7], b[8]), r2: be16(b[9], b[10]))
        } else {
            guard b.count >= 10 else { return nil }
            reading = QNWeight(kg: Double(be16(b[3], b[4])) / weightDivisor, state: b[5], isStable: b[5] == 0x01,
                               r1: be16(b[6], b[7]), r2: be16(b[8], b[9]))
        }
        var fixed = reading
        // Some firmwares report one more decimal than the 0x12 frame says.
        if fixed.kg <= 5 || fixed.kg >= 250 { fixed.kg /= 10 }
        return fixed
    }

    private static func be16(_ hi: UInt8, _ lo: UInt8) -> UInt16 { UInt16(hi) << 8 | UInt16(lo) }
    private static func le16(_ lo: UInt8, _ hi: UInt8) -> UInt16 { UInt16(hi) << 8 | UInt16(lo) }
}
