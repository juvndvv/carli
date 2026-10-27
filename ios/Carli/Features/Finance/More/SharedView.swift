import SwiftUI

struct FinanceContact: Decodable, Identifiable, Equatable {
    var id: String
    var name: String
    var notes: String?
    var archived: Bool?
    var balanceCents: Int
    var sharesPendingCents: Int
    var owedToMeCents: Int
    var iOweCents: Int

    private enum CodingKeys: String, CodingKey {
        case id, name, notes, archived, balanceCents, sharesPendingCents, owedToMeCents, iOweCents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        balanceCents = try container.decodeIfPresent(Int.self, forKey: .balanceCents) ?? 0
        sharesPendingCents = try container.decodeIfPresent(Int.self, forKey: .sharesPendingCents) ?? 0
        owedToMeCents = try container.decodeIfPresent(Int.self, forKey: .owedToMeCents) ?? 0
        iOweCents = try container.decodeIfPresent(Int.self, forKey: .iOweCents) ?? 0
    }

    var isArchived: Bool { archived == true }

    var summary: String {
        var parts: [String] = []
        if sharesPendingCents > 0 { parts.append("\(Money.format(sharesPendingCents)) en gastos sin liquidar") }
        if owedToMeCents > 0 { parts.append("te debe \(Money.format(owedToMeCents)) en préstamos") }
        if iOweCents > 0 { parts.append("le debes \(Money.format(iOweCents)) en préstamos") }
        guard !parts.isEmpty else { return "Sin nada pendiente" }
        return parts.joined(separator: " · ").capitalizedFirst
    }
}

struct ContactsOverview: Decodable {
    struct Meta: Decodable {
        var owedToMeCents: Int?
        var iOweCents: Int?
    }

    var data: [FinanceContact]
    var meta: Meta?
}

struct ContactShare: Decodable, Identifiable, Equatable {
    var id: String
    var date: String
    var payee: String?
    var description: String?
    var transactionAmountCents: Int?
    var amountCents: Int
    var settled: Bool?

    var title: String {
        if let payee, !payee.isEmpty { return payee }
        if let description, !description.isEmpty { return description }
        return "Gasto compartido"
    }
}

struct ContactDebt: Decodable, Identifiable, Equatable {
    var id: String
    var name: String?
    var direction: String?
    var pendingCents: Int
    var dueDate: String?
    var closed: Bool?
}

struct ContactDetail: Decodable {
    var contact: FinanceContact
    var shares: [ContactShare]
    var debts: [ContactDebt]

    var deletable: Bool { shares.isEmpty && debts.isEmpty }

    private enum CodingKeys: String, CodingKey { case shares, debts }

    init(from decoder: Decoder) throws {
        contact = try FinanceContact(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shares = try container.decodeIfPresent([ContactShare].self, forKey: .shares) ?? []
        debts = try container.decodeIfPresent([ContactDebt].self, forKey: .debts) ?? []
    }
}

struct ContactRoute: Hashable { var id: String }

@Observable
final class SharedModel {
    enum State { case loading, loaded, failed(String) }

    var state: State = .loading
    var overview: ContactsOverview?
    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        do {
            overview = try await api.get("v1/finance/contacts")
            state = .loaded
        } catch {
            if overview == nil { state = .failed(error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.")) }
        }
    }
}

private func peopleLabel(_ count: Int) -> String {
    switch count {
    case 0: "Nadie"
    case 1: "1 persona"
    default: "\(count) personas"
    }
}

/// Más › Compartidos: who owes you from shared expenses, and settling up.
struct SharedView: View {
    @State var model: SharedModel
    @State private var adding = false
    @State private var settling: FinanceContact?
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                switch model.state {
                case .loading:
                    CarliCard { SkeletonBar(width: 200, height: 40) }
                    CarliCard { SkeletonBar(width: 300, height: 120) }
                case .failed(let message):
                    CardMessage(title: "No se han podido cargar los contactos", symbol: "exclamationmark.circle",
                                message: message, action: "Reintentar") { Task { await model.load() } }
                case .loaded:
                    if let overview = model.overview { content(overview) }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle("Compartidos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nuevo contacto", systemImage: "person.badge.plus") { adding = true }
            }
        }
        .refreshable { await model.load() }
        .task { if model.overview == nil { await model.load() } }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in Task { await model.load() } }
        .sheet(isPresented: $adding) {
            ContactFormView(api: model.api, detail: nil) { toast = $0 }
        }
        .sheet(item: $settling) { contact in
            SettleView(api: model.api, contact: contact) { toast = $0 }
        }
        .carliToast($toast)
    }

    @ViewBuilder
    private func content(_ overview: ContactsOverview) -> some View {
        Grid(horizontalSpacing: CarliSpace.s12) {
            GridRow {
                StatCard(label: "Te deben", value: Money.format(overview.meta?.owedToMeCents ?? 0), valueColor: CarliColor.positive,
                         note: peopleLabel(overview.data.filter { $0.balanceCents > 0 }.count))
                StatCard(label: "Debes", value: Money.format(overview.meta?.iOweCents ?? 0),
                         note: peopleLabel(overview.data.filter { $0.balanceCents < 0 }.count))
            }
        }
        CarliCard(padding: 0) {
            Text("Gastos compartidos")
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .accessibilityAddTraits(.isHeader)
                .padding([.horizontal, .top], CarliSpace.s16)
                .padding(.bottom, CarliSpace.s8)
            if overview.data.isEmpty {
                ContentUnavailableView {
                    Label("Aún no compartes gastos", systemImage: "person.2")
                } description: {
                    Text("Añade a las personas con las que compartes gastos. Al registrar un gasto podrás repartirlo con ellas.")
                } actions: {
                    Button("Nuevo contacto") { adding = true }.buttonStyle(.glass)
                }
            } else {
                ForEach(Array(overview.data.enumerated()), id: \.element.id) { index, contact in
                    if index > 0 { Divider().padding(.leading, 64) }
                    HStack(spacing: CarliSpace.s8) {
                        NavigationLink(value: ContactRoute(id: contact.id)) {
                            HStack(spacing: CarliSpace.s12) {
                                Avatar(name: contact.name)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(contact.name).font(.body.weight(.medium)).foregroundStyle(CarliColor.text).lineLimit(1)
                                    Text(contact.summary).font(.footnote).foregroundStyle(CarliColor.text2)
                                }
                                Spacer(minLength: CarliSpace.s8)
                                Text(DebtsCopy.balance(contact.balanceCents))
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(contact.balanceCents > 0 ? CarliColor.positive
                                                     : contact.balanceCents == 0 ? CarliColor.text2 : CarliColor.text)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        if contact.sharesPendingCents > 0 {
                            Button("Liquidar") { settling = contact }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                                .accessibilityLabel("Liquidar con \(contact.name)")
                        }
                    }
                    .padding(.horizontal, CarliSpace.s16)
                    .padding(.vertical, CarliSpace.s12)
                }
            }
        }
        .padding(.bottom, CarliSpace.s8)
    }
}

/// One contact: balance breakdown, shared expenses and loans.
struct ContactDetailView: View {
    let api: APIClient
    let contactId: String

    @Environment(\.dismiss) private var dismiss
    @State private var detail: ContactDetail?
    @State private var failed = false
    @State private var editing = false
    @State private var settling = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                if let detail {
                    content(detail)
                } else if failed {
                    CardMessage(title: "No encontramos este contacto", symbol: "exclamationmark.circle",
                                message: "Puede que se haya eliminado.", action: "Volver a compartidos") { dismiss() }
                } else {
                    CarliCard { SkeletonBar(width: 220, height: 60) }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle(detail?.contact.name ?? "Contacto")
        .toolbar {
            if let detail {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Editar contacto", systemImage: "pencil") { editing = true }
                }
                if detail.contact.sharesPendingCents > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Liquidar", systemImage: "checkmark") { settling = true }
                    }
                }
            }
        }
        .refreshable { await load() }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in Task { await load() } }
        .sheet(isPresented: $editing) {
            if let detail {
                ContactFormView(api: api, detail: detail, onDeleted: { dismiss() }) { toast = $0 }
            }
        }
        .sheet(isPresented: $settling) {
            if let detail {
                SettleView(api: api, contact: detail.contact) { toast = $0 }
            }
        }
        .carliToast($toast)
    }

    @ViewBuilder
    private func content(_ detail: ContactDetail) -> some View {
        let contact = detail.contact
        CarliCard {
            HStack(spacing: CarliSpace.s12) {
                Avatar(name: contact.name, size: 48)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Saldo").font(.footnote).foregroundStyle(CarliColor.text2)
                    Text(DebtsCopy.balance(contact.balanceCents))
                        .font(.system(size: 28, weight: .bold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(contact.balanceCents > 0 ? CarliColor.positive : CarliColor.text)
                }
                Spacer()
                if contact.isArchived { CarliBadge(label: "Archivado", symbol: "archivebox") }
            }
            Divider().padding(.vertical, CarliSpace.s12)
            breakdown("Gastos compartidos sin liquidar", contact.sharesPendingCents)
            if contact.owedToMeCents > 0 { breakdown("Préstamos que te debe", contact.owedToMeCents) }
            if contact.iOweCents > 0 { breakdown("Préstamos que le debes", contact.iOweCents) }
            if let notes = contact.notes, !notes.isEmpty {
                Text(notes).font(.footnote).foregroundStyle(CarliColor.text2).padding(.top, CarliSpace.s8)
            }
        }

        CarliCard(padding: 0) {
            Text("Gastos compartidos")
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .accessibilityAddTraits(.isHeader)
                .padding([.horizontal, .top], CarliSpace.s16)
                .padding(.bottom, CarliSpace.s8)
            if detail.shares.isEmpty {
                ContentUnavailableView("Sin gastos compartidos", systemImage: "person.2",
                                       description: Text("Al registrar un gasto, actívale “Gasto compartido” y elige a \(contact.name)."))
            } else {
                ForEach(Array(detail.shares.enumerated()), id: \.element.id) { index, share in
                    if index > 0 { Divider().padding(.leading, 68) }
                    HStack(spacing: CarliSpace.s12) {
                        IconBubble(symbol: share.settled == true ? "checkmark" : "receipt")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(share.title).font(.body.weight(.medium)).foregroundStyle(CarliColor.text).lineLimit(1)
                            Text("\(CarliDate.dayTitle(share.date)) · total \(Money.format(abs(share.transactionAmountCents ?? 0)))")
                                .font(.footnote).foregroundStyle(CarliColor.text2).lineLimit(1)
                            CarliBadge(label: share.settled == true ? "Liquidado" : "Pendiente",
                                       symbol: share.settled == true ? "checkmark" : "clock")
                        }
                        Spacer()
                        Text(Money.format(share.amountCents, .signed))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(share.settled == true ? CarliColor.text2 : CarliColor.positive)
                    }
                    .padding(.horizontal, CarliSpace.s16)
                    .padding(.vertical, CarliSpace.s8)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.bottom, CarliSpace.s8)

        if !detail.debts.isEmpty {
            CarliCard(padding: 0) {
                HStack {
                    Text("Préstamos")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(CarliColor.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    NavigationLink("Deudas", value: FinanceMorePage.debts)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CarliColor.brandInk)
                }
                .padding([.horizontal, .top], CarliSpace.s16)
                .padding(.bottom, CarliSpace.s8)
                ForEach(detail.debts) { debt in
                    let owesMe = debt.direction == "owed_to_me"
                    HStack(spacing: CarliSpace.s12) {
                        IconBubble(symbol: owesMe ? "arrow.down.left" : "arrow.up.right")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(debt.name ?? "").foregroundStyle(CarliColor.text)
                            Text(debtSubtitle(debt, owesMe: owesMe)).font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                        Spacer()
                        Text(Money.format(debt.pendingCents))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(debt.closed == true ? CarliColor.text2 : owesMe ? CarliColor.positive : CarliColor.text)
                    }
                    .padding(.horizontal, CarliSpace.s16)
                    .padding(.vertical, CarliSpace.s8)
                }
            }
            .padding(.bottom, CarliSpace.s8)
        }
    }

    private func breakdown(_ label: String, _ cents: Int) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(CarliColor.text2)
            Spacer()
            Text(Money.format(cents)).font(.footnote).monospacedDigit().foregroundStyle(CarliColor.text)
        }
        .padding(.vertical, 2)
    }

    private func debtSubtitle(_ debt: ContactDebt, owesMe: Bool) -> String {
        var parts = [owesMe ? "Te deben" : "Debes"]
        if debt.closed == true {
            parts.append("saldada")
        } else if let due = debt.dueDate.flatMap(CarliDate.day) {
            parts.append("vence \(CarliDate.short(due))")
        }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<ContactDetail> = try await api.get("v1/finance/contacts/\(contactId)")
            detail = envelope.data
        } catch {
            if detail == nil { failed = true }
        }
    }
}

/// New / edit contact; archive or delete when editing.
struct ContactFormView: View {
    let api: APIClient
    let detail: ContactDetail?
    var onDeleted: (() -> Void)?
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var notes: String
    @State private var saving = false
    @State private var error: String?

    init(api: APIClient, detail: ContactDetail?, onDeleted: (() -> Void)? = nil, onSaved: @escaping (String) -> Void) {
        self.api = api
        self.detail = detail
        self.onDeleted = onDeleted
        self.onSaved = onSaved
        _name = State(initialValue: detail?.contact.name ?? "")
        _notes = State(initialValue: detail?.contact.notes ?? "")
    }

    private struct Payload: Encodable {
        var name: String
        var notes: String?

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(notes, forKey: .notes)
        }

        private enum CodingKeys: String, CodingKey { case name, notes }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre (Ana, Piso compartido…)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Notas (opcional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } footer: {
                    if detail == nil { Text("Solo necesitas un nombre; no tendrá acceso a la app.") }
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
                if let contact = detail?.contact {
                    Section {
                        Button(contact.isArchived ? "Desarchivar" : "Archivar", systemImage: "archivebox") {
                            Task { await setArchived(!contact.isArchived, contact) }
                        }
                        if detail?.deletable == true {
                            Button("Eliminar contacto", systemImage: "trash", role: .destructive) {
                                Task { await delete(contact) }
                            }
                        }
                    }
                }
            }
            .navigationTitle(detail == nil ? "Nuevo contacto" : "Editar contacto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button(detail == nil ? "Añadir" : "Guardar", role: .confirm) { Task { await save() } }
                            .disabled(trimmed.isEmpty || trimmed.count > 120)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        let note = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = Payload(name: trimmed, notes: note.isEmpty ? nil : note)
        do {
            if let contact = detail?.contact {
                let _: Empty = try await api.patch("v1/finance/contacts/\(contact.id)", body: body)
                onSaved("Contacto actualizado")
            } else {
                let _: Empty = try await api.post("v1/finance/contacts", body: body)
                onSaved("\(trimmed) añadido")
            }
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar el contacto.")
        }
    }

    private func setArchived(_ archived: Bool, _ contact: FinanceContact) async {
        do {
            let _: Empty = try await api.patch("v1/finance/contacts/\(contact.id)", body: ["archived": archived])
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            onSaved(archived ? "\(contact.name) archivado" : "\(contact.name) vuelve a estar activo")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido archivar el contacto.")
        }
    }

    private func delete(_ contact: FinanceContact) async {
        do {
            try await api.delete("v1/finance/contacts/\(contact.id)")
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            onSaved("\(contact.name) eliminado")
            dismiss()
            onDeleted?()
        } catch {
            self.error = error.apiMessage(fallback: "Este contacto tiene gastos o deudas: archívalo en su lugar.")
        }
    }
}

/// Records the contact paying back their pending shared expenses.
struct SettleView: View {
    let api: APIClient
    let contact: FinanceContact
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [FinanceAccount] = []
    @State private var accountId: String?
    @State private var date = Date.now
    @State private var saving = false
    @State private var error: String?

    private var effectiveAccountId: String? { accountId ?? DebtsCopy.preferredAccount(accounts) }

    private struct Payload: Encodable {
        var accountId: String
        var date: String
    }

    private struct Result: Decodable {
        struct Data: Decodable { var netCents: Int? }
        var data: Data
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: CarliSpace.s4) {
                        Text("\(contact.name) te paga").font(.footnote).foregroundStyle(CarliColor.text2)
                        Text(Money.format(contact.sharesPendingCents, .signed))
                            .font(.system(size: 34, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(CarliColor.positive)
                    }
                    .frame(maxWidth: .infinity)
                } footer: {
                    Text("Registra el cobro de los gastos compartidos pendientes.")
                }
                Section {
                    Picker("Cuenta donde lo recibes", selection: Binding(get: { effectiveAccountId }, set: { accountId = $0 })) {
                        if effectiveAccountId == nil { Text("Elige una cuenta").tag(String?.none) }
                        ForEach(accounts.filter { !$0.isArchived }) { account in
                            Label(account.name, systemImage: account.symbol).tag(Optional(account.id))
                        }
                    }
                    DatePicker("Fecha", selection: $date, in: ...Date.now, displayedComponents: .date)
                } footer: {
                    VStack(alignment: .leading, spacing: CarliSpace.s4) {
                        Text("Se crea un ingreso que no cuenta como ingreso del periodo: solo te devuelve lo que adelantaste.")
                        if contact.iOweCents > 0 || contact.owedToMeCents > 0 {
                            Text("Las deudas con \(contact.name) se gestionan aparte, en Deudas.")
                        }
                    }
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle("Liquidar con \(contact.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Registrar cobro", role: .confirm) { Task { await settle() } }
                            .disabled(effectiveAccountId == nil)
                    }
                }
            }
            .task {
                if let page: AccountsPage = try? await api.get("v1/finance/accounts") { accounts = page.data }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func settle() async {
        guard let accountId = effectiveAccountId else {
            error = "Elige la cuenta donde recibes el dinero."
            return
        }
        saving = true
        error = nil
        defer { saving = false }
        do {
            let result: Result = try await api.post("v1/finance/contacts/\(contact.id)/settle",
                                                    body: Payload(accountId: accountId, date: CarliDate.isoDay(date)))
            NotificationCenter.default.post(name: .financeChanged, object: nil)
            let name = accounts.first { $0.id == accountId }?.name
            onDone("Liquidado con \(contact.name): \(Money.format(result.data.netCents ?? contact.sharesPendingCents, .signed))\(name.map { " en \($0)" } ?? "")")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido liquidar.")
        }
    }
}
