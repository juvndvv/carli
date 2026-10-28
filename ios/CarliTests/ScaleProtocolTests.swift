import Foundation
import Testing
@testable import Carli

struct ScaleProtocolTests {
    private let seconds: UInt32 = 0x0102_0304
    private var date: Date { QN.date(scaleSeconds: seconds) }

    @Test func checksumIsTheByteSum() {
        #expect(QN.checksum([0xFF, 0x02]) == 0x01)
        #expect(QN.sealed([0x1F, 0x05, 0xFF, 0x10]) == [0x1F, 0x05, 0xFF, 0x10, 0x33])
    }

    @Test func configCarriesHeightAgeAndSex() {
        let frame = QNCommand.config(protocolType: 0xFF, profile: QNProfile(heightCm: 178, age: 35, sex: .male))
        #expect(frame == [0x13, 0x09, 0xFF, 0x01, 0x10, 0xB2, 0x23, 0x00, 0x01])
    }

    @Test func configClampsToTheScaleRange() {
        let frame = QNCommand.config(protocolType: 0xFF, profile: QNProfile(heightCm: 250, age: 90, sex: .female))
        #expect(Array(frame[5...7]) == [220, 80, 0x01])
    }

    @Test func timeFramesUseLittleEndianScaleSeconds() {
        #expect(QN.scaleSeconds(date) == seconds)
        #expect(QNCommand.timeSync(protocolType: 0xFF, date: date) == [0x20, 0x08, 0xFF, 0x04, 0x03, 0x02, 0x01, 0x31])
        #expect(QNCommand.clock(date) == [0x02, 0x04, 0x03, 0x02, 0x01])
    }

    @Test func historyQueryAndAck() {
        #expect(QNCommand.historyQuery(protocolType: 0xFF) == [0x22, 0x06, 0xFF, 0x00, 0x03, 0x2A])
        #expect(QNCommand.stableAck(protocolType: 0xFF) == [0x1F, 0x05, 0xFF, 0x10, 0x33])
    }

    @Test func infoFrameSetsTheWeightDivisor() {
        let hundred = QNParser.parse(QN.sealed([0x12, 0x0B, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0x01]), weightDivisor: 100)
        let ten = QNParser.parse(QN.sealed([0x12, 0x0B, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0x00]), weightDivisor: 100)
        #expect(hundred == .info(protocolType: 0xFF, weightDivisor: 100))
        #expect(ten == .info(protocolType: 0xFF, weightDivisor: 10))
    }

    @Test func stableWeightCarriesImpedance() throws {
        let event = QNParser.parse(QN.sealed([0x10, 0x0B, 0xFF, 0x01, 0x02, 0x1E, 0x0A, 0x10, 0xFE, 0x11, 0x94]),
                                   weightDivisor: 10)
        guard case .weight(let weight) = try #require(event) else { Issue.record("not a weight"); return }
        #expect(abs(weight.kg - 76.9) < 0.001)
        #expect(weight.isStable)
        #expect(weight.r1 == 4350 && weight.r2 == 4500)
        #expect(weight.impedanceOhm == 435)
    }

    @Test func weightWhileMeasuringIsNotStable() throws {
        let event = QNParser.parse(QN.sealed([0x10, 0x0B, 0xFF, 0x01, 0x01, 0x1E, 0x0A, 0, 0, 0, 0]), weightDivisor: 10)
        guard case .weight(let weight) = try #require(event) else { Issue.record("not a weight"); return }
        #expect(!weight.isStable)
    }

    @Test func olderLayoutKeepsWeightInBytesThreeAndFour() throws {
        let event = QNParser.parse(QN.sealed([0x10, 0x0A, 0x01, 0x1E, 0x0A, 0x01, 0x10, 0xFE, 0x11, 0x94]),
                                   weightDivisor: 100)
        guard case .weight(let weight) = try #require(event) else { Issue.record("not a weight"); return }
        #expect(abs(weight.kg - 76.9) < 0.001)
        #expect(weight.isStable)
        #expect(weight.r1 == 4350)
    }

    @Test func storedReadingHasItsOwnDate() throws {
        let bytes: [UInt8] = [0x23, 0x11, 0xFF, 0, 0, 0, 0x04, 0x03, 0x02, 0x01, 0x1E, 0x0A, 0x00, 0xFE, 0x10, 0x94, 0x11]
        let event = QNParser.parse(bytes, weightDivisor: 100)
        #expect(event == .stored(QNStoredReading(date: date, kg: 76.9, r1: 4350, r2: 4500)))
    }

    @Test func shortFramesAreIgnored() {
        #expect(QNParser.parse([0x10, 0x0B], weightDivisor: 10) == nil)
        #expect(QNParser.parse([0x10, 0x0B, 0xFF, 0x01, 0x02], weightDivisor: 10) == nil)
        #expect(QNParser.parse([0x14, 0x05, 0xFF], weightDivisor: 10) == .configAck)
    }
}

struct ScaleResultTests {
    /// The three frames Juanda's CS10G (firmware V48.0) sent at the end of a weigh-in on 2026-10-28;
    /// the display showed 137.8 kg.
    private let frames: [[UInt8]] = [
        [0x10, 0x14, 0x01, 0x02, 0x31, 0x35, 0xD4, 0x0B, 0x68, 0x09, 0xEB, 0x0B, 0x3F, 0x09, 0xC6, 0x09, 0x92, 0x08, 0x0D, 0x91],
        [0x10, 0x14, 0x09, 0x20, 0x32, 0x07, 0xBA, 0x00, 0xD4, 0x00, 0xCA, 0x0B, 0x51, 0x09, 0xF8, 0x0A, 0xEA, 0x09, 0xAE, 0xE6],
        [0x10, 0x14, 0x09, 0xB7, 0x33, 0x08, 0x4E, 0x09, 0xAC, 0x08, 0x43, 0x01, 0x10, 0x01, 0x00, 0x00, 0x00, 0x57, 0x00, 0xD6],
    ]

    @Test func realFramesHaveValidChecksums() {
        for frame in frames { #expect(QN.checksum(frame.dropLast()) == frame.last) }
    }

    @Test func resultFramesAreNotReadAsWeights() {
        let event = QNParser.parse(frames[2], weightDivisor: 10)
        #expect(event == .resultPart(QNResultPart(index: 3, total: 3, bytes: frames[2])))
    }

    @Test func assemblerWaitsForEveryPart() throws {
        var assembler = QNResultAssembler()
        var result: QNResult?
        for frame in frames {
            guard case .resultPart(let part) = QNParser.parse(frame, weightDivisor: 10) else {
                Issue.record("not a result part"); return
            }
            #expect(result == nil)
            result = assembler.add(part)
        }
        let full = try #require(result)
        #expect(full.parts == frames)
        #expect(full.kg == 137.8)
        #expect(full.impedances == [2920, 2539, 2879, 2502, 2450, 2061,
                                    2336, 1978, 212, 202, 2897, 2552, 2794, 2478,
                                    2487, 2126, 2476, 2115, 272, 256, 0, 22272])
    }
}

struct ScaleHistoryTests {
    /// History answer from the same scale on 2026-10-28: the 06:51 weigh-in (137.8 kg) and its 0x24.
    private let record: [[UInt8]] = [
        [0x23, 0x01, 0x02, 0x01, 0x31, 0xAE, 0x03, 0x74, 0x32, 0x35, 0xD4, 0x0B, 0x68, 0x09, 0xEB, 0x0B, 0x3F, 0x09, 0xC6, 0x38],
        [0x23, 0x09, 0x92, 0x01, 0x32, 0x08, 0x0D, 0x09, 0x20, 0x07, 0xBA, 0x00, 0xD4, 0x00, 0xCA, 0x0B, 0x51, 0x09, 0xF8, 0xEB],
        [0x23, 0x0A, 0xEA, 0x01, 0x33, 0x09, 0xAE, 0x09, 0xB7, 0x08, 0x4E, 0x09, 0xAC, 0x08, 0x43, 0x01, 0x10, 0x01, 0x00, 0x2A],
    ]
    private let metrics: [UInt8] = [0x24, 0x13, 0xFF, 0x01, 0xC2, 0x01, 0x76, 0x01, 0xEB, 0x1A, 0x21, 0x07, 0x76, 0x00, 0x76, 0x01, 0xE2, 0x97, 0x04]

    @Test func storedRecordMatchesTheLiveWeighIn() throws {
        var assembler = QNResultAssembler()
        var result: QNResult?
        for frame in record {
            #expect(QN.checksum(frame.dropLast()) == frame.last)
            guard case .resultPart(let part) = QNParser.parse(frame, weightDivisor: 10) else {
                Issue.record("not a stored part"); return
            }
            result = assembler.add(part)
        }
        let stored = try #require(result)
        #expect(stored.isStored)
        #expect(stored.kg == 137.8)
        #expect(stored.date == QN.date(scaleSeconds: 0x3274_03AE))
        // Same values the live frames carried for that weigh-in.
        #expect(stored.impedances == [2920, 2539, 2879, 2502, 2450, 2061,
                                      2336, 1978, 212, 202, 2897, 2552, 2794, 2478,
                                      2487, 2126, 2476, 2115, 272, 256])
    }

    @Test func metricsFrameMatchesTheDisplay() throws {
        #expect(QN.checksum(metrics.dropLast()) == metrics.last)
        guard case .metrics(let m) = QNParser.parse(metrics, weightDivisor: 10) else {
            Issue.record("not metrics"); return
        }
        #expect(m.bmi == 45.0)
        #expect(m.waterPercent == 37.4)
        #expect(m.musclePercent == 49.1)
        #expect(m.fatPercent == 48.2)
        #expect(m.visceralOrBone == 26)
        #expect(m.basalKcal == 1910)
    }

    @Test func emptyHistoryIsNotARecord() {
        let empty: [UInt8] = [0x23] + Array(repeating: 0, count: 18) + [0x23]
        #expect(QNParser.parse(empty, weightDivisor: 10) == .stored(QNStoredReading(date: QN.date(scaleSeconds: 0), kg: 0, r1: 0, r2: 0)))
    }
}
