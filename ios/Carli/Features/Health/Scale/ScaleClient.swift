import CoreBluetooth
import Foundation
import Observation

/// One weigh-in as it came from the scale, before the server works out body composition.
struct ScaleReading: Identifiable, Equatable {
    enum Source: String { case live = "en vivo", stored = "histórico" }

    let id = UUID()
    var date: Date
    var kg: Double
    var r1: UInt16
    var r2: UInt16
    var source: Source
    var frame: String

    var impedanceOhm: Double { Double(r1) / 10 }
}

/// Talks to the GE CS10G over Bluetooth: finds it, sends the profile, and collects weigh-ins.
/// Delegate callbacks arrive on the main queue.
@Observable
final class ScaleClient: NSObject {
    enum Phase: Equatable {
        case idle, scanning, connecting, connected
        case unavailable(String)

        var label: String {
            switch self {
            case .idle: "Parada"
            case .scanning: "Buscando la báscula… súbete para encenderla"
            case .connecting: "Conectando…"
            case .connected: "Conectada"
            case .unavailable(let reason): reason
            }
        }
    }

    struct LogLine: Identifiable {
        enum Kind: String { case received = "←", sent = "→", note = "·" }
        let id = UUID()
        let date: Date
        let kind: Kind
        let text: String
    }

    private(set) var phase: Phase = .idle
    private(set) var log: [LogLine] = []
    private(set) var deviceName: String?
    private(set) var manufacturer: String?
    private(set) var firmware: String?
    private(set) var live: QNWeight?
    private(set) var readings: [ScaleReading] = []
    private(set) var results: [QNResult] = []
    var profile: QNProfile

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var writer: CBCharacteristic?
    @ObservationIgnored private var running = false
    @ObservationIgnored private var protocolType: UInt8 = 0
    @ObservationIgnored private var weightDivisor: Double = 100
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var tookLiveReading = false
    @ObservationIgnored private var assembler = QNResultAssembler()

    init(profile: QNProfile) {
        self.profile = profile
    }

    func start() {
        running = true
        if let central {
            if central.state == .poweredOn { scan() }
        } else {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func stop() {
        running = false
        central?.stopScan()
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        phase = .idle
    }

    func requestHistory() {
        send(QNCommand.historyQuery(protocolType: protocolType))
    }

    func clearLog() {
        log.removeAll()
        readings.removeAll()
        results.removeAll()
        live = nil
    }

    /// Plain-text log to paste back for debugging.
    var transcript: String {
        let time = Date.FormatStyle().hour(.twoDigits(amPM: .omitted)).minute().second().secondFraction(.fractional(3))
        var lines = ["carli · báscula · \(deviceName ?? "?") · \(manufacturer ?? "?") · \(firmware ?? "?")",
                     "perfil: \(profile.heightCm) cm, \(profile.age) años, \(profile.sex == .male ? "hombre" : "mujer")"]
        lines += log.map { "[\($0.date.formatted(time))] \($0.kind.rawValue) \($0.text)" }
        return lines.joined(separator: "\n")
    }

    // MARK: Internals

    private func scan() {
        phase = .scanning
        note("Buscando…")
        central?.scanForPeripherals(withServices: nil)
    }

    private func resetSession() {
        writer = nil
        protocolType = 0
        weightDivisor = 100
        configured = false
        tookLiveReading = false
        assembler = QNResultAssembler()
    }

    private func note(_ text: String) {
        log.append(LogLine(date: .now, kind: .note, text: text))
    }

    private func send(_ bytes: [UInt8]) {
        guard let peripheral, let writer else {
            note("Sin conexión: no se envía \(QN.hex(bytes))")
            return
        }
        let type: CBCharacteristicWriteType = writer.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(Data(bytes), for: writer, type: type)
        log.append(LogLine(date: .now, kind: .sent, text: QN.hex(bytes)))
    }

    private func handle(_ bytes: [UInt8]) {
        log.append(LogLine(date: .now, kind: .received, text: QN.hex(bytes)))
        if protocolType == 0, bytes.count > 2 { protocolType = bytes[2] }
        guard let event = QNParser.parse(bytes, weightDivisor: weightDivisor) else { return }

        switch event {
        case .info(_, let divisor):
            weightDivisor = divisor
            guard !configured else { return }
            configured = true
            send(QNCommand.config(protocolType: protocolType, profile: profile))
            send(QNCommand.clock(.now))
        case .configAck:
            send(QNCommand.timeSync(protocolType: protocolType, date: .now))
        case .handshake:
            QNCommand.handshakeReplies.forEach(send)
            requestHistory()
        case .resultPart(let part):
            guard let result = assembler.add(part) else { return }
            results.insert(result, at: 0)
            note("Resultado completo (\(result.parts.count) tramas): \(result.impedances.map(String.init).joined(separator: " "))")
        case .weight(let weight):
            // Readings outside a person's range mean we misread the frame; keep them only in the log.
            guard (2...250).contains(weight.kg) else { return }
            live = weight
            guard weight.isStable else { return }
            if protocolType == 0xFF { send(QNCommand.stableAck(protocolType: protocolType)) }
            guard !tookLiveReading else { return }
            tookLiveReading = true
            readings.insert(ScaleReading(date: .now, kg: weight.kg, r1: weight.r1, r2: weight.r2,
                                         source: .live, frame: QN.hex(bytes)), at: 0)
            note(String(format: "Pesada estable: %.2f kg, r1 %d, r2 %d", weight.kg, weight.r1, weight.r2))
        case .stored(let stored):
            guard stored.kg > 2 else {
                note("La báscula no tiene pesadas guardadas")
                return
            }
            readings.insert(ScaleReading(date: stored.date, kg: stored.kg, r1: stored.r1, r2: stored.r2,
                                         source: .stored, frame: QN.hex(bytes)), at: 0)
            note(String(format: "Histórico: %.2f kg del %@", stored.kg, stored.date.formatted()))
        case .other:
            break
        }
    }
}

extension ScaleClient: @MainActor CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if running { scan() }
        case .unauthorized:
            phase = .unavailable("carli no tiene permiso de Bluetooth. Actívalo en Ajustes › carli.")
        case .poweredOff:
            phase = .unavailable("El Bluetooth está apagado.")
        case .unsupported:
            phase = .unavailable("Este dispositivo no tiene Bluetooth (el simulador tampoco).")
        default:
            phase = .unavailable("Bluetooth no disponible.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        let isScale = QN.names.contains(name.lowercased())
            || (!name.isEmpty && !QN.advertisedServices.isDisjoint(with: services) && name.lowercased().contains("scale"))
        guard isScale else { return }

        central.stopScan()
        deviceName = name
        var line = "Encontrada \(name) (\(RSSI) dBm) servicios \(services.joined(separator: ","))"
        if let data = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            line += " fabricante \(QN.hex(data))"
        }
        note(line)
        self.peripheral = peripheral
        peripheral.delegate = self
        phase = .connecting
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        resetSession()
        phase = .connected
        note("Conectada")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        note("No se pudo conectar: \(error?.localizedDescription ?? "sin detalle")")
        self.peripheral = nil
        if running { scan() } else { phase = .idle }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        note("Desconectada\(error.map { ": \($0.localizedDescription)" } ?? "")")
        self.peripheral = nil
        resetSession()
        if running { scan() } else { phase = .idle }
    }
}

extension ScaleClient: @MainActor CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid.uuidString {
            case QN.writeCharacteristic: writer = characteristic
            case "2A29", "2A26", "2A19": peripheral.readValue(for: characteristic)
            default: break
            }
            // Listen to every notifying characteristic (FFF1 and the vendor AE02) to find the live weight.
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            note("No se pudo suscribir a \(characteristic.uuid.uuidString): \(error.localizedDescription)")
        } else {
            note("Suscrita a \(characteristic.uuid.uuidString), esperando datos")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        switch characteristic.uuid.uuidString {
        case QN.notifyCharacteristic: handle([UInt8](data))
        case "2A19": note("Batería: \(data.first.map(String.init) ?? "?") %")
        case "2A29": manufacturer = String(decoding: data, as: UTF8.self)
        case "2A26": firmware = String(decoding: data, as: UTF8.self)
        default:
            log.append(LogLine(date: .now, kind: .received, text: "[\(characteristic.uuid.uuidString)] \(QN.hex(data))"))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error { note("Error al escribir: \(error.localizedDescription)") }
    }
}
