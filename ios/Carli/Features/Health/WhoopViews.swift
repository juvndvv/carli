import AuthenticationServices
import SwiftUI

struct WhoopRoute: Hashable {}

/// Opens WHOOP's consent page and reads the carli://health/whoop callback.
enum WhoopAuth {
    enum Outcome { case connected, failed(String), cancelled }

    static let errors = [
        "cancelado": "Has cancelado el permiso en WHOOP. No se ha conectado nada.",
        "estado": "El enlace de vuelta de WHOOP ha caducado o ya se había usado. Vuelve a intentarlo.",
        "otra": "Esa cuenta de WHOOP ya está conectada a otro usuario de carli.",
        "whoop": "WHOOP no ha podido completar la conexión. Inténtalo de nuevo en unos minutos.",
    ]

    static func outcome(_ callback: URL) -> Outcome {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            return .failed(errors[error] ?? errors["whoop"]!)
        }
        return items.contains { $0.name == "ok" } ? .connected : .failed(errors["estado"]!)
    }

    static func run(_ session: WebAuthenticationSession, url: URL) async -> Outcome {
        do {
            let callback = try await session.authenticate(using: url, callbackURLScheme: "carli", preferredBrowserSession: .shared)
            return outcome(callback)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return .cancelled
        } catch {
            return .failed(errors["whoop"]!)
        }
    }
}

/// "7 h 05 min", "6.214", "8,4" and WHOOP's recovery colours.
enum WhoopFormat {
    private static let spanish = Locale(identifier: "es_ES")

    static func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : String(format: "%d h %02d min", minutes / 60, minutes % 60)
    }

    static func integer(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic).locale(spanish))
    }

    static func decimal(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(spanish))
    }

    static func distance(_ meters: Double) -> String {
        meters >= 1000 ? "\(decimal(meters / 1000, digits: 2)) km" : "\(Int(meters.rounded())) m"
    }

    /// WHOOP's bands: green from 67 %, yellow from 34 %, red below.
    static func recoveryColor(_ score: Int) -> Color {
        switch score {
        case 67...: CarliColor.positive
        case 34..<67: CarliColor.warning
        default: CarliColor.negative
        }
    }

    static func sport(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "Entreno" }
        let known = [
            "running": "Correr", "cycling": "Ciclismo", "walking": "Caminar", "weightlifting": "Pesas",
            "functional-fitness": "Entreno funcional", "swimming": "Natación", "hiking/rucking": "Senderismo",
            "yoga": "Yoga", "padel": "Pádel", "tennis": "Tenis", "soccer": "Fútbol", "basketball": "Baloncesto",
            "hiit": "HIIT", "spin": "Spinning", "strength-trainer": "Fuerza", "activity": "Actividad",
        ]
        return known[name.lowercased()] ?? name.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }
}

// MARK: Resumen card

/// Salud › Resumen: today's recovery, night, strain and steps, or an invitation to connect WHOOP.
struct WhoopTodayCard: View {
    var status: WhoopStatus
    var day: WhoopDay?

    var body: some View {
        NavigationLink(value: WhoopRoute()) {
            CarliCard {
                VStack(alignment: .leading, spacing: CarliSpace.s12) {
                    CardHeader(title: "WHOOP", subtitle: subtitle, symbol: "waveform.path.ecg") { Chevron() }
                    if status.account == nil {
                        Text("Conecta tu pulsera para ver aquí la recuperación, el sueño, el esfuerzo y los pasos de cada día.")
                            .font(.subheadline)
                            .foregroundStyle(CarliColor.text2)
                    } else if let day {
                        WhoopTiles(day: day)
                    } else {
                        Text("Aún no hay datos. La primera copia puede tardar unos minutos.")
                            .font(.subheadline)
                            .foregroundStyle(CarliColor.text2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String? {
        if status.account?.needsReconnect == true { return "Hay que volver a conectarlo" }
        guard status.account != nil, let day, let date = CarliDate.day(day.date) else { return nil }
        return CarliDate.calendar.isDateInToday(date) ? "Hoy" : CarliDate.long(date)
    }
}

/// The four numbers of a day: recovery, sleep, strain and steps.
struct WhoopTiles: View {
    var day: WhoopDay

    var body: some View {
        HStack(alignment: .top, spacing: CarliSpace.s12) {
            tile("Recuperación", value: day.recovery?.score.map { "\($0) %" }, color: day.recovery?.score.map(WhoopFormat.recoveryColor))
            tile("Sueño", value: day.sleep?.asleepMinutes.map(WhoopFormat.duration))
            tile("Esfuerzo", value: day.strain?.strain.map { WhoopFormat.decimal($0) })
            tile("Pasos", value: day.strain?.steps.map(WhoopFormat.integer))
        }
    }

    private func tile(_ label: String, value: String?, color: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(CarliColor.text2).lineLimit(1).minimumScaleFactor(0.8)
            Text(value ?? "–")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(color ?? CarliColor.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: WHOOP page

/// Salud › WHOOP: the link to the band's account and the last weeks, day by day.
struct WhoopView: View {
    let api: APIClient

    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var status: WhoopStatus?
    @State private var days: [WhoopDay] = []
    @State private var failed: String?
    @State private var notice: String?
    @State private var busy = false
    @State private var confirmingDisconnect = false
    @State private var toast: String?

    var body: some View {
        List {
            if let notice {
                Section {
                    HStack(alignment: .top, spacing: CarliSpace.s8) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(CarliColor.text2)
                        Text(notice).font(.footnote).foregroundStyle(CarliColor.text)
                        Spacer()
                        Button("Cerrar aviso", systemImage: "xmark") { self.notice = nil }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                    }
                }
            }
            if let status {
                if !status.configured {
                    Section {
                        Label("Falta configurar WHOOP en el servidor (WHOOP_CLIENT_ID y WHOOP_CLIENT_SECRET).", systemImage: "wrench.and.screwdriver")
                            .font(.footnote)
                            .foregroundStyle(CarliColor.text2)
                    }
                } else if let account = status.account {
                    if account.needsReconnect {
                        Section {
                            Button { Task { await connect() } } label: {
                                Label("WHOOP ya no da acceso. Vuelve a conectarlo.", systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(CarliColor.negative)
                            }
                            .disabled(busy)
                        }
                    }
                    if days.isEmpty {
                        Section {
                            Text("Aún no hay datos de las últimas dos semanas.").foregroundStyle(CarliColor.text2)
                        }
                    }
                    ForEach(days) { daySections($0) }
                    accountSection(account)
                } else {
                    Section {
                        ContentUnavailableView {
                            Label("Conecta WHOOP", systemImage: "waveform.path.ecg")
                        } description: {
                            Text("carli copiará tu recuperación, sueño, esfuerzo, pasos y entrenos de los últimos 90 días y los mantendrá al día. Solo lectura: carli nunca cambia nada en WHOOP.")
                        } actions: {
                            Button("Conectar WHOOP") { Task { await connect() } }
                                .buttonStyle(.glassProminent)
                                .tint(CarliColor.primary)
                                .foregroundStyle(CarliColor.onPrimary)
                                .disabled(busy)
                        }
                    }
                }
            } else if let failed {
                ContentUnavailableView {
                    Label("No se ha podido cargar WHOOP", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("WHOOP")
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog("¿Desconectar WHOOP?", isPresented: $confirmingDisconnect, titleVisibility: .visible) {
            Button("Desconectar", role: .destructive) { Task { await disconnect() } }
        } message: {
            Text("carli deja de recibir datos nuevos. Lo ya copiado se queda aquí y en WHOOP no se borra nada.")
        }
        .carliToast($toast)
    }

    @ViewBuilder
    private func daySections(_ day: WhoopDay) -> some View {
        Section {
            WhoopTiles(day: day)
            if let recovery = day.recovery {
                if recovery.calibrating {
                    Text("WHOOP aún se está calibrando: la recuperación será más fiable en unos días.")
                        .font(.footnote).foregroundStyle(CarliColor.text2)
                }
                metric("VFC (HRV)", recovery.hrvMs.map { "\(WhoopFormat.decimal($0)) ms" })
                metric("Pulso en reposo", recovery.restingHeartRate.map { "\($0) ppm" })
                metric("Oxígeno en sangre", recovery.spo2.map { "\(WhoopFormat.decimal($0)) %" })
                metric("Temperatura de la piel", recovery.skinTempC.map { "\(WhoopFormat.decimal($0)) °C" })
            }
            if let sleep = day.sleep {
                metric("En la cama", sleep.inBedMinutes.map(WhoopFormat.duration))
                metric("Ligero · Profundo · REM", stages(sleep))
                metric("Rendimiento del sueño", sleep.performance.map { "\($0) %" })
                metric("Necesitabas", sleep.needMinutes.map(WhoopFormat.duration))
                metric("Frecuencia respiratoria", sleep.respiratoryRate.map { "\(WhoopFormat.decimal($0)) rpm" })
            }
            if day.napMinutes > 0 {
                metric("Siestas", WhoopFormat.duration(day.napMinutes))
            }
            if let strain = day.strain {
                metric("Calorías", strain.kcal.map { "\(WhoopFormat.integer($0)) kcal" })
                metric("Pulso medio · máximo", strain.averageHeartRate.map { avg in "\(avg) · \(strain.maxHeartRate.map(String.init) ?? "–") ppm" })
            }
            ForEach(day.workouts) { workout in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(WhoopFormat.sport(workout.sport)).font(.subheadline.weight(.semibold))
                        Spacer()
                        if let strain = workout.strain { Text("Esfuerzo \(WhoopFormat.decimal(strain))").font(.subheadline).monospacedDigit() }
                    }
                    Text(workoutLine(workout)).font(.footnote).foregroundStyle(CarliColor.text2)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text(title(day)).textCase(nil)
        } footer: {
            if day.strain?.inProgress == true {
                Text("El día de WHOOP va de despertar a despertar: el esfuerzo y los pasos de hoy siguen sumando.")
            }
        }
    }

    private func accountSection(_ account: WhoopAccountInfo) -> some View {
        Section {
            Button { Task { await sync() } } label: {
                Label("Actualizar ahora", systemImage: "arrow.clockwise")
            }
            .disabled(busy || account.needsReconnect)
            Button(role: .destructive) { confirmingDisconnect = true } label: {
                Label("Desconectar", systemImage: "xmark.circle")
            }
        } header: {
            Text(account.email ?? "Cuenta de WHOOP").textCase(nil)
        } footer: {
            if let error = account.lastError {
                Text(error)
            } else if let synced = account.syncedAt.flatMap(CarliDate.instant) {
                Text("Actualizado \(CarliDate.relative(synced)). Se actualiza solo cada hora y en cuanto WHOOP avisa de un cambio.")
            }
        }
    }

    private func metric(_ label: String, _ value: String?) -> some View {
        LabeledContent(label) {
            Text(value ?? "–").monospacedDigit().foregroundStyle(CarliColor.text)
        }
    }

    private func stages(_ sleep: WhoopSleep) -> String? {
        guard let light = sleep.lightMinutes, let deep = sleep.deepMinutes, let rem = sleep.remMinutes else { return nil }
        return [light, deep, rem].map(WhoopFormat.duration).joined(separator: " · ")
    }

    private func workoutLine(_ workout: WhoopWorkout) -> String {
        var parts: [String] = []
        if let start = CarliDate.instant(workout.startsAt), let end = CarliDate.instant(workout.endsAt) {
            parts.append(WhoopFormat.duration(Int(end.timeIntervalSince(start) / 60)))
        }
        if let distance = workout.distanceM, distance > 0 { parts.append(WhoopFormat.distance(distance)) }
        if let kcal = workout.kcal { parts.append("\(WhoopFormat.integer(kcal)) kcal") }
        if let avg = workout.averageHeartRate { parts.append("\(avg) ppm de media") }
        return parts.joined(separator: " · ")
    }

    private func title(_ day: WhoopDay) -> String {
        guard let date = CarliDate.day(day.date) else { return day.date }
        if CarliDate.calendar.isDateInToday(date) { return "Hoy" }
        if CarliDate.calendar.isDateInYesterday(date) { return "Ayer" }
        return CarliDate.long(date)
    }

    private func load() async {
        do {
            let loaded = try await WhoopAPI.status(api)
            if loaded.account != nil { days = try await WhoopAPI.days(api) }
            status = loaded
            failed = nil
        } catch {
            if status == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
    }

    private func connect() async {
        busy = true
        defer { busy = false }
        do {
            guard let url = try await WhoopAPI.authURL(api) else { return }
            switch await WhoopAuth.run(webAuth, url: url) {
            case .connected:
                notice = nil
                toast = "WHOOP conectado"
                NotificationCenter.default.post(name: .healthChanged, object: nil)
            case .failed(let message):
                notice = message
            case .cancelled:
                break
            }
            await load()
        } catch {
            notice = error.apiMessage(fallback: "No se ha podido empezar la conexión con WHOOP.")
        }
    }

    private func sync() async {
        busy = true
        defer { busy = false }
        do {
            try await WhoopAPI.sync(api)
            toast = "WHOOP actualizado"
        } catch {
            toast = error.apiMessage(fallback: "WHOOP no ha respondido. Se volverá a intentar en una hora.")
        }
        await load()
    }

    private func disconnect() async {
        do {
            try await WhoopAPI.disconnect(api)
            toast = "WHOOP desconectado"
            days = []
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido desconectar WHOOP.")
        }
        await load()
    }
}
