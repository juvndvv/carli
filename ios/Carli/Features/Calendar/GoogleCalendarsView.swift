import AuthenticationServices
import SwiftUI

/// Opens Google's consent page and reads the carli://calendar/google callback.
enum GoogleAuth {
    enum Outcome { case connected, failed(String), cancelled }

    static let errors = [
        "cancelado": "Has cancelado el permiso en Google. No se ha conectado nada.",
        "estado": "El enlace de vuelta de Google ha caducado o ya se había usado. Vuelve a intentarlo.",
        "permisos": "Google no ha dado permiso para ver el calendario. Vuelve a conectar y marca la casilla de Google Calendar.",
        "google": "Google no ha podido completar la conexión. Inténtalo de nuevo en unos minutos.",
    ]

    static func outcome(_ callback: URL) -> Outcome {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            return .failed(errors[error] ?? errors["google"]!)
        }
        return items.contains { $0.name == "account" } ? .connected : .failed(errors["estado"]!)
    }

    static func run(_ session: WebAuthenticationSession, url: URL) async -> Outcome {
        do {
            // Ephemeral, so Google asks which account every time (personal and work).
            let callback = try await session.authenticate(using: url, callbackURLScheme: "carli", preferredBrowserSession: .ephemeral)
            return outcome(callback)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return .cancelled
        } catch {
            return .failed(errors["google"]!)
        }
    }
}

/// Ajustes › Calendarios: linked Google accounts and which of their calendars carli shows.
struct GoogleCalendarsView: View {
    let api: APIClient

    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var overview: GoogleAccounts?
    @State private var failed: String?
    @State private var notice: String?
    @State private var busy: String?
    @State private var disconnecting: GoogleAccount?
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
            if let overview {
                if !overview.configured {
                    Section {
                        Label("Falta configurar Google en el servidor (GOOGLE_CLIENT_ID y GOOGLE_CLIENT_SECRET).", systemImage: "wrench.and.screwdriver")
                            .font(.footnote)
                            .foregroundStyle(CarliColor.text2)
                    }
                } else if overview.accounts.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("Conecta Google Calendar", systemImage: "calendar")
                        } description: {
                            Text("Tus eventos aparecerán en el Calendario de Inicio junto a tareas, cargos previstos y hábitos. Solo lectura: carli nunca cambia nada en Google.")
                        } actions: {
                            Button("Conectar cuenta de Google") { Task { await connect() } }
                                .buttonStyle(.glassProminent)
                                .tint(CarliColor.primary)
                                .foregroundStyle(CarliColor.onPrimary)
                        }
                    }
                }
                ForEach(overview.accounts) { account in
                    accountSection(account)
                }
                if overview.configured && !overview.accounts.isEmpty {
                    Section {
                        Button { Task { await connect() } } label: {
                            Label("Conectar otra cuenta", systemImage: "plus")
                        }
                        .disabled(busy != nil)
                    } footer: {
                        Text("Puedes conectar tu cuenta personal y la del trabajo. Si tu empresa bloquea apps externas, comparte ese calendario con tu cuenta personal y actívalo aquí.")
                    }
                }
            } else if let failed {
                ContentUnavailableView {
                    Label("No se han podido cargar los calendarios", systemImage: "exclamationmark.circle")
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
        .navigationTitle("Calendarios")
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog("¿Desconectar \(disconnecting?.email ?? "la cuenta")?", isPresented: Binding(
            get: { disconnecting != nil }, set: { if !$0 { disconnecting = nil } }), titleVisibility: .visible, presenting: disconnecting) { account in
            Button("Desconectar", role: .destructive) { Task { await disconnect(account) } }
        } message: { _ in
            Text("Sus eventos dejarán de verse en carli. En Google no se borra nada.")
        }
        .carliToast($toast)
    }

    private func accountSection(_ account: GoogleAccount) -> some View {
        Section {
            if account.needsReconnect {
                Button { Task { await connect() } } label: {
                    Label("Google ya no da acceso. Vuelve a conectar esta cuenta.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(CarliColor.negative)
                }
            }
            ForEach(account.calendars) { calendar in
                Toggle(isOn: Binding(get: { calendar.selected }, set: { on in Task { await toggle(calendar, on: on) } })) {
                    HStack(spacing: CarliSpace.s8) {
                        Circle().fill(calendar.tint ?? CarliColor.text3).frame(width: 10, height: 10)
                        Text(calendar.primary ? "Principal" : calendar.name)
                            .foregroundStyle(CarliColor.text)
                    }
                }
                .disabled(busy == calendar.id)
            }
            Button { Task { await sync(account) } } label: {
                Label("Actualizar ahora", systemImage: "arrow.clockwise")
            }
            .disabled(busy != nil || account.needsReconnect)
            Button(role: .destructive) { disconnecting = account } label: {
                Label("Desconectar", systemImage: "xmark.circle")
            }
        } header: {
            Text(account.email).textCase(nil)
        } footer: {
            if let error = account.lastError {
                Text(error)
            } else if let synced = account.syncedAt.flatMap(CarliDate.instant) {
                Text("Actualizado \(CarliDate.relative(synced)). Se actualiza solo cada 15 minutos.")
            }
        }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<GoogleAccounts> = try await api.get("v1/calendar/google/accounts")
            overview = envelope.data
            failed = nil
        } catch {
            if overview == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
    }

    private func connect() async {
        busy = "connect"
        defer { busy = nil }
        do {
            let envelope: DataEnvelope<GoogleAuthURL> = try await api.post("v1/calendar/google/accounts")
            guard let url = URL(string: envelope.data.authUrl) else { return }
            switch await GoogleAuth.run(webAuth, url: url) {
            case .connected:
                notice = nil
                toast = "Cuenta de Google conectada"
                NotificationCenter.default.post(name: .calendarChanged, object: nil)
            case .failed(let message):
                notice = message
            case .cancelled:
                break
            }
            await load()
        } catch {
            notice = error.apiMessage(fallback: "No se ha podido empezar la conexión con Google.")
        }
    }

    private func toggle(_ calendar: GoogleCalendarRef, on: Bool) async {
        busy = calendar.id
        defer { busy = nil }
        do {
            let _: DataEnvelope<GoogleCalendarRef> = try await api.patch("v1/calendar/google/calendars/\(calendar.id)", body: Patch(["selected": .bool(on)]))
            NotificationCenter.default.post(name: .calendarChanged, object: nil)
            await load()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido cambiar el calendario.")
        }
    }

    private func sync(_ account: GoogleAccount) async {
        busy = account.id
        defer { busy = nil }
        do {
            let _: DataEnvelope<GoogleAccount> = try await api.post("v1/calendar/google/accounts/\(account.id)/sync")
            toast = "Calendario actualizado"
            NotificationCenter.default.post(name: .calendarChanged, object: nil)
        } catch {
            toast = error.apiMessage(fallback: "Google no ha respondido. Se volverá a intentar en unos minutos.")
        }
        await load()
    }

    private func disconnect(_ account: GoogleAccount) async {
        do {
            try await api.delete("v1/calendar/google/accounts/\(account.id)")
            toast = "Cuenta desconectada"
            NotificationCenter.default.post(name: .calendarChanged, object: nil)
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido desconectar la cuenta.")
        }
        await load()
    }
}
