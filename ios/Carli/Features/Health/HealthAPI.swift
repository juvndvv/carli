import Foundation

/// Calls to /v1/health.
enum HealthAPI {
    static func summary(_ api: APIClient) async throws -> HealthSummary {
        let envelope: DataEnvelope<HealthSummary> = try await api.get("v1/health/summary")
        return envelope.data
    }

    static func measurements(_ api: APIClient, from: Date? = nil) async throws -> [BodyMeasurement] {
        let query = from.map { ["from": HealthDate.day($0)] } ?? [:]
        let envelope: DataEnvelope<[BodyMeasurement]> = try await api.get("v1/health/measurements", query: query)
        return envelope.data
    }

    static func measurement(_ api: APIClient, id: String) async throws -> BodyMeasurement {
        let envelope: DataEnvelope<BodyMeasurement> = try await api.get("v1/health/measurements/\(id)")
        return envelope.data
    }

    static func delete(_ api: APIClient, id: String) async throws {
        try await api.delete("v1/health/measurements/\(id)")
        NotificationCenter.default.post(name: .healthChanged, object: nil)
    }

    static func addManual(_ api: APIClient, kg: Double, at date: Date) async throws {
        struct Body: Encodable { var weightKg: Double; var measuredAt: String }
        let _: DataEnvelope<BodyMeasurement> = try await api.post("v1/health/measurements",
                                                                  body: Body(weightKg: kg, measuredAt: HealthDate.string(date)))
        NotificationCenter.default.post(name: .healthChanged, object: nil)
    }

    static func profile(_ api: APIClient) async throws -> HealthProfile {
        let envelope: DataEnvelope<HealthProfile> = try await api.get("v1/health/settings")
        return envelope.data
    }

    static func saveProfile(_ api: APIClient, _ fields: [String: JSONValue]) async throws -> HealthProfile {
        let envelope: DataEnvelope<HealthProfile> = try await api.put("v1/health/settings", body: Patch(fields))
        NotificationCenter.default.post(name: .healthChanged, object: nil)
        return envelope.data
    }

    /// Uploads scale results; the server merges the live and stored copies of each weigh-in.
    static func sync(_ api: APIClient, _ results: [QNResult], device: String?, firmware: String?) async throws {
        let readings = results.filter { (2...250).contains($0.kg) }.map { ScaleUpload(result: $0, device: device, firmware: firmware) }
        guard !readings.isEmpty else { return }
        struct Body: Encodable { var readings: [ScaleUpload] }
        struct Counts: Decodable { var created: Int; var updated: Int }
        let _: DataEnvelope<Counts> = try await api.post("v1/health/measurements/sync", body: Body(readings: readings))
        NotificationCenter.default.post(name: .healthChanged, object: nil)
    }
}

/// Calls to /v1/health/body: tape measurements of the body.
enum BodyAPI {
    static func overview(_ api: APIClient, compare: BodyCompare) async throws -> BodyOverview {
        let envelope: DataEnvelope<BodyOverview> = try await api.get("v1/health/body", query: ["compare": compare.query])
        return envelope.data
    }

    static func sites(_ api: APIClient, archived: Bool = false) async throws -> [BodySite] {
        let envelope: DataEnvelope<[BodySite]> = try await api.get("v1/health/body/sites", query: archived ? ["archived": "1"] : [:])
        return envelope.data
    }

    static func history(_ api: APIClient, site: String, from: Date? = nil) async throws -> [SiteValue] {
        let query = from.map { ["from": HealthDate.day($0)] } ?? [:]
        let envelope: DataEnvelope<[SiteValue]> = try await api.get("v1/health/body/sites/\(site)/measurements", query: query)
        return envelope.data
    }

    struct SiteFields: Encodable {
        var name: String
        var zone: String
        var side: String?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(zone, forKey: .zone)
            // Explicit null, so editing a site to a centre zone clears its side.
            try container.encode(side, forKey: .side)
        }

        private enum CodingKeys: String, CodingKey { case name, zone, side }
    }

    @discardableResult
    static func createSite(_ api: APIClient, _ fields: SiteFields) async throws -> BodySite {
        let envelope: DataEnvelope<BodySite> = try await api.post("v1/health/body/sites", body: fields)
        NotificationCenter.default.post(name: .healthChanged, object: nil)
        return envelope.data
    }

    @discardableResult
    static func updateSite(_ api: APIClient, id: String, _ fields: SiteFields) async throws -> BodySite {
        let envelope: DataEnvelope<BodySite> = try await api.patch("v1/health/body/sites/\(id)", body: fields)
        NotificationCenter.default.post(name: .healthChanged, object: nil)
        return envelope.data
    }

    static func archive(_ api: APIClient, id: String, _ archived: Bool) async throws {
        struct Body: Encodable { var archived: Bool }
        let _: DataEnvelope<BodySite> = try await api.patch("v1/health/body/sites/\(id)", body: Body(archived: archived))
        NotificationCenter.default.post(name: .healthChanged, object: nil)
    }

    static func reorder(_ api: APIClient, ids: [String]) async throws {
        struct Body: Encodable { var ids: [String] }
        let _: Empty = try await api.put("v1/health/body/sites/order", body: Body(ids: ids))
        NotificationCenter.default.post(name: .healthChanged, object: nil)
    }

    static func deleteSite(_ api: APIClient, id: String) async throws {
        try await api.delete("v1/health/body/sites/\(id)")
        NotificationCenter.default.post(name: .healthChanged, object: nil)
    }

    /// One session with the tape: every value shares the same moment.
    static func record(_ api: APIClient, values: [(site: String, cm: Double)], at date: Date) async throws {
        struct Value: Encodable { var siteId: String; var valueCm: Double }
        struct Body: Encodable { var measuredAt: String; var values: [Value] }
        let body = Body(measuredAt: HealthDate.string(date), values: values.map { Value(siteId: $0.site, valueCm: $0.cm) })
        let _: DataEnvelope<[SiteValue]> = try await api.post("v1/health/body/measurements", body: body)
        NotificationCenter.default.post(name: .healthChanged, object: nil)
    }

    static func deleteValue(_ api: APIClient, id: String) async throws {
        try await api.delete("v1/health/body/measurements/\(id)")
        NotificationCenter.default.post(name: .healthChanged, object: nil)
    }
}

/// One scale result as the sync endpoint takes it: the decoded values plus the raw frames.
struct ScaleUpload: Encodable {
    struct Metrics: Encodable {
        var bmi: Double
        var fatPercent: Double
        var musclePercent: Double
        var waterPercent: Double
        var visceralOrBone: Int
        var basalKcal: Int
    }

    var measuredAt: String
    var weightKg: Double
    var stored: Bool
    var impedances: [Int]
    var frames: String
    var device: String?
    var firmware: String?
    var metrics: Metrics?
    var metricsFrame: String?

    init(result: QNResult, device: String?, firmware: String?) {
        measuredAt = HealthDate.string(result.date ?? result.receivedAt)
        weightKg = result.kg
        stored = result.isStored
        impedances = result.impedances.map(Int.init)
        frames = result.parts.map(QN.hex).joined(separator: " | ")
        self.device = device
        self.firmware = firmware
        if let m = result.metrics {
            metrics = Metrics(bmi: m.bmi, fatPercent: m.fatPercent, musclePercent: m.musclePercent,
                              waterPercent: m.waterPercent, visceralOrBone: m.visceralOrBone, basalKcal: m.basalKcal)
            metricsFrame = QN.hex(m.bytes)
        }
    }
}
