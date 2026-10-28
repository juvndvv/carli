import AuthenticationServices
import SwiftUI

struct BanksRoute: Hashable {}
struct BankLinkRoute: Hashable {
    var connectionId: String
    var renewed = false
}

struct Aspsp: Decodable, Identifiable, Hashable {
    var name: String
    var country: String
    var logo: String?
    var consentDays: Int?

    var id: String { "\(country):\(name)" }
    var subtitle: String {
        let consent = "Permiso de \(consentDays ?? 0) días"
        return country == "ES" ? consent : "\(country) · \(consent)"
    }
}

struct BankConnection: Decodable, Identifiable, Equatable {
    struct Linked: Decodable, Equatable, Identifiable {
        var id: String
        var name: String
        var syncFromDate: String?

        var label: String {
            guard let from = syncFromDate.flatMap(CarliDate.day) else { return name }
            let year = CarliDate.calendar.component(.year, from: from)
            return "\(name) · desde el \(CarliDate.short(from)) \(year)"
        }
    }

    var id: String
    var aspspName: String
    var status: String?
    var expiresInDays: Int?
    var lastSyncedAt: String?
    var lastError: String?
    var linkedAccounts: [Linked]?
    var lastSyncTransfers: Int?

    var linked: [Linked] { linkedAccounts ?? [] }

    struct State { var label: String; var tone: CarliBadge.Tone; var canSync: Bool; var canRenew: Bool; var healthy: Bool }

    var state: State {
        switch status {
        case "expired": return State(label: "Caducada", tone: .negative, canSync: false, canRenew: true, healthy: false)
        case "revoked": return State(label: "Desconectada", tone: .neutral, canSync: false, canRenew: false, healthy: false)
        case "error": return State(label: "Error", tone: .negative, canSync: true, canRenew: true, healthy: false)
        default:
            let days = expiresInDays ?? 90
            if days <= 7 {
                let label = days <= 0 ? "Caduca hoy" : days == 1 ? "Caduca mañana" : "Caduca en \(days) días"
                return State(label: label, tone: .warning, canSync: true, canRenew: true, healthy: false)
            }
            return State(label: "Activa", tone: .neutral, canSync: true, canRenew: true, healthy: true)
        }
    }

    var lastSyncLabel: String {
        guard let date = lastSyncedAt.flatMap(CarliDate.instant) else { return "Aún no se ha sincronizado" }
        return "Sincronizado \(CarliDate.dateTime(date))"
    }

    var syncedMessage: String {
        switch lastSyncTransfers ?? 0 {
        case 0: "\(aspspName) sincronizado"
        case 1: "\(aspspName) sincronizado · 1 transferencia entre tus cuentas detectada"
        case let count: "\(aspspName) sincronizado · \(count) transferencias entre tus cuentas detectadas"
        }
    }
}

struct CategoryRule: Decodable, Identifiable, Equatable {
    struct Category: Decodable, Equatable { var id: String?; var name: String; var icon: String? }
    var id: String
    var pattern: String
    var kind: String?
    var categoryId: String
    var category: Category?

    var label: String {
        let name = category?.name ?? "Categoría eliminada"
        return kind == "income" ? "\(name) · ingreso" : name
    }
}

/// Starts the bank's consent page and reads the carli:// callback.
enum BankAuth {
    enum Outcome { case completed(connectionId: String, renewed: Bool), failed(String), cancelled }

    static let errors = [
        "cancelado": "Has cancelado la autorización en el banco. No se ha conectado nada.",
        "estado": "El enlace de vuelta del banco ha caducado o ya se había usado. Vuelve a intentarlo.",
        "proveedor": "El banco no ha podido completar la conexión. Inténtalo de nuevo en unos minutos.",
    ]

    static func outcome(_ callback: URL) -> Outcome {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = value("error") { return .failed(errors[error] ?? "No se ha podido conectar el banco. Vuelve a intentarlo.") }
        guard let connection = value("connection") else { return .failed(errors["estado"]!) }
        return .completed(connectionId: connection, renewed: value("renovado") == "1")
    }

    static func run(_ session: WebAuthenticationSession, url: URL) async -> Outcome {
        do {
            let callback = try await session.authenticate(using: url, callbackURLScheme: "carli",
                                                          preferredBrowserSession: .ephemeral)
            return outcome(callback)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return .cancelled
        } catch {
            return .failed(errors["proveedor"]!)
        }
    }
}

private struct AuthURL: Decodable {
    struct Data: Decodable { var authUrl: String }
    var data: Data
}

/// Ajustes de Finanzas › Bancos: Enable Banking connections and categorisation rules.
struct BanksView: View {
    let api: APIClient
    var go: (FinanceRoute) -> Void

    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var connections: [BankConnection]?
    @State private var rules: [CategoryRule]?
    @State private var failed: String?
    @State private var callbackError: String?
    @State private var busy: String?
    @State private var choosingBank = false
    @State private var disconnecting: BankConnection?
    @State private var ruleQuery = ""
    @State private var linkRoute: BankLinkRoute?
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                if let callbackError {
                    HStack(alignment: .top, spacing: CarliSpace.s8) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(CarliColor.text2)
                        Text(callbackError).font(.footnote).foregroundStyle(CarliColor.text)
                        Spacer()
                        Button("Cerrar aviso", systemImage: "xmark") { self.callbackError = nil }.labelStyle(.iconOnly)
                    }
                    .padding(CarliSpace.s12)
                    .background(CarliColor.surface2, in: .rect(cornerRadius: 12))
                }
                if let connections {
                    if connections.isEmpty {
                        CarliCard {
                            ContentUnavailableView {
                                Label("Conecta tu banco", systemImage: "building.columns")
                            } description: {
                                Text("Importa los movimientos de Revolut, BBVA o MyInvestor automáticamente varias veces al día. Solo lectura: entran sin categoría y los revisas en Pendientes.")
                            } actions: {
                                Button("Conectar banco") { choosingBank = true }.buttonStyle(.glassProminent)
                            }
                        }
                    }
                    ForEach(connections) { connectionCard($0) }
                } else if let failed {
                    CardMessage(title: "No se han podido cargar los bancos", symbol: "exclamationmark.circle",
                                message: failed, action: "Reintentar") { Task { await load() } }
                } else {
                    CarliCard { SkeletonBar(width: 300, height: 120) }
                }
                rulesCard
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle("Bancos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Conectar banco", systemImage: "plus") { choosingBank = true }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .navigationDestination(item: $linkRoute) { route in
            BankLinkView(api: api, route: route) { toast = $0; Task { await load() } }
        }
        .sheet(isPresented: $choosingBank) {
            ChooseBankView(api: api) { aspsp in
                Task { await connect(aspsp) }
            }
        }
        .confirmationDialog("¿Desconectar \(disconnecting?.aspspName ?? "el banco")?", isPresented: Binding(
            get: { disconnecting != nil }, set: { if !$0 { disconnecting = nil } }), titleVisibility: .visible, presenting: disconnecting) { connection in
            Button("Desconectar", role: .destructive) { Task { await disconnect(connection) } }
        } message: { _ in
            Text("Se revoca el permiso de lectura en el banco y se dejan de importar movimientos. Los movimientos ya importados se conservan en tus cuentas.")
        }
        .carliToast($toast)
    }

    private func connectionCard(_ connection: BankConnection) -> some View {
        let state = connection.state
        return CarliCard {
            HStack(spacing: CarliSpace.s12) {
                IconBubble(symbol: "building.columns")
                VStack(alignment: .leading, spacing: 1) {
                    Text(connection.aspspName).font(.body.weight(.semibold)).foregroundStyle(CarliColor.text)
                    Text(connection.lastSyncLabel).font(.footnote).foregroundStyle(CarliColor.text3)
                }
                Spacer()
                CarliBadge(label: state.label, tone: state.tone)
            }
            VStack(alignment: .leading, spacing: CarliSpace.s4) {
                if connection.status == "error", let error = connection.lastError {
                    Text(error).font(.footnote).foregroundStyle(CarliColor.negative)
                }
                if connection.status == "expired" {
                    Text("El permiso del banco ha caducado. Renuévalo para seguir importando movimientos.")
                        .font(.footnote).foregroundStyle(CarliColor.text2)
                }
                if connection.linked.isEmpty {
                    Text("Ninguna cuenta vinculada: no se importa nada de este banco.")
                        .font(.footnote).foregroundStyle(CarliColor.text2)
                } else {
                    ForEach(connection.linked) { account in
                        NavigationLink(value: AccountLink(id: account.id)) {
                            Text(account.label).font(.footnote.weight(.medium)).foregroundStyle(CarliColor.brandInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, CarliSpace.s12)
            FlowButtons {
                if state.canSync {
                    Button("Sincronizar ahora", systemImage: "arrow.clockwise") { Task { await sync(connection) } }
                        .disabled(connection.linked.isEmpty || busy != nil)
                }
                if state.canRenew {
                    Button("Renovar", systemImage: "key") { Task { await renew(connection) } }
                        .disabled(busy != nil)
                }
                Button("Cuentas", systemImage: "link") { linkRoute = BankLinkRoute(connectionId: connection.id) }
                Button("Desconectar", systemImage: "trash") { disconnecting = connection }
                    .disabled(busy != nil)
            }
            .padding(.top, CarliSpace.s12)
            if busy == connection.id {
                ProgressView().padding(.top, CarliSpace.s8)
            }
        }
    }

    private var rulesCard: some View {
        CarliCard {
            Text("Reglas de categorización")
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .accessibilityAddTraits(.isHeader)
            Text("Los movimientos importados cuyo comercio o concepto contiene el texto de una regla entran ya categorizados y no pasan por Pendientes.")
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
                .padding(.top, CarliSpace.s4)
            if let rules {
                if rules.isEmpty {
                    Text("Aún no hay reglas. Al categorizar un movimiento importado te ofreceremos aplicarlo a los parecidos y recordarlo.")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text3)
                        .padding(.top, CarliSpace.s12)
                } else {
                    if rules.count > 8 {
                        TextField("Buscar regla", text: $ruleQuery)
                            .textFieldStyle(.roundedBorder)
                            .padding(.top, CarliSpace.s12)
                    }
                    let visible = visibleRules(rules)
                    ForEach(visible) { rule in
                        HStack(spacing: CarliSpace.s12) {
                            IconBubble(symbol: CarliIcon.symbol(rule.category?.icon ?? "tag"), size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(rule.pattern).foregroundStyle(CarliColor.text)
                                Text(rule.label).font(.footnote).foregroundStyle(CarliColor.text2)
                            }
                            Spacer()
                            Button("Eliminar la regla \(rule.pattern)", systemImage: "trash") { Task { await deleteRule(rule) } }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.glass)
                                .controlSize(.small)
                        }
                        .padding(.top, CarliSpace.s12)
                    }
                    if visible.isEmpty {
                        Text("Ninguna regla coincide con «\(ruleQuery)».").font(.footnote).foregroundStyle(CarliColor.text3)
                            .padding(.top, CarliSpace.s12)
                    }
                }
            } else {
                SkeletonBar(width: 220, height: 16).padding(.top, CarliSpace.s12)
            }
        }
    }

    private func visibleRules(_ rules: [CategoryRule]) -> [CategoryRule] {
        let query = ruleQuery.trimmingCharacters(in: .whitespaces).uppercased()
        guard !query.isEmpty else { return rules }
        return rules.filter { $0.pattern.uppercased().contains(query) || $0.label.uppercased().contains(query) }
    }

    private func load() async {
        do {
            let list: DataEnvelope<[BankConnection]> = try await api.get("v1/finance/bank/connections")
            connections = list.data
            failed = nil
        } catch {
            if connections == nil { failed = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
        if let list: DataEnvelope<[CategoryRule]> = try? await api.get("v1/finance/category-rules") { rules = list.data }
    }

    private struct ConnectBody: Encodable {
        var aspspName: String
        var aspspCountry: String
        var returnTo = "app"
    }

    private func connect(_ aspsp: Aspsp) async {
        do {
            let auth: AuthURL = try await api.post("v1/finance/bank/connections",
                                                   body: ConnectBody(aspspName: aspsp.name, aspspCountry: aspsp.country))
            await authorize(auth.data.authUrl)
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido iniciar la conexión con el banco.")
        }
    }

    private func renew(_ connection: BankConnection) async {
        busy = connection.id
        defer { busy = nil }
        do {
            let auth: AuthURL = try await api.post("v1/finance/bank/connections/\(connection.id)/renew", body: ["return_to": "app"])
            await authorize(auth.data.authUrl)
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido renovar el permiso del banco.")
        }
    }

    private func authorize(_ link: String) async {
        guard let url = URL(string: link) else { return }
        switch await BankAuth.run(webAuth, url: url) {
        case .completed(let id, let renewed):
            await load()
            linkRoute = BankLinkRoute(connectionId: id, renewed: renewed)
        case .failed(let message):
            callbackError = message
        case .cancelled:
            break
        }
    }

    private struct Queued: Decodable {
        struct Data: Decodable { var queued: Bool? }
        var data: Data
    }

    private func sync(_ connection: BankConnection) async {
        busy = connection.id
        defer { busy = nil }
        do {
            let result: Queued = try await api.post("v1/finance/bank/connections/\(connection.id)/sync", body: [String: String]())
            toast = result.data.queued == true ? "Sincronizando \(connection.aspspName)…" : "\(connection.aspspName) ya se está sincronizando…"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido sincronizar el banco.")
            return
        }
        if let current = await BankSync.waitForSync(api: api, before: connection) {
            toast = current.status == "error" ? (current.lastError ?? "No se ha podido sincronizar \(current.aspspName).") : current.syncedMessage
        }
        await load()
    }

    private func disconnect(_ connection: BankConnection) async {
        busy = connection.id
        defer { busy = nil }
        do {
            try await api.delete("v1/finance/bank/connections/\(connection.id)")
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            toast = "\(connection.aspspName) desconectado · los movimientos importados se conservan"
            await load()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido desconectar el banco.")
        }
    }

    private func deleteRule(_ rule: CategoryRule) async {
        do {
            try await api.delete("v1/finance/category-rules/\(rule.id)")
            toast = "Regla «\(rule.pattern)» eliminada"
            await load()
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido eliminar la regla.")
        }
    }
}

/// Polls a connection until its sync finishes (or ~30 s pass), then refreshes finance screens.
enum BankSync {
    static func waitForSync(api: APIClient, before: BankConnection) async -> BankConnection? {
        for _ in 0..<10 {
            try? await Task.sleep(for: .seconds(3))
            guard let current: DataEnvelope<BankConnection> = try? await api.get("v1/finance/bank/connections/\(before.id)") else { continue }
            let after = current.data
            if after.lastSyncedAt != before.lastSyncedAt || after.status != before.status || after.lastError != before.lastError {
                NotificationCenter.default.post(name: .financeChanged, object: nil)
                return after
            }
        }
        NotificationCenter.default.post(name: .financeChanged, object: nil)
        return nil
    }
}

/// Small glass buttons that wrap onto as many lines as needed.
struct FlowButtons<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        FlowLayout(spacing: CarliSpace.s8) { content }
            .buttonStyle(.glass)
            .controlSize(.small)
    }
}

/// Lays children out in rows, wrapping to a new row when the next one doesn't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// Bank picker: Spanish banks plus Revolut (Lithuania).
struct ChooseBankView: View {
    let api: APIClient
    var pick: (Aspsp) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var aspsps: [Aspsp]?
    @State private var failed: String?
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Solo lectura: la app nunca puede mover tu dinero. Te llevaremos a la web de tu banco para que autorices el acceso. Al volver, eliges a qué cuenta va cada una y desde qué fecha importar movimientos.")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                }
                if let failed {
                    Text(failed).foregroundStyle(CarliColor.negative)
                } else if let aspsps {
                    let visible = aspsps.filter { query.isEmpty || $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                        .contains(query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)) }
                    if visible.isEmpty {
                        Text("No hay bancos que coincidan con «\(query)».").foregroundStyle(CarliColor.text3)
                    }
                    ForEach(visible) { aspsp in
                        Button {
                            dismiss()
                            pick(aspsp)
                        } label: {
                            HStack(spacing: CarliSpace.s12) {
                                IconBubble(symbol: "building.columns", size: 34)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(aspsp.name).foregroundStyle(CarliColor.text)
                                    Text(aspsp.subtitle).font(.footnote).foregroundStyle(CarliColor.text2)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .searchable(text: $query, prompt: "Buscar banco")
            .navigationTitle("Conectar banco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            let home: DataEnvelope<[Aspsp]> = try await api.get("v1/finance/bank/aspsps", query: ["country": "ES"])
            var all = home.data
            if let lithuania: DataEnvelope<[Aspsp]> = try? await api.get("v1/finance/bank/aspsps", query: ["country": "LT"]) {
                let seen = Set(all.map(\.id))
                all += lithuania.data.filter { $0.name.localizedCaseInsensitiveContains("revolut") && !seen.contains($0.id) }
            }
            aspsps = all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            failed = error.apiMessage(fallback: "No se ha podido cargar la lista de bancos.")
        }
    }
}

struct BankAccountCandidate: Decodable, Identifiable, Equatable {
    struct Linked: Decodable, Equatable { var id: String; var name: String?; var syncFromDate: String? }
    var externalAccountUid: String
    var name: String?
    var iban: String?
    var currency: String?
    var suggestedAccountType: String?
    var linkedAccount: Linked?
    var shortName: String?
    var suggestedName: String?

    var id: String { externalAccountUid }
    var kind: AccountKind { AccountKind(rawValue: suggestedAccountType ?? "") ?? .checking }
    var isEuro: Bool { currency == nil || currency?.uppercased() == "EUR" }

    var title: String {
        let value = (shortName ?? name)?.trimmingCharacters(in: .whitespaces)
        return value?.isEmpty == false ? value! : kind.label
    }

    var subtitle: String {
        var parts: [String] = []
        if let iban, !iban.isEmpty {
            let compact = iban.replacingOccurrences(of: " ", with: "")
            parts.append(compact.count <= 4 ? compact : "•••• \(compact.suffix(4))")
        }
        if let currency { parts.append(currency) }
        if let linked = linkedAccount?.name { parts.append("vinculada a \(linked)") }
        return parts.joined(separator: " · ")
    }

    func defaultName(bank: String) -> String {
        if let suggested = suggestedName?.trimmingCharacters(in: .whitespaces), !suggested.isEmpty { return suggested }
        if let name = name?.trimmingCharacters(in: .whitespaces), !name.isEmpty { return "\(bank) \(name)" }
        return "\(bank) \(kind.label.lowercased())"
    }
}

/// After authorising: which app account each bank account feeds, and from which date.
struct BankLinkView: View {
    static let newAccount = "new"

    struct Row: Identifiable {
        var candidate: BankAccountCandidate
        var target: String?
        var name: String
        var kind: AccountKind
        var from: Date
        var id: String { candidate.id }
    }

    let api: APIClient
    let route: BankLinkRoute
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var connection: BankConnection?
    @State private var rows: [Row] = []
    @State private var accounts: [FinanceAccount] = []
    @State private var loading = true
    @State private var failed: String?
    @State private var saving = false
    @State private var error: String?

    private var duplicates: Set<String> {
        var seen = Set<String>(), duplicated = Set<String>()
        for target in rows.compactMap(\.target) where target != Self.newAccount {
            if !seen.insert(target).inserted { duplicated.insert(target) }
        }
        return duplicated
    }

    var body: some View {
        Form {
            if route.renewed {
                Section {
                    Label("Permiso renovado. Tus cuentas siguen vinculadas; revisa que todo esté bien y guarda.",
                          systemImage: "checkmark.circle")
                        .foregroundStyle(CarliColor.positive)
                }
            }
            if let failed {
                Section {
                    ContentUnavailableView("No se han podido cargar las cuentas", systemImage: "exclamationmark.triangle",
                                           description: Text(failed))
                }
            } else if loading {
                Section { ProgressView() }
            } else if rows.isEmpty {
                Section {
                    ContentUnavailableView("El banco no ha devuelto cuentas", systemImage: "building.columns",
                                           description: Text("Puede que no hayas autorizado ninguna. Renueva la conexión y elige las cuentas en el banco."))
                }
            } else {
                Section {
                    Text("Elige a qué cuenta de la app va cada cuenta del banco. Los movimientos se importan desde la fecha que indiques: si ya apuntaste a mano los anteriores, deja la de hoy para no duplicarlos.")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                }
                ForEach($rows) { $row in
                    Section {
                        Picker("Vincular con", selection: $row.target) {
                            Label("Crear cuenta nueva", systemImage: "plus").tag(Optional(Self.newAccount))
                            ForEach(selectable) { account in
                                Text(accountOptionLabel(account)).tag(Optional(account.id))
                            }
                            Label("No importar", systemImage: "eye.slash").tag(String?.none)
                        }
                        if let target = row.target, duplicates.contains(target) {
                            Text("Esta cuenta ya está elegida para otra cuenta del banco.").font(.footnote).foregroundStyle(CarliColor.negative)
                        }
                        if row.target != nil {
                            DatePicker("Importar desde", selection: $row.from, in: ...Date.now, displayedComponents: .date)
                        }
                        if row.target == Self.newAccount {
                            TextField("Nombre de la cuenta nueva", text: $row.name)
                            Picker("Tipo", selection: $row.kind) {
                                ForEach(AccountKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.candidate.title).font(.subheadline.weight(.semibold)).foregroundStyle(CarliColor.text)
                            Text(row.candidate.subtitle).font(.caption)
                        }
                        .textCase(nil)
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
        }
        .navigationTitle(connection.map { "Vincular cuentas de \($0.aspspName)" } ?? "Vincular cuentas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !rows.isEmpty {
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Guardar y sincronizar") { Task { await save() } }.disabled(!duplicates.isEmpty)
                    }
                }
            }
        }
        .task { await load() }
    }

    private var selectable: [FinanceAccount] {
        accounts.filter { !$0.isArchived && ($0.type != "cash" || $0.bank != nil) }
    }

    private func accountOptionLabel(_ account: FinanceAccount) -> String {
        if let bank = account.bank, !(connection?.linked.contains { $0.id == account.id } ?? false) {
            return "\(account.name) (ya vinculada a \(bank.aspspName ?? "otro banco"))"
        }
        return account.name
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let current: DataEnvelope<BankConnection> = try await api.get("v1/finance/bank/connections/\(route.connectionId)")
            let candidates: DataEnvelope<[BankAccountCandidate]> = try await api.get("v1/finance/bank/connections/\(route.connectionId)/accounts")
            if let page: AccountsPage = try? await api.get("v1/finance/accounts") { accounts = page.data }
            connection = current.data
            let unlinked = current.data.linked.isEmpty && !route.renewed ? Self.newAccount : nil
            rows = candidates.data.map { candidate in
                Row(candidate: candidate,
                    target: candidate.linkedAccount?.id ?? (candidate.isEuro ? unlinked : nil),
                    name: candidate.defaultName(bank: current.data.aspspName),
                    kind: candidate.kind,
                    from: candidate.linkedAccount?.syncFromDate.flatMap(CarliDate.day) ?? .now)
            }
        } catch {
            failed = error.apiMessage(fallback: "Vuelve a la lista de bancos e inténtalo de nuevo.")
        }
    }

    private struct LinkItem: Encodable {
        var externalAccountUid: String
        var accountId: String?
        var syncFromDate: String?
        var name: String?
        var type: String?

        private enum CodingKeys: String, CodingKey { case externalAccountUid, accountId, syncFromDate, name, type }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(externalAccountUid, forKey: .externalAccountUid)
            try container.encode(accountId, forKey: .accountId)
            try container.encodeIfPresent(syncFromDate, forKey: .syncFromDate)
            if accountId == BankLinkView.newAccount {
                try container.encode(name, forKey: .name)
                try container.encode(type, forKey: .type)
            }
        }
    }

    private func save() async {
        guard duplicates.isEmpty else { return }
        let items = rows.map { row -> LinkItem in
            guard let target = row.target else { return LinkItem(externalAccountUid: row.candidate.externalAccountUid) }
            let name = row.name.trimmingCharacters(in: .whitespaces)
            return LinkItem(externalAccountUid: row.candidate.externalAccountUid, accountId: target,
                            syncFromDate: CarliDate.isoDay(min(row.from, .now)),
                            name: name.isEmpty ? nil : name, type: row.kind.rawValue)
        }
        saving = true
        error = nil
        defer { saving = false }
        do {
            let result: DataEnvelope<BankConnection> = try await api.post("v1/finance/bank/connections/\(route.connectionId)/accounts",
                                                                         body: ["accounts": items])
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            let linked = items.filter { $0.accountId != nil }.count
            if linked > 0 {
                let before = result.data
                Task { _ = await BankSync.waitForSync(api: api, before: before) }
            }
            onDone(linked == 0 ? "\(result.data.aspspName): no se importará ninguna cuenta"
                   : "\(result.data.aspspName) vinculado · importando movimientos")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se han podido vincular las cuentas.")
        }
    }
}
