import SwiftUI

extension Notification.Name {
    /// Posted when a pending item is resolved here, so Inicio's card follows.
    static let pendingChanged = Notification.Name("carli.pendingChanged")
}

/// Pendientes: everything waiting for a decision, grouped by module and type, with inline actions.
@Observable
final class PendingModel {
    struct TypeGroup: Identifiable {
        var module: String
        var type: String
        var count: Int
        var route: String?
        var items: [PendingItem]
        var id: String { "\(module):\(type)" }
        var descriptor: PendingDescriptor { .of(module, type) }
    }

    struct ModuleGroup: Identifiable {
        var module: String
        var types: [TypeGroup]
        var id: String { module }
    }

    var summary: PendingSummary?
    var items: [PendingItem] = []
    var cursor: String?
    var loaded = false
    var failed: String?
    var loadingMore = false
    var loadMoreError: String?
    var module: String?
    var type: String?
    var categories: [FinanceCategory] = []
    var toast: String?
    var undo: UndoOffer?

    let api: APIClient
    private var generation = 0

    init(api: APIClient, module: String?, type: String?) {
        self.api = api
        self.module = module?.isEmpty == false ? module : nil
        self.type = type?.isEmpty == false ? type : nil
    }

    var isFiltered: Bool { module != nil || type != nil }

    var groups: [ModuleGroup] {
        var result: [ModuleGroup] = []
        for item in items {
            if !result.contains(where: { $0.module == item.module }) { result.append(ModuleGroup(module: item.module, types: [])) }
            let m = result.firstIndex { $0.module == item.module }!
            if let t = result[m].types.firstIndex(where: { $0.type == item.type }) {
                result[m].types[t].items.append(item)
            } else {
                let count = summary?.byModule.first { $0.module == item.module && $0.type == item.type }?.count ?? 0
                result[m].types.append(TypeGroup(module: item.module, type: item.type, count: count, route: item.route, items: [item]))
            }
        }
        for m in result.indices {
            for t in result[m].types.indices where result[m].types[t].items.count > result[m].types[t].count {
                result[m].types[t].count = result[m].types[t].items.count
            }
        }
        return result
    }

    func load() async {
        generation += 1
        let mine = generation
        var query: [String: String] = [:]
        if let module { query["module"] = module }
        if let type { query["type"] = type }
        do {
            let page: PendingPage = try await api.get("v1/pending", query: query)
            guard mine == generation else { return }
            items = page.data
            cursor = page.nextCursor
            failed = nil
            loadMoreError = nil
        } catch {
            guard mine == generation else { return }
            if items.isEmpty { failed = error.apiMessage(fallback: "Inténtalo de nuevo en unos segundos.") }
        }
        if let envelope: DataEnvelope<PendingSummary> = try? await api.get("v1/pending/summary") { summary = envelope.data }
        loaded = true
    }

    func loadMore() async {
        guard let cursor, !loadingMore else { return }
        loadingMore = true
        defer { loadingMore = false }
        var query = ["cursor": cursor]
        if let module { query["module"] = module }
        if let type { query["type"] = type }
        do {
            let page: PendingPage = try await api.get("v1/pending", query: query)
            let known = Set(items.map(\.id))
            items += page.data.filter { !known.contains($0.id) }
            self.cursor = page.nextCursor
            loadMoreError = nil
        } catch {
            loadMoreError = error.apiMessage(fallback: "No se han podido cargar más pendientes.")
        }
    }

    func select(module: String?, type: String?) {
        guard module != self.module || type != self.type else { return }
        self.module = module
        self.type = type
        items = []
        cursor = nil
        loaded = false
        Task { await load() }
    }

    /// Drops a handled item and its count, then tells Inicio.
    func resolve(_ item: PendingItem) {
        items.removeAll { $0.id == item.id }
        if var current = summary, let index = current.byModule.firstIndex(where: { $0.module == item.module && $0.type == item.type }) {
            current.total = max(0, current.total - 1)
            if current.byModule[index].count > 1 { current.byModule[index].count -= 1 } else { current.byModule.remove(at: index) }
            summary = current
        }
        NotificationCenter.default.post(name: .pendingChanged, object: nil)
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        if let envelope: DataEnvelope<[FinanceCategory]> = try? await api.get("v1/finance/categories") { categories = envelope.data }
    }

    func categoryName(_ id: String) -> String {
        for parent in categories {
            if parent.id == id { return parent.name }
            if let child = parent.children?.first(where: { $0.id == id }) { return child.name }
        }
        return "la categoría elegida"
    }

    // MARK: Actions

    func categorize(_ item: PendingItem, categoryId: String) async {
        let transactionId = item.meta("transaction_id") ?? item.itemId
        do {
            let _: Empty = try await api.patch("v1/finance/transactions/\(transactionId)", body: Patch(["category_id": .string(categoryId)]))
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido guardar la categoría.")
            return
        }
        resolve(item)
        NotificationCenter.default.post(name: .financeChanged, object: nil)
        let name = categoryName(categoryId)
        let message = "\(item.title) → \(name)"
        let fromBank = item.meta("source") == "bank"
        if fromBank {
            undo = UndoOffer(text: message) { [weak self] in
                guard let self else { return }
                do {
                    let _: Empty = try await api.patch("v1/finance/transactions/\(transactionId)", body: Patch(["category_id": .null]))
                    NotificationCenter.default.post(name: .financeChanged, object: nil)
                    await load()
                } catch {
                    toast = error.apiMessage(fallback: "No se ha podido deshacer.")
                }
            }
        } else {
            toast = message
        }
        let offer = await SimilarCategorization.offer(api: api, transactionId: transactionId, categoryId: categoryId,
                                                      categoryName: name) { [weak self] text in
            self?.toast = text
            Task { await self?.load() }
        }
        guard let offer else { return }
        if fromBank { try? await Task.sleep(for: .seconds(5)) }
        undo = offer
    }

    func recurringRule(_ item: PendingItem) async -> RecurringRule? {
        guard let ruleId = item.meta("rule_id") else { return nil }
        do {
            let envelope: DataEnvelope<RecurringRule> = try await api.get("v1/finance/recurring-rules/\(ruleId)")
            return envelope.data
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido cargar el recurrente.")
            return nil
        }
    }

    func answerTransfer(_ item: PendingItem, confirm: Bool) async {
        guard let outgoing = item.meta("outgoing_transaction_id"), let incoming = item.meta("incoming_transaction_id") else { return }
        let body = Patch(["outgoing_transaction_id": .string(outgoing), "incoming_transaction_id": .string(incoming)])
        do {
            let _: Empty = try await api.post("v1/finance/transfers/suggestions/\(confirm ? "confirm" : "dismiss")", body: body)
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido guardar la respuesta.")
            return
        }
        resolve(item)
        NotificationCenter.default.post(name: .financeChanged, object: nil)
        if confirm {
            undo = UndoOffer(text: "Guardada como transferencia") { [weak self] in
                guard let self else { return }
                do {
                    let _: Empty = try await api.post("v1/finance/transactions/\(outgoing)/undo-transfer", body: Patch([:]))
                    NotificationCenter.default.post(name: .financeChanged, object: nil)
                    await load()
                } catch {
                    toast = error.apiMessage(fallback: "No se ha podido deshacer.")
                }
            }
        } else {
            toast = "Entendido: no es una transferencia"
        }
    }

    enum OverdueAction { case done, today, skip }

    func overdue(_ item: PendingItem, _ action: OverdueAction) async {
        let taskId = item.meta("task_id") ?? item.itemId
        func post(_ path: String, _ body: Patch? = nil) async throws {
            if let body {
                let _: Empty = try await api.post("v1/tasks/tasks/\(taskId)/\(path)", body: body)
            } else {
                let _: Empty = try await api.post("v1/tasks/tasks/\(taskId)/\(path)")
            }
            NotificationCenter.default.post(name: .tasksChanged, object: nil)
        }
        do {
            switch action {
            case .done: try await post("complete")
            case .today: try await post("postpone", Patch(["date": .string(CarliDate.isoDay(.now))]))
            case .skip: try await post("skip")
            }
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido actualizar la tarea.")
            return
        }
        resolve(item)
        let text = switch action {
        case .done: "\(item.title) hecha"
        case .today: "\(item.title) pasa a hoy"
        case .skip: "\(item.title) omitida"
        }
        let originalDate = String(item.date.prefix(10))
        undo = UndoOffer(text: text) { [weak self] in
            guard let self else { return }
            do {
                switch action {
                case .done, .skip: try await post("reopen")
                case .today: try await post("postpone", Patch(["date": .string(originalDate)]))
                }
                await load()
            } catch {
                toast = error.apiMessage(fallback: "No se ha podido deshacer.")
            }
        }
    }
}

struct PendingView: View {
    @State var model: PendingModel
    @Environment(AppRouter.self) private var router
    @State private var categorizing: PendingItem?
    @State private var confirming: RecurringRule?
    @State private var confirmingItem: PendingItem?
    @State private var busy: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s16) {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(CarliColor.text2)
                    .padding(.horizontal, CarliSpace.s16)
                chips
                content.padding(.horizontal, CarliSpace.s16)
            }
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .navigationTitle("Pendientes")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await model.load() }
        .task { if !model.loaded { await model.load() } }
        .sheet(item: $categorizing) { item in
            NavigationStack {
                CategoryPickerView(categories: model.categories, kind: item.meta("kind") ?? "expense", selection: Binding(
                    get: { nil },
                    set: { picked in
                        guard let picked else { return }
                        Task { await model.categorize(item, categoryId: picked) }
                    }))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { categorizing = nil } }
                    }
            }
            .task { await model.loadCategories() }
        }
        .sheet(item: $confirming) { rule in
            ConfirmOccurrenceView(api: model.api, rule: rule) { message in
                model.toast = message
                if let item = confirmingItem { model.resolve(item) }
                NotificationCenter.default.post(name: .financeChanged, object: nil)
            }
        }
        .carliToast($model.toast)
        .undoBar($model.undo)
    }

    private var subtitle: String {
        guard let summary = model.summary else { return "Todo lo que requiere tu atención" }
        switch summary.total {
        case 0: return "Nada por revisar"
        case 1: return "1 elemento por revisar"
        default: return "\(summary.total) elementos por revisar"
        }
    }

    @ViewBuilder
    private var chips: some View {
        let entries = model.summary?.byModule ?? []
        if entries.count > 1 || model.isFiltered {
            ScrollView(.horizontal) {
                HStack(spacing: CarliSpace.s8) {
                    Chip(label: "Todo (\(model.summary?.total ?? 0))", selected: !model.isFiltered) {
                        model.select(module: nil, type: nil)
                    }
                    ForEach(entries) { entry in
                        let descriptor = PendingDescriptor.of(entry.module, entry.type)
                        Chip(label: "\(descriptor.label) (\(entry.count))", symbol: descriptor.symbol,
                             selected: model.module == entry.module && model.type == entry.type) {
                            model.select(module: entry.module, type: entry.type)
                        }
                    }
                }
                .padding(.horizontal, CarliSpace.s16)
            }
            .scrollIndicators(.hidden)
            .accessibilityLabel("Filtrar pendientes")
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.loaded {
            ProgressView().frame(maxWidth: .infinity).padding(.top, CarliSpace.s32)
        } else if let failed = model.failed {
            CarliCard {
                ContentUnavailableView {
                    Label("No se han podido cargar los pendientes", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await model.load() } }.buttonStyle(.glass)
                }
            }
        } else if model.items.isEmpty {
            CarliCard {
                if model.isFiltered {
                    ContentUnavailableView {
                        Label("Nada pendiente de este tipo", systemImage: "checkmark.circle")
                    } description: {
                        Text("Ya lo has revisado todo en esta sección.")
                    } actions: {
                        Button("Ver todos los pendientes") { model.select(module: nil, type: nil) }.buttonStyle(.glass)
                    }
                } else {
                    ContentUnavailableView("Todo al día", systemImage: "checkmark.circle",
                                           description: Text("Aquí aparecerá lo que necesite tu atención, como movimientos sin categoría o recurrentes por confirmar."))
                }
            }
        } else {
            let groups = model.groups
            let showHeads = groups.count > 1 || !model.isFiltered
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: CarliSpace.s12) {
                    if showHeads {
                        Label(PendingDescriptor.moduleName(group.module), systemImage: PendingDescriptor.moduleSymbol(group.module))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(CarliColor.text)
                            .padding(.leading, CarliSpace.s4)
                            .accessibilityAddTraits(.isHeader)
                    }
                    ForEach(group.types) { typeGroup in typeCard(typeGroup) }
                }
            }
            if let error = model.loadMoreError {
                Text(error).font(.footnote).foregroundStyle(CarliColor.negative).frame(maxWidth: .infinity)
            }
            if model.cursor != nil {
                Button {
                    Task { await model.loadMore() }
                } label: {
                    if model.loadingMore { ProgressView() } else { Text("Cargar más") }
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func typeCard(_ group: PendingModel.TypeGroup) -> some View {
        CarliCard(padding: 0) {
            HStack(spacing: CarliSpace.s8) {
                Text(group.descriptor.label)
                    .font(.headline)
                    .foregroundStyle(CarliColor.text)
                    .accessibilityAddTraits(.isHeader)
                Text("\(group.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .foregroundStyle(CarliColor.warning)
                    .background(CarliColor.warning.opacity(0.14), in: .capsule)
                Spacer()
                if canOpen(group.module) {
                    Button("Ver todos") { openRoute(group.module, group.route) }
                        .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.top, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s4)
            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().padding(.leading, CarliSpace.s16) }
                itemRow(item, group.descriptor)
            }
        }
    }

    private func itemRow(_ item: PendingItem, _ descriptor: PendingDescriptor) -> some View {
        VStack(alignment: .leading, spacing: CarliSpace.s8) {
            HStack(spacing: CarliSpace.s12) {
                Image(systemName: descriptor.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(CarliColor.text2)
                    .frame(width: 36, height: 36)
                    .background(CarliColor.surface2, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(CarliColor.text)
                        .lineLimit(2)
                    Text(item.subtitleLine)
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let amount = item.amountCents {
                    Text(Money.format(amount, descriptor.neutralAmount ? .absolute : .signed))
                        .font(.body.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(descriptor.neutralAmount ? CarliColor.text2 : amount > 0 ? CarliColor.positive : CarliColor.text)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .accessibilityElement(children: .combine)
            actions(item)
                .padding(.leading, 48)
        }
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, CarliSpace.s12)
    }

    @ViewBuilder
    private func actions(_ item: PendingItem) -> some View {
        let running = busy == item.id
        switch (item.module, item.type) {
        case ("finance", "uncategorized_transaction"):
            Button("Elegir categoría", systemImage: "tag") { categorizing = item }
                .buttonStyle(.glass)
                .controlSize(.small)
        case ("finance", "recurring_to_confirm"):
            Button {
                run(item) {
                    if let rule = await model.recurringRule(item) {
                        confirmingItem = item
                        confirming = rule
                    }
                }
            } label: {
                Label("Confirmar cargo", systemImage: "checkmark")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(running)
        case ("finance", "transfer_suggestion"):
            HStack(spacing: CarliSpace.s8) {
                Button("Confirmar", systemImage: "checkmark") { run(item) { await model.answerTransfer(item, confirm: true) } }
                    .buttonStyle(.glass)
                Button("No es transferencia", systemImage: "xmark") { run(item) { await model.answerTransfer(item, confirm: false) } }
                    .buttonStyle(.borderless)
                    .foregroundStyle(CarliColor.text2)
            }
            .controlSize(.small)
            .disabled(running)
        case ("tasks", "overdue_task"):
            HStack(spacing: CarliSpace.s8) {
                Button("Hecha") { run(item) { await model.overdue(item, .done) } }
                    .buttonStyle(.glassProminent)
                    .tint(CarliColor.primary)
                    .foregroundStyle(CarliColor.onPrimary)
                Button("Pasar a hoy") { run(item) { await model.overdue(item, .today) } }
                    .buttonStyle(.glass)
                Button("Omitir") { run(item) { await model.overdue(item, .skip) } }
                    .buttonStyle(.glass)
            }
            .controlSize(.small)
            .disabled(running)
        default:
            if canOpen(item.module) {
                Button("Revisar") { openRoute(item.module, item.route) }
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
        }
    }

    private func run(_ item: PendingItem, _ work: @escaping () async -> Void) {
        guard busy == nil else { return }
        busy = item.id
        Task {
            await work()
            busy = nil
        }
    }

    private func canOpen(_ module: String) -> Bool { module == "finance" || module == "tasks" }

    /// Finance routes open their screen with the matching filters; task routes fall back to Hoy.
    private func openRoute(_ module: String, _ route: String?) {
        if module == "tasks", !(route ?? "").hasPrefix("/tareas") {
            router.open(url: "/tareas/hoy")
        } else {
            router.open(url: route)
        }
    }
}
