import Foundation
import Testing
@testable import Carli

struct HealthTests {
    private func decode<T: Decodable>(_ json: String) throws -> T {
        try APIClient.decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test func summaryDecodesTheServerPayload() throws {
        let summary: HealthSummary = try decode(#"""
        {"latest":{"id":"m1","measured_at":"2026-10-28T06:51:58+01:00","weight_kg":137.8,"source":"scale","fat_percent":48.2,"basal_kcal":1910,"impedances":[2920,2539]},
         "latest_with_metrics":null,"week_change":-1.2,"month_change":null,"goal_kg":120.0,"to_goal_kg":17.8,"weighed_today":true,"profile_complete":false}
        """#)
        #expect(summary.latest?.weightKg == 137.8)
        #expect(summary.latest?.fromScale == true)
        #expect(summary.latest?.date == HealthDate.parse("2026-10-28T05:51:58Z"))
        #expect(summary.weekChange == -1.2)
        #expect(summary.monthChange == nil)
        #expect(!summary.profileComplete)
    }

    @Test func profileFallsBackForTheScale() throws {
        let profile: HealthProfile = try decode(#"{"height_cm":175,"birth_date":"1990-05-01","sex":"female","goal_kg":null,"reminder_enabled":true,"reminder_time":"07:30","reminder_days":[1,3],"age":36}"#)
        #expect(profile.isComplete)
        #expect(profile.scaleProfile == QNProfile(heightCm: 175, age: 36, sex: .female))
        let empty: HealthProfile = try decode(#"{"height_cm":null,"birth_date":null,"sex":null,"goal_kg":null,"reminder_enabled":false,"reminder_time":"08:00","reminder_days":[1,2,3,4,5,6,7],"age":null}"#)
        #expect(!empty.isComplete)
        #expect(empty.scaleProfile.heightCm == 170)
    }

    @Test func scaleUploadCarriesTheRawFramesAndTheComposition() throws {
        let parts: [[UInt8]] = [
            [0x23, 0x01, 0x02, 0x01, 0x31, 0xAE, 0x03, 0x74, 0x32, 0x35, 0xD4, 0x0B, 0x68, 0x09, 0xEB, 0x0B, 0x3F, 0x09, 0xC6, 0x38],
            [0x23, 0x09, 0x92, 0x01, 0x32, 0x08, 0x0D, 0x09, 0x20, 0x07, 0xBA, 0x00, 0xD4, 0x00, 0xCA, 0x0B, 0x51, 0x09, 0xF8, 0xEB],
            [0x23, 0x0A, 0xEA, 0x01, 0x33, 0x09, 0xAE, 0x09, 0xB7, 0x08, 0x4E, 0x09, 0xAC, 0x08, 0x43, 0x01, 0x10, 0x01, 0x00, 0x2A],
        ]
        let metrics = QNMetrics([0x24, 0x13, 0xFF, 0x01, 0xC2, 0x01, 0x76, 0x01, 0xEB, 0x1A, 0x21, 0x07, 0x76, 0x00, 0x76, 0x01, 0xE2, 0x97, 0x04])
        let upload = ScaleUpload(result: QNResult(parts: parts, metrics: metrics), device: "QN-Scale", firmware: "V48.0")
        #expect(upload.stored)
        #expect(upload.weightKg == 137.8)
        #expect(upload.impedances.count == 20)
        #expect(upload.measuredAt == HealthDate.string(QN.date(scaleSeconds: 0x3274_03AE)))
        #expect(upload.metrics?.fatPercent == 48.2)
        #expect(upload.metricsFrame?.hasPrefix("24 13 FF") == true)
        #expect(upload.frames.components(separatedBy: " | ").count == 3)
    }

    @Test func liveResultsAreDatedWhenReceived() {
        let received = Date(timeIntervalSince1970: 1_800_000_000)
        let live = QNResult(parts: [[0x10, 0x14, 0x01, 0x02, 0x31, 0x35, 0xD4] + Array(repeating: 0, count: 13)], receivedAt: received)
        #expect(ScaleUpload(result: live, device: nil, firmware: nil).measuredAt == HealthDate.string(received))
    }

    @Test func weightFormats() {
        #expect(WeightFormat.kg(137.8) == "137,8 kg")
        #expect(WeightFormat.change(-1.2) == "−1,2 kg")
        #expect(WeightFormat.change(0.01) == "Sin cambios")
        #expect(BodyMetric.fat.format(48.2) == "48,2 %")
    }
}
