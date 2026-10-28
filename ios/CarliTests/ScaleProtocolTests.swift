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
