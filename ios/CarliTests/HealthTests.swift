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

    @Test func reminderCoversTheWeightUnlessSaidOtherwise() throws {
        let old: HealthProfile = try decode(#"{"reminder_enabled":true,"reminder_time":"07:30","reminder_days":[1]}"#)
        #expect(old.remindsWeight)
        #expect(!old.remindsBody)
        let both: HealthProfile = try decode(#"{"reminder_enabled":true,"reminder_time":"07:30","reminder_days":[1],"reminder_weight":false,"reminder_body":true}"#)
        #expect(!both.remindsWeight)
        #expect(both.remindsBody)
    }

    @Test func bodyOverviewDecodesTheServerPayload() throws {
        let overview: BodyOverview = try decode(#"""
        {"sites":[{"id":"s1","name":"Cintura","zone":"waist","side":null,"position":4,"archived":false,
                   "latest":{"id":"v2","site_id":"s1","measured_at":"2026-11-03T09:00:00+01:00","value_cm":114.5},
                   "baseline":{"id":"v1","site_id":"s1","measured_at":"2026-09-01T09:00:00+02:00","value_cm":120.4},
                   "change_cm":-5.9,"count":3},
                  {"id":"s2","name":"Brazo izquierdo","zone":"arm","side":"left","position":2,"archived":false,
                   "latest":null,"baseline":null,"change_cm":null,"count":0}],
         "last_measured_at":"2026-11-03T09:00:00+01:00","measured_today":true}
        """#)
        #expect(overview.sites[0].latest?.valueCm == 114.5)
        #expect(overview.sites[0].changeCm == -5.9)
        #expect(overview.sites[1].latest == nil)
        #expect(overview.measuredToday)
    }

    @Test func bodyZonesMirrorTheSidesOnTheViewer() {
        let right = BodyZone.arm.point(side: "right")
        let left = BodyZone.arm.point(side: "left")
        // Facing the viewer: the right arm is drawn on the left.
        #expect(right.x < 0.5)
        #expect(left.x == 1 - right.x)
        #expect(BodyZone.waist.point(side: nil).x == 0.5)
        #expect(BodyZone.neck.point(side: nil).y < BodyZone.ankle.point(side: nil).y)
    }

    @Test func bodyFormatsChangesAndParsesCommas() {
        #expect(BodyFormat.change(-2.06) == "−2,1")
        #expect(BodyFormat.change(0.4) == "+0,4")
        #expect(BodyFormat.change(0.01) == "=")
        #expect(BodyMeasureSheet.parse("84,5") == 84.5)
        #expect(BodyMeasureSheet.parse(" 90 ") == 90)
        #expect(BodyMeasureSheet.parse("abc") == nil)
        #expect(BodySiteEditor.zoneLabel(.wrist, side: "left") == "Muñeca izquierda")
        #expect(BodySiteEditor.zoneLabel(.waist, side: "left") == "Cintura")
    }

    @Test func whoopDayDecodesTheServerPayload() throws {
        let days: [WhoopDay] = try decode(#"""
        [{"date":"2026-11-04","nap_minutes":30,
          "recovery":{"state":"SCORED","calibrating":false,"score":74,"resting_heart_rate":52,"hrv_ms":61.234,"spo2":96.4,"skin_temp_c":33.7},
          "sleep":{"state":"SCORED","starts_at":"2026-11-03T23:40:00+01:00","ends_at":"2026-11-04T07:10:00+01:00","asleep_minutes":420,"in_bed_minutes":450,
                   "awake_minutes":30,"light_minutes":210,"deep_minutes":90,"rem_minutes":120,"need_minutes":482,"performance":92,"consistency":81,
                   "efficiency":93.3,"respiratory_rate":15.3,"disturbances":12},
          "strain":{"state":"SCORED","in_progress":true,"strain":8.4,"kcal":1981,"average_heart_rate":68,"max_heart_rate":141,"steps":6214},
          "workouts":[{"id":"w1","state":"SCORED","sport":"running","starts_at":"2026-11-04T08:00:00+01:00","ends_at":"2026-11-04T08:45:00+01:00",
                       "strain":11.2,"kcal":455,"average_heart_rate":148,"max_heart_rate":176,"distance_m":7210.5,"zone_minutes":[0,2,10,20,12,1]}]},
         {"date":"2026-11-03","nap_minutes":0,"recovery":null,"sleep":null,"workouts":[],
          "strain":{"state":"SCORED","in_progress":false,"strain":12.6,"kcal":2512,"average_heart_rate":72,"max_heart_rate":168,"steps":null}}]
        """#)
        #expect(days.map(\.id) == ["2026-11-04", "2026-11-03"])
        #expect(days[0].recovery?.hrvMs == 61.234)
        #expect(days[0].recovery?.skinTempC == 33.7)
        #expect(days[0].strain?.steps == 6214)
        #expect(days[0].workouts.first?.distanceM == 7210.5)
        #expect(days[1].strain?.steps == nil)
    }

    @Test func whoopFormatsAndCallbacks() {
        #expect(WhoopFormat.duration(420) == "7 h 00 min")
        #expect(WhoopFormat.duration(30) == "30 min")
        #expect(WhoopFormat.sport("running") == "Correr")
        #expect(WhoopFormat.sport("rowing") == "Rowing")
        if case .connected = WhoopAuth.outcome(URL(string: "carli://health/whoop?ok=1")!) {} else { Issue.record("expected connected") }
        if case .failed(let message) = WhoopAuth.outcome(URL(string: "carli://health/whoop?error=otra")!) {
            #expect(message.contains("otro usuario"))
        } else {
            Issue.record("expected failed")
        }
    }
}
