import SwiftUI

/// Compra: the primary shopping list (or the one picked in the header), grouped by supermarket section.
struct ShoppingSectionView: View {
    var store: NotesStore
    @Binding var selected: String?
    var focusRequest: Int

    var body: some View {
        Group {
            if let snapshot = store.snapshot {
                let lists = snapshot.shoppingNotes
                if let note = lists.first(where: { $0.id == selected }) ?? snapshot.primaryShopping {
                    ShoppingListView(store: store, noteId: note.id, switchable: true, selected: $selected, focusRequest: focusRequest)
                        .id(note.id)
                } else {
                    ContentUnavailableView {
                        Label("Tu lista de la compra", systemImage: "cart")
                    } description: {
                        Text("Por secciones del súper, con lo que sueles comprar y productos que vuelven solos.")
                    } actions: {
                        Button("Crear lista") { selected = store.createNote(.shopping, title: "Súper") }.buttonStyle(.glass)
                    }
                }
            } else if let failed = store.failed {
                ContentUnavailableView {
                    Label("No se han podido cargar las notas", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await store.load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CarliColor.bg)
        .task { await store.load() }
        .notesDestinations(store)
    }
}

struct ShoppingListView: View {
    var store: NotesStore
    var noteId: String
    var switchable: Bool
    var selected: Binding<String?>?
    var fresh = false
    var focusRequest = 0

    @Environment(\.dismiss) private var dismiss
    @State private var add = ""
    @State private var showCart = false
    @State private var editing: NoteItem?
    @State private var switching = false
    @State private var finishing = false
    @State private var restock = false
    @State private var renaming = false
    @State private var moving = false
    @FocusState private var adding: Bool

    init(store: NotesStore, noteId: String, switchable: Bool, selected: Binding<String?>? = nil, fresh: Bool = false, focusRequest: Int = 0) {
        self.store = store
        self.noteId = noteId
        self.switchable = switchable
        self.selected = selected
        self.fresh = fresh
        self.focusRequest = focusRequest
    }

    var body: some View {
        if let snapshot = store.snapshot, let note = snapshot.note(noteId) {
            content(snapshot, note)
        }
    }

    private func content(_ snapshot: NotesSnapshot, _ note: Note) -> some View {
        let products = snapshot.products(of: note.id)
        let byId = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        let groups = Self.groups(note, snapshot.sections)
        let cart = note.items.filter(\.checked)
        let query = add.trimmingCharacters(in: .whitespaces)
        let suggestions = Self.suggestions(note, products, query: query, limit: query.isEmpty ? 6 : 4)
        return List {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.openCount == 0 ? "NADA POR COMPRAR" : "\(note.openCount) POR COMPRAR")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CarliColor.text2)
                    if switchable {
                        Button { switching = true } label: {
                            HStack(spacing: 6) {
                                Text(note.displayTitle).font(.largeTitle.weight(.bold)).lineLimit(1)
                                Image(systemName: "chevron.down").font(.headline.weight(.bold)).foregroundStyle(CarliColor.text2)
                            }
                            .foregroundStyle(CarliColor.text)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Cambiar de lista")
                    } else {
                        Text(note.displayTitle).font(.largeTitle.weight(.bold)).lineLimit(1)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: CarliSpace.s4, bottom: CarliSpace.s8, trailing: CarliSpace.s4))
                HStack(spacing: CarliSpace.s12) {
                    Image(systemName: "plus").foregroundStyle(CarliColor.text2)
                    TextField("Añadir producto", text: $add)
                        .focused($adding)
                        .submitLabel(.done)
                        .onSubmit { submit(add, note) }
                }
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: CarliSpace.s8) {
                        Text(query.isEmpty ? "Sueles comprar" : "Ya lo compraste").font(.caption).foregroundStyle(CarliColor.text2)
                        ScrollView(.horizontal) {
                            HStack(spacing: CarliSpace.s8) {
                                ForEach(suggestions) { product in
                                    Chip(label: "+ \(product.name)") { submit(product.name, note) }
                                        .accessibilityLabel("Añadir \(product.name)")
                                }
                            }
                        }
                        .scrollIndicators(.hidden)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: CarliSpace.s4, bottom: 0, trailing: 0))
                }
            }
            if groups.isEmpty && cart.isEmpty {
                Text("La lista está vacía. Añade lo que te falta: se ordena solo por secciones del súper.")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.items) { item in
                        row(item, product: item.productId.flatMap { byId[$0] })
                            .swipeActions { Button("Quitar", systemImage: "trash", role: .destructive) { store.deleteItem(item, undoText: "\(item.text) quitado") } }
                    }
                }
            }
            if !cart.isEmpty {
                Section {
                    if showCart {
                        ForEach(cart) { item in row(item, product: item.productId.flatMap { byId[$0] }) }
                    }
                } header: {
                    HStack {
                        Text("En el carro · \(cart.count)")
                        Spacer()
                        Button(showCart ? "Ocultar" : "Mostrar") { withAnimation { showCart.toggle() } }.textCase(nil)
                    }
                } footer: {
                    Button("Terminar compra") { finishing = true }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .padding(.top, CarliSpace.s16)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await store.load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Reposición de productos", systemImage: "repeat") { restock = true }
                    Button("Renombrar lista", systemImage: "pencil") { renaming = true }
                    if !note.primary {
                        Button("Usar como lista principal", systemImage: "star") { store.makePrimary(note.id) }
                    }
                    Menu("Fijar, mover, archivar…", systemImage: "ellipsis.circle") {
                        NoteMenuItems(store: store, note: note, onMove: { moving = true }, onRemoved: { if !switchable { dismiss() } })
                    }
                    NavigationLink(value: NotesSettingsRoute()) { Label("Ajustes de Notas", systemImage: "gearshape") }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Reposición y ajustes de la lista")
            }
        }
        .onAppear { if fresh { adding = true } }
        .onChange(of: focusRequest) { adding = true }
        .sheet(item: $editing) { item in ShoppingItemSheet(store: store, item: item) }
        .sheet(isPresented: $switching) {
            ShoppingListSwitcher(store: store, current: note.id) { selected?.wrappedValue = $0 }
        }
        .sheet(isPresented: $finishing) {
            FinishShoppingSheet(note: note, products: byId) { store.finishShopping(note) }
        }
        .sheet(isPresented: $restock) { RestockOverview(store: store, noteId: note.id) }
        .sheet(isPresented: $moving) {
            FolderPicker(store: store, title: "Mover a", current: note.folderId) { store.moveNote(note.id, to: $0) }
        }
        .namePrompt("Renombrar lista", isPresented: $renaming, initial: note.title ?? "") { store.updateNote(note.id, title: $0) }
        .notesFeedback(store)
    }

    private func row(_ item: NoteItem, product: ShoppingProduct?) -> some View {
        let restocks = (product?.restock ?? .none) != .none
        return HStack(spacing: CarliSpace.s12) {
            Button { store.setChecked(item, !item.checked) } label: {
                HStack(spacing: CarliSpace.s12) {
                    Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.checked ? CarliColor.text2 : CarliColor.text3)
                    Text(item.text)
                        .strikethrough(item.checked)
                        .foregroundStyle(item.checked ? CarliColor.text2 : CarliColor.text)
                    Spacer(minLength: 0)
                    if restocks && !item.checked {
                        Image(systemName: "repeat").font(.caption).foregroundStyle(CarliColor.text2)
                    }
                    if let quantity = item.quantity {
                        Text(quantity).monospacedDigit().foregroundStyle(CarliColor.text2)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(([item.text] + [item.quantity].compactMap { $0 }
                                 + (restocks ? ["vuelve sola: \(product!.restockLabel)"] : [])).joined(separator: ", "))
            .accessibilityHint(item.checked ? "Devolver a la lista" : "Al carro")
            .accessibilityAddTraits(item.checked ? .isSelected : [])
            Button("Editar", systemImage: "info.circle") { editing = item }
                .labelStyle(.iconOnly)
                .foregroundStyle(CarliColor.text3)
                .buttonStyle(.borderless)
        }
    }

    private func submit(_ value: String, _ note: Note) {
        let text = value.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        add = ""
        store.addProduct(note.id, text)
        adding = true
    }

    struct SectionGroup {
        var title: String
        var items: [NoteItem]
    }

    /// Open items grouped by supermarket section, in the order the user walks the shop.
    static func groups(_ note: Note, _ sections: [ShoppingSection]) -> [SectionGroup] {
        let open = note.items.filter { !$0.checked }
        let ids = Set(sections.map(\.id))
        var result = sections.compactMap { section -> SectionGroup? in
            let items = open.filter { $0.sectionId == section.id }
            return items.isEmpty ? nil : SectionGroup(title: section.name, items: items)
        }
        let loose = open.filter { $0.sectionId.map(ids.contains) != true }
        if !loose.isEmpty { result.append(SectionGroup(title: "Sin sección", items: loose)) }
        return result
    }

    /// What the list usually buys and is not on it now, most bought first.
    static func suggestions(_ note: Note, _ products: [ShoppingProduct], query: String, limit: Int) -> [ShoppingProduct] {
        let listed = Set(note.items.compactMap(\.productId))
        return products
            .filter { !listed.contains($0.id) && (query.isEmpty || TextFold.contains($0.name, query)) }
            .sorted {
                ($0.timesBought ?? 0) != ($1.timesBought ?? 0) ? ($0.timesBought ?? 0) > ($1.timesBought ?? 0)
                    : ($0.lastBought ?? .distantPast) > ($1.lastBought ?? .distantPast)
            }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: Sheets

private let restockDisclaimer = "Cuando le toca, vuelve a la lista sin marcar. Cuenta desde la última vez que lo compraste. No crea tareas ni avisos."

struct ShoppingItemSheet: View {
    var store: NotesStore
    var item: NoteItem

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var quantity: String
    @State private var sectionId: String?
    @State private var restockProduct: ShoppingProduct?

    init(store: NotesStore, item: NoteItem) {
        self.store = store
        self.item = item
        _name = State(initialValue: item.text)
        _quantity = State(initialValue: item.quantity ?? "")
        _sectionId = State(initialValue: item.sectionId)
    }

    var body: some View {
        let product = item.productId.flatMap { id in store.snapshot?.products.first { $0.id == id } }
        NavigationStack {
            Form {
                Section("Nombre") { TextField("Nombre", text: $name) }
                Section {
                    TextField("Opcional", text: $quantity)
                } header: { Text("Cantidad") } footer: { Text("Texto libre: \"2\", \"1 kg\". Se recuerda para la próxima vez.") }
                Section {
                    Picker("Sección", selection: $sectionId) {
                        Text("Sin sección").tag(String?.none)
                        ForEach(store.snapshot?.sections ?? []) { Text($0.name).tag(Optional($0.id)) }
                    }
                } footer: { Text("Se recuerda para este producto.") }
                if let product {
                    Section {
                        Button { restockProduct = product } label: {
                            LabeledContent("Reposición", value: product.restockLabel)
                        }
                        .foregroundStyle(CarliColor.text)
                    }
                }
            }
            .navigationTitle("Producto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark") {
                        store.updateShoppingItem(item, text: name, quantity: quantity, sectionId: sectionId)
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(CarliColor.primary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(item: $restockProduct) { ProductRestockSheet(store: store, product: $0) }
        }
        .presentationDetents([.large])
    }
}

struct ProductRestockSheet: View {
    var store: NotesStore
    var product: ShoppingProduct

    @Environment(\.dismiss) private var dismiss
    @State private var mode: RestockMode
    @State private var amount: Int
    @State private var weeks: Bool

    init(store: NotesStore, product: ShoppingProduct) {
        self.store = store
        self.product = product
        let days = product.restockIntervalDays ?? 7
        _mode = State(initialValue: product.restock)
        _weeks = State(initialValue: days % 7 == 0)
        _amount = State(initialValue: days % 7 == 0 ? days / 7 : days)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Reposición", selection: $mode) {
                        Text("Sin repetir").tag(RestockMode.none)
                        Text("Cada compra").tag(RestockMode.everyTrip)
                        Text("Cada…").tag(RestockMode.interval)
                    }
                    .pickerStyle(.segmented)
                    if mode == .interval {
                        Stepper("Cada \(amount) \(weeks ? (amount == 1 ? "semana" : "semanas") : (amount == 1 ? "día" : "días"))",
                                value: $amount, in: 1...(weeks ? 26 : 90))
                        Picker("Unidad", selection: $weeks) {
                            Text("días").tag(false)
                            Text("semanas").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text(product.name)
                } footer: {
                    Text(((product.lastBought.map { "Última compra: \(CarliDate.short($0))." }) ?? "Aún no lo has comprado con esta lista.")
                         + " " + restockDisclaimer)
                }
                Section {
                    Button("Olvidar producto", role: .destructive) {
                        store.forgetProduct(product)
                        dismiss()
                    }
                } footer: {
                    Text("Deja de sugerirse; los elementos que haya en la lista se quedan.")
                }
            }
            .navigationTitle("Reposición")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark") {
                        store.setRestock(product, mode, intervalDays: weeks ? amount * 7 : amount)
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(CarliColor.primary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct RestockOverview: View {
    var store: NotesStore
    var noteId: String

    @Environment(\.dismiss) private var dismiss
    @State private var picked: ShoppingProduct?

    var body: some View {
        let note = store.snapshot?.note(noteId)
        let products = (store.snapshot?.products(of: noteId) ?? []).sorted { $0.name.lowercased() < $1.name.lowercased() }
        let listed = Set(note?.items.compactMap(\.productId) ?? [])
        let restocking = products.filter { $0.restock != .none }
        let others = products.filter { $0.restock == .none }
        NavigationStack {
            List {
                if products.isEmpty {
                    Text("Aquí aparecerán los productos que añadas a la lista. Elige cuáles vuelven solos y cada cuánto.")
                        .font(.footnote).foregroundStyle(CarliColor.text2)
                }
                if !restocking.isEmpty {
                    Section {
                        ForEach(restocking) { product in row(product, next: next(product, listed: listed)) }
                    } header: { Text("Se reponen solos") } footer: { Text(restockDisclaimer) }
                }
                if !others.isEmpty {
                    Section("Sin repetir") {
                        ForEach(others) { product in row(product, next: nil) }
                    }
                }
            }
            .navigationTitle("Reposición")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo", systemImage: "checkmark") { dismiss() } } }
            .sheet(item: $picked) { ProductRestockSheet(store: store, product: $0) }
        }
    }

    private func next(_ product: ShoppingProduct, listed: Set<String>) -> String {
        if listed.contains(product.id) { return product.defaultQuantity.map { "En la lista · \($0)" } ?? "En la lista" }
        guard let date = product.restockDate else { return "Cuando lo compres" }
        let days = TaskDates.offset(date)
        if days <= 0 { return "Vuelve hoy" }
        if days == 1 { return "Vuelve mañana" }
        return "Vuelve el \(TaskDates.weekdayShort(date))"
    }

    private func row(_ product: ShoppingProduct, next: String?) -> some View {
        Button { picked = product } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                    if let next { Text(next).font(.footnote).foregroundStyle(CarliColor.text2) }
                }
                Spacer()
                Text(product.restockLabel).font(.footnote).foregroundStyle(CarliColor.text2)
                Chevron()
            }
            .foregroundStyle(CarliColor.text)
        }
    }
}

private struct FinishShoppingSheet: View {
    var note: Note
    var products: [String: ShoppingProduct]
    var finish: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let cart = note.items.filter(\.checked)
        let inCart = cart.compactMap { $0.productId.flatMap { products[$0] } }
        let everyTrip = inCart.filter { $0.restock == .everyTrip }.map(\.name)
        let interval = inCart.filter { $0.restock == .interval }.map(\.name)
        NavigationStack {
            List {
                Section {
                    line("cart", "Se vacía el carro", "Puedes deshacerlo durante unos segundos")
                    if !everyTrip.isEmpty {
                        line("repeat", "\(Self.names(everyTrip)) \(everyTrip.count == 1 ? "vuelve" : "vuelven") ya", "Se reponen en cada compra")
                    }
                    if !interval.isEmpty { line("calendar", Self.names(interval), "Vuelven cuando les toque") }
                } header: {
                    Text(cart.count == 1 ? "1 producto en el carro" : "\(cart.count) productos en el carro").textCase(nil)
                }
            }
            .navigationTitle("Terminar compra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminar compra") {
                        finish()
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(CarliColor.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func line(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle).font(.footnote).foregroundStyle(CarliColor.text2)
            }
        } icon: { Image(systemName: symbol) }
    }

    static func names(_ names: [String]) -> String {
        if names.count == 1 { return names[0] }
        let shown = Array(names.prefix(3))
        let rest = names.count - shown.count
        return rest > 0 ? "\(shown.joined(separator: ", ")) y \(rest) más"
            : "\(shown.dropLast().joined(separator: ", ")) y \(shown.last!)"
    }
}

private struct ShoppingListSwitcher: View {
    var store: NotesStore
    var current: String
    var pick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var creating = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.snapshot?.shoppingNotes ?? []) { note in
                    Button {
                        pick(note.id)
                        dismiss()
                    } label: {
                        HStack {
                            Text(note.displayTitle)
                            Spacer()
                            if note.primary { Text("Principal").font(.footnote).foregroundStyle(CarliColor.text2) }
                            Text("\(note.openCount)").font(.footnote).foregroundStyle(CarliColor.text2)
                            if note.id == current { Image(systemName: "checkmark") }
                        }
                        .foregroundStyle(CarliColor.text)
                    }
                }
                Button("Nueva lista de la compra", systemImage: "plus") { creating = true }
            }
            .navigationTitle("Listas de la compra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar", systemImage: "xmark") { dismiss() } } }
            .namePrompt("Nueva lista", isPresented: $creating, placeholder: "Farmacia, Bricolaje…", confirm: "Crear") { name in
                pick(store.createNote(.shopping, title: name))
                dismiss()
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: Ajustes

struct NotesSettingsView: View {
    var store: NotesStore

    @State private var inline = false
    @State private var newSection = false
    @State private var renaming: ShoppingSection?

    var body: some View {
        let snapshot = store.snapshot ?? NotesSnapshot()
        List {
            Section {
                ForEach(snapshot.shoppingNotes) { note in
                    Button { store.makePrimary(note.id) } label: {
                        HStack {
                            Text(note.displayTitle)
                            Spacer()
                            if note.primary { Image(systemName: "checkmark") }
                        }
                        .foregroundStyle(CarliColor.text)
                    }
                }
            } header: { Text("Lista de la compra principal") } footer: { Text("Es la que abre la pestaña Compra.") }
            Section("Elementos marcados en listas nuevas") {
                Picker("Marcados", selection: Binding(get: { inline }, set: { value in
                    inline = value
                    Task {
                        do {
                            try await ModuleSettings.save(store.api, module: AppModule.notes, ["checked_behavior": .string(value ? "inline" : "move")])
                        } catch {
                            inline = !value
                            store.toast = error.apiMessage(fallback: "No se ha podido guardar.")
                        }
                    }
                })) {
                    Text("Bajan a “Hechos”").tag(false)
                    Text("Tachados en su sitio").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Section {
                ForEach(snapshot.sections) { section in
                    Text(section.name)
                        .contentShape(.rect)
                        .onTapGesture { renaming = section }
                        .swipeActions { Button("Borrar", systemImage: "trash", role: .destructive) { store.deleteSection(section.id) } }
                }
                .onMove { from, to in
                    var ordered = snapshot.sections
                    ordered.move(fromOffsets: from, toOffset: to)
                    store.reorderSections(ordered)
                }
            } header: {
                HStack {
                    Text("Secciones del súper")
                    Spacer()
                    Button("Añadir") { newSection = true }.textCase(nil)
                }
            } footer: {
                Text("Ordénalas como recorres tu súper: mantén pulsado y arrastra para mover, desliza para borrar.")
            }
            Section {
                Button(store.syncing ? "Sincronizando…" : "Sincronizar ahora") { Task { await store.load() } }
                    .disabled(store.syncing)
            }
        }
        .navigationTitle("Ajustes de Notas")
        .task {
            struct Settings: Decodable { var checkedBehavior: String? }
            inline = await ModuleSettings.load(store.api, module: AppModule.notes, as: Settings.self)?.checkedBehavior == "inline"
        }
        .namePrompt("Nueva sección", isPresented: $newSection, confirm: "Crear") { store.createSection($0) }
        .namePrompt("Renombrar sección", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }),
                    initial: renaming?.name ?? "") { name in
            if let section = renaming { store.renameSection(section.id, name) }
        }
        .notesFeedback(store)
    }
}
