import Foundation
import Observation

/// One change for `POST /v1/notes/sync`. It is applied to the in-memory snapshot at once and sent in order;
/// the server applies it again with the same rules and answers with the fresh snapshot.
struct NoteOperation: Encodable {
    var id = UUID().uuidString.lowercased()
    var type: String
    var at = Date.now
    var payload: [String: JSONValue]

    private enum CodingKeys: String, CodingKey { case id, type, at, payload }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encode(NoteOperation.iso(at), forKey: .at)
        try c.encode(Patch(payload), forKey: .payload)
    }

    static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

/// The notes snapshot plus every write, shared by the Notas and Compra sections.
@Observable
final class NotesStore {
    let api: APIClient
    private(set) var snapshot: NotesSnapshot?
    var failed: String?
    var toast: String?
    var undo: UndoOffer?
    var syncing = false
    /// Notes module setting for new lists: "move" (checked go to Hechos) or "inline".
    var defaultCheckedBehavior = "move"

    private var pending: [NoteOperation] = []
    private var flushing = false

    init(api: APIClient) {
        self.api = api
    }

    static func newId() -> String { UUID().uuidString.lowercased() }

    func load() async {
        do {
            let envelope: DataEnvelope<NotesSnapshot> = try await api.get("v1/notes/snapshot")
            replace(with: envelope.data)
            failed = nil
            struct Settings: Decodable { var checkedBehavior: String? }
            if let behavior = await ModuleSettings.load(api, module: AppModule.notes, as: Settings.self)?.checkedBehavior {
                defaultCheckedBehavior = behavior
            }
        } catch {
            if snapshot == nil { failed = error.apiMessage(fallback: "Inténtalo de nuevo.") }
        }
    }

    private func replace(with fresh: NotesSnapshot) {
        var next = fresh
        for operation in pending { Self.apply(operation, to: &next) }
        if next != snapshot { snapshot = next }
        NotificationCenter.default.post(name: .notesChanged, object: self)
    }

    /// Applies the operations locally and queues them for the server.
    func record(_ operations: [NoteOperation]) {
        guard !operations.isEmpty else { return }
        if var current = snapshot {
            for operation in operations { Self.apply(operation, to: &current) }
            snapshot = current
        }
        pending.append(contentsOf: operations)
        Task { await flush() }
    }

    func record(_ type: String, _ payload: [String: JSONValue]) {
        record([NoteOperation(type: type, payload: payload)])
    }

    private struct SyncBody: Encodable { var operations: [NoteOperation] }
    private struct SyncResponse: Decodable { var data: NotesSnapshot }

    private func flush() async {
        guard !flushing else { return }
        flushing = true
        syncing = true
        defer {
            flushing = false
            syncing = false
        }
        while !pending.isEmpty {
            let batch = pending
            do {
                let response: SyncResponse = try await api.post("v1/notes/sync", body: SyncBody(operations: batch))
                pending.removeFirst(min(batch.count, pending.count))
                replace(with: response.data)
            } catch {
                pending.removeAll()
                toast = error.apiMessage(fallback: "No se han podido guardar los cambios.")
                await load()
                return
            }
        }
    }

    // MARK: Notes

    @discardableResult
    func createNote(_ type: NoteType, folderId: String? = nil, title: String? = nil, body: String? = nil,
                    checkedBehavior: String? = nil) -> String {
        let id = Self.newId()
        let checkedBehavior = checkedBehavior ?? defaultCheckedBehavior
        record("note.upsert", ["id": .string(id), "type": .string(type.rawValue), "folder_id": .optional(folderId),
                               "title": .optional(title), "body": .optional(body), "checked_behavior": .string(checkedBehavior)])
        return id
    }

    func updateNote(_ id: String, title: String? = nil, body: String? = nil) {
        var payload: [String: JSONValue] = ["id": .string(id)]
        if let title { payload["title"] = .string(title) }
        if let body { payload["body"] = .string(body) }
        record("note.upsert", payload)
    }

    func setFlag(_ id: String, _ flag: String, _ value: Bool) {
        record("note.upsert", ["id": .string(id), flag: .bool(value)])
    }

    func moveNote(_ id: String, to folderId: String?) { record("note.upsert", ["id": .string(id), "folder_id": .optional(folderId)]) }
    func setCheckedBehavior(_ id: String, inline: Bool) {
        record("note.upsert", ["id": .string(id), "checked_behavior": .string(inline ? "inline" : "move")])
    }
    func makePrimary(_ id: String) { record("note.upsert", ["id": .string(id), "is_primary": .bool(true)]) }
    func purge(_ id: String) { record("note.purge", ["id": .string(id)]) }

    /// Discards a note left empty when its editor closes.
    func discardIfEmpty(_ id: String) {
        if let note = snapshot?.note(id), note.isEmpty, !note.isShopping { purge(id) }
    }

    func delete(_ note: Note) {
        setFlag(note.id, "deleted", true)
        undo = UndoOffer(text: "Nota en la papelera") { [weak self] in self?.setFlag(note.id, "deleted", false) }
    }

    func archive(_ note: Note) {
        setFlag(note.id, "archived", !note.archived)
        undo = UndoOffer(text: note.archived ? "Nota fuera del archivo" : "Nota archivada") { [weak self] in
            self?.setFlag(note.id, "archived", note.archived)
        }
    }

    func duplicate(_ note: Note) -> String {
        let id = Self.newId()
        var operations = [NoteOperation(type: "note.upsert", payload: [
            "id": .string(id), "type": .string(note.type), "folder_id": .optional(note.folderId),
            "title": .string("\(note.displayTitle) (copia)"), "body": .optional(note.body),
            "checked_behavior": .string(note.checkedBehavior ?? "move"),
        ])]
        for item in note.items {
            operations.append(NoteOperation(type: "item.upsert", payload: [
                "id": .string(Self.newId()), "note_id": .string(id), "text": .string(item.text),
                "quantity": .optional(item.quantity), "section_id": .optional(item.sectionId), "checked": .bool(false),
                "position": .int(item.position),
            ]))
        }
        record(operations)
        return id
    }

    /// Text ↔ list: every non-empty line becomes an item, and the items become lines.
    func convert(_ note: Note) {
        switch note.kind {
        case .text:
            let lines = (note.body ?? "").split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            var operations = [NoteOperation(type: "note.upsert", payload: ["id": .string(note.id), "type": .string("list"), "body": .null])]
            for (index, line) in lines.enumerated() {
                operations.append(NoteOperation(type: "item.upsert", payload: [
                    "id": .string(Self.newId()), "note_id": .string(note.id),
                    "text": .string(line.replacingOccurrences(of: #"^[-*•]\s*"#, with: "", options: .regularExpression)),
                    "checked": .bool(false), "position": .int(index),
                ]))
            }
            record(operations)
        case .list:
            var operations = [NoteOperation(type: "note.upsert", payload: [
                "id": .string(note.id), "type": .string("text"), "body": .string(note.items.map(\.text).joined(separator: "\n")),
            ])]
            operations += note.items.map { NoteOperation(type: "item.delete", payload: ["id": .string($0.id)]) }
            record(operations)
        case .shopping:
            return
        }
    }

    // MARK: Folders

    @discardableResult
    func createFolder(_ name: String, parentId: String? = nil) -> String {
        let id = Self.newId()
        let siblings = snapshot?.children(of: parentId) ?? []
        record("folder.upsert", ["id": .string(id), "parent_id": .optional(parentId), "name": .string(name.trimmingCharacters(in: .whitespaces)),
                                 "position": .int((siblings.map(\.position).max() ?? -1) + 1)])
        return id
    }

    func renameFolder(_ id: String, _ name: String) {
        record("folder.upsert", ["id": .string(id), "name": .string(name.trimmingCharacters(in: .whitespaces))])
    }

    func moveFolder(_ id: String, to parentId: String?) -> Bool {
        if let parentId, snapshot?.descendantsAndSelf(id).contains(parentId) == true { return false }
        record("folder.upsert", ["id": .string(id), "parent_id": .optional(parentId)])
        return true
    }

    func deleteFolder(_ id: String) { record("folder.delete", ["id": .string(id)]) }

    // MARK: Items

    private func itemPayload(_ item: NoteItem) -> [String: JSONValue] {
        ["id": .string(item.id), "note_id": .string(item.noteId), "text": .string(item.text), "quantity": .optional(item.quantity),
         "section_id": .optional(item.sectionId), "product_id": .optional(item.productId), "checked": .bool(item.checked),
         "position": .int(item.position)]
    }

    @discardableResult
    func addItem(_ noteId: String, _ text: String, at position: Int? = nil) -> String {
        let id = Self.newId()
        let items = snapshot?.note(noteId)?.items ?? []
        var operations: [NoteOperation] = []
        if let position {
            for item in items where item.position >= position {
                var payload = itemPayload(item)
                payload["position"] = .int(item.position + 1)
                operations.append(NoteOperation(type: "item.upsert", payload: payload))
            }
        }
        operations.append(NoteOperation(type: "item.upsert", payload: [
            "id": .string(id), "note_id": .string(noteId), "text": .string(text.trimmingCharacters(in: .whitespaces)),
            "checked": .bool(false), "position": .int(position ?? ((items.map(\.position).max() ?? -1) + 1)),
        ]))
        record(operations)
        return id
    }

    func renameItem(_ item: NoteItem, _ text: String) {
        var payload = itemPayload(item)
        payload["text"] = .string(text.trimmingCharacters(in: .whitespaces))
        record("item.upsert", payload)
    }

    func setChecked(_ item: NoteItem, _ checked: Bool) {
        var payload = itemPayload(item)
        payload["checked"] = .bool(checked)
        record("item.upsert", payload)
    }

    func deleteItem(_ item: NoteItem, undoText: String = "Elemento borrado") {
        record("item.delete", ["id": .string(item.id)])
        undo = UndoOffer(text: undoText) { [weak self] in self?.restoreItem(item) }
    }

    func restoreItem(_ item: NoteItem) { record("item.upsert", itemPayload(item)) }

    func reorderItems(_ ordered: [NoteItem]) {
        var operations: [NoteOperation] = []
        for (position, item) in ordered.enumerated() where item.position != position {
            var payload = itemPayload(item)
            payload["position"] = .int(position)
            operations.append(NoteOperation(type: "item.upsert", payload: payload))
        }
        record(operations)
    }

    func uncheckAll(_ note: Note) {
        record(note.items.filter(\.checked).map { item in
            var payload = itemPayload(item)
            payload["checked"] = .bool(false)
            return NoteOperation(type: "item.upsert", payload: payload)
        })
    }

    // MARK: Shopping

    /// Adds a product to a shopping list, reusing what the list has learnt about it (section and usual quantity).
    func addProduct(_ noteId: String, _ name: String, quantity: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let snapshot, let note = snapshot.note(noteId) else { return }
        let product = snapshot.products(of: noteId).first { TextFold.fold($0.name) == TextFold.fold(trimmed) }
        if let product, let listed = note.items.first(where: { $0.productId == product.id }) {
            if listed.checked { setChecked(listed, false) }
            return
        }
        let productId = product?.id ?? Self.newId()
        let sectionId = product?.sectionId ?? SectionGuess.sectionId(for: trimmed, in: snapshot.sections)
        var operations: [NoteOperation] = []
        if product == nil {
            operations.append(NoteOperation(type: "product.upsert", payload: [
                "id": .string(productId), "note_id": .string(noteId), "name": .string(trimmed),
                "section_id": .optional(sectionId), "default_quantity": .optional(quantity),
            ]))
        }
        operations.append(NoteOperation(type: "item.upsert", payload: [
            "id": .string(Self.newId()), "note_id": .string(noteId), "product_id": .string(productId),
            "text": .string(product?.name ?? trimmed), "quantity": .optional(quantity ?? product?.defaultQuantity),
            "section_id": .optional(sectionId), "checked": .bool(false),
            "position": .int((note.items.map(\.position).max() ?? -1) + 1),
        ]))
        record(operations)
    }

    /// Edits a shopping item; the product remembers the section and quantity for next time.
    func updateShoppingItem(_ item: NoteItem, text: String, quantity: String?, sectionId: String?) {
        let quantity = quantity?.trimmingCharacters(in: .whitespaces).isEmpty == false ? quantity!.trimmingCharacters(in: .whitespaces) : nil
        var payload = itemPayload(item)
        payload["text"] = .string(text.trimmingCharacters(in: .whitespaces))
        payload["quantity"] = .optional(quantity)
        payload["section_id"] = .optional(sectionId)
        var operations = [NoteOperation(type: "item.upsert", payload: payload)]
        if let productId = item.productId {
            operations.append(NoteOperation(type: "product.upsert", payload: [
                "id": .string(productId), "name": .string(text.trimmingCharacters(in: .whitespaces)),
                "section_id": .optional(sectionId), "default_quantity": .optional(quantity),
            ]))
        }
        record(operations)
    }

    func setRestock(_ product: ShoppingProduct, _ mode: RestockMode, intervalDays: Int?) {
        record("product.upsert", ["id": .string(product.id), "restock_mode": .string(mode.rawValue),
                                  "restock_interval_days": mode == .interval ? .optional(intervalDays) : .null])
    }

    func forgetProduct(_ product: ShoppingProduct) { record("product.delete", ["id": .string(product.id)]) }

    /// Empties the cart and stamps each product's purchase date, which restock counts from. Offers an undo.
    func finishShopping(_ note: Note) {
        let cart = note.items.filter(\.checked)
        let products = Dictionary(uniqueKeysWithValues: (snapshot?.products(of: note.id) ?? []).map { ($0.id, $0) })
        let before = Set(note.items.map(\.id))
        record("shopping.finish", ["note_id": .string(note.id), "item_ids": .array(cart.map { .string($0.id) }),
                                   "finished_at": .string(NoteOperation.iso(.now))])
        undo = UndoOffer(text: cart.count == 1 ? "Compra terminada: 1 producto" : "Compra terminada: \(cart.count) productos") { [weak self] in
            guard let self else { return }
            // Restocked items appear after the server answers; remove whatever is new since the finish.
            let restocked = (self.snapshot?.note(note.id)?.items ?? []).filter { !before.contains($0.id) }
            var operations = restocked.map { NoteOperation(type: "item.delete", payload: ["id": .string($0.id)]) }
            for item in cart {
                if let productId = item.productId, let product = products[productId] {
                    operations.append(NoteOperation(type: "product.upsert", payload: [
                        "id": .string(product.id), "last_bought_at": .optional(product.lastBoughtAt),
                        "times_bought": .int(product.timesBought ?? 0), "restocked_for": .optional(product.restockedFor),
                    ]))
                }
                operations.append(NoteOperation(type: "item.upsert", payload: self.itemPayload(item)))
            }
            self.record(operations)
        }
    }

    @discardableResult
    func createSection(_ name: String) -> String {
        let id = Self.newId()
        record("section.upsert", ["id": .string(id), "name": .string(name.trimmingCharacters(in: .whitespaces)),
                                  "position": .int(snapshot?.sections.count ?? 0)])
        return id
    }

    func renameSection(_ id: String, _ name: String) {
        record("section.upsert", ["id": .string(id), "name": .string(name.trimmingCharacters(in: .whitespaces))])
    }

    func reorderSections(_ ordered: [ShoppingSection]) {
        record(ordered.enumerated().filter { $0.element.position != $0.offset }.map {
            NoteOperation(type: "section.upsert", payload: ["id": .string($0.element.id), "position": .int($0.offset)])
        })
    }

    func deleteSection(_ id: String) { record("section.delete", ["id": .string(id)]) }

    // MARK: Local apply

    /// Mirrors the server rules closely enough for an instant UI; the next snapshot corrects anything else.
    static func apply(_ operation: NoteOperation, to s: inout NotesSnapshot) {
        let p = operation.payload
        let at = NoteOperation.iso(operation.at)
        func string(_ key: String) -> String?? {
            guard let value = p[key] else { return .none }
            if case .string(let text) = value { return .some(text) }
            return .some(nil)
        }
        func int(_ key: String) -> Int? {
            if case .int(let value)? = p[key] { return value }
            return nil
        }
        func bool(_ key: String) -> Bool? {
            if case .bool(let value)? = p[key] { return value }
            return nil
        }
        guard case .string(let id)? = p["id"] ?? p["note_id"] else { return }

        switch operation.type {
        case "note.upsert":
            if let index = s.notes.firstIndex(where: { $0.id == id }) {
                var note = s.notes[index]
                if let type = string("type") { note.type = type ?? note.type }
                if let folder = string("folder_id") { note.folderId = folder }
                if let title = string("title") { note.title = title }
                if p.keys.contains("body") { note.body = string("body") ?? nil }
                if let pinned = bool("pinned") { note.pinnedAt = pinned ? (note.pinnedAt ?? at) : nil }
                if let archived = bool("archived") { note.archivedAt = archived ? (note.archivedAt ?? at) : nil }
                if let deleted = bool("deleted") { note.deletedAt = deleted ? (note.deletedAt ?? at) : nil }
                if let behavior = string("checked_behavior") { note.checkedBehavior = behavior }
                if bool("is_primary") == true {
                    for other in s.notes.indices { s.notes[other].isPrimary = false }
                    note.isPrimary = true
                }
                note.updatedAt = at
                s.notes[index] = note
            } else if let type = string("type") ?? nil {
                var note = Note(id: id, type: .of(type), folderId: string("folder_id") ?? nil, title: string("title") ?? nil,
                                body: string("body") ?? nil, checkedBehavior: string("checked_behavior") ?? nil, at: at)
                if type == "shopping" && !s.notes.contains(where: { $0.primary && !$0.deleted }) { note.isPrimary = true }
                s.notes.append(note)
            }
        case "note.purge":
            s.notes.removeAll { $0.id == id }
            s.products.removeAll { $0.noteId == id }
        case "item.upsert":
            for n in s.notes.indices {
                if let i = s.notes[n].items.firstIndex(where: { $0.id == id }) {
                    var item = s.notes[n].items[i]
                    if let text = string("text") { item.text = text ?? item.text }
                    if let quantity = string("quantity") { item.quantity = quantity }
                    if let section = string("section_id") { item.sectionId = section }
                    if let product = string("product_id") { item.productId = product }
                    if let checked = bool("checked") { item.checkedAt = checked ? (item.checkedAt ?? at) : nil }
                    if let position = int("position") { item.position = position }
                    item.updatedAt = at
                    s.notes[n].items[i] = item
                    s.notes[n].items.sort { $0.position < $1.position }
                    s.notes[n].updatedAt = at
                    return
                }
            }
            guard let noteId = string("note_id") ?? nil, let text = string("text") ?? nil,
                  let n = s.notes.firstIndex(where: { $0.id == noteId }) else { return }
            let item = NoteItem(id: id, noteId: noteId, productId: string("product_id") ?? nil, text: text,
                                quantity: string("quantity") ?? nil, sectionId: string("section_id") ?? nil,
                                checkedAt: bool("checked") == true ? at : nil, position: int("position") ?? 0, updatedAt: at)
            s.notes[n].items.append(item)
            s.notes[n].items.sort { $0.position < $1.position }
            s.notes[n].updatedAt = at
        case "item.delete":
            for n in s.notes.indices { s.notes[n].items.removeAll { $0.id == id } }
        case "folder.upsert":
            if let index = s.folders.firstIndex(where: { $0.id == id }) {
                if let name = string("name") { s.folders[index].name = name ?? s.folders[index].name }
                if let parent = string("parent_id") { s.folders[index].parentId = parent }
                if let position = int("position") { s.folders[index].position = position }
            } else if let name = string("name") ?? nil {
                s.folders.append(NoteFolder(id: id, parentId: string("parent_id") ?? nil, name: name, position: int("position") ?? 0))
            }
        case "folder.delete":
            guard let folder = s.folder(id) else { return }
            for index in s.folders.indices where s.folders[index].parentId == id { s.folders[index].parentId = folder.parentId }
            for index in s.notes.indices where s.notes[index].folderId == id { s.notes[index].folderId = folder.parentId }
            s.folders.removeAll { $0.id == id }
        case "product.upsert":
            if let index = s.products.firstIndex(where: { $0.id == id }) {
                if let name = string("name") { s.products[index].name = name ?? s.products[index].name }
                if let section = string("section_id") { s.products[index].sectionId = section }
                if let quantity = string("default_quantity") { s.products[index].defaultQuantity = quantity }
                if let mode = string("restock_mode") { s.products[index].restockMode = mode }
                if p.keys.contains("restock_interval_days") { s.products[index].restockIntervalDays = int("restock_interval_days") }
            } else if let noteId = string("note_id") ?? nil, let name = string("name") ?? nil {
                s.products.append(ShoppingProduct(id: id, noteId: noteId, name: name, sectionId: string("section_id") ?? nil,
                                                  defaultQuantity: string("default_quantity") ?? nil))
            }
        case "product.delete":
            for n in s.notes.indices {
                for i in s.notes[n].items.indices where s.notes[n].items[i].productId == id { s.notes[n].items[i].productId = nil }
            }
            s.products.removeAll { $0.id == id }
        case "section.upsert":
            if let index = s.sections.firstIndex(where: { $0.id == id }) {
                if let name = string("name") { s.sections[index].name = name ?? s.sections[index].name }
                if let position = int("position") { s.sections[index].position = position }
            } else if let name = string("name") ?? nil {
                s.sections.append(ShoppingSection(id: id, name: name, position: int("position") ?? s.sections.count))
            }
            s.sections.sort { $0.position < $1.position }
        case "section.delete":
            for n in s.notes.indices {
                for i in s.notes[n].items.indices where s.notes[n].items[i].sectionId == id { s.notes[n].items[i].sectionId = nil }
            }
            s.sections.removeAll { $0.id == id }
        case "shopping.finish":
            guard case .array(let ids)? = p["item_ids"], let n = s.notes.firstIndex(where: { $0.id == id }) else { return }
            let finished = Set(ids.compactMap { if case .string(let value) = $0 { value } else { nil } })
            s.notes[n].items.removeAll { finished.contains($0.id) }
        default:
            break
        }
    }
}

/// Picks a supermarket section for a product the list has never seen, by keywords in its name.
enum SectionGuess {
    private static let keywords: [(String, String)] = [
        ("fruta y verdura", "platano|manzana|pera|naranja|mandarina|limon|fresa|uva|melon|sandia|kiwi|aguacate|tomate|lechuga|cebolla|ajo|patata|zanahoria|pimiento|pepino|calabacin|berenjena|espinaca|brocoli|coliflor|champinon|seta|fruta|verdura|puerro|judia|calabaza|mango|pina|melocoton|cereza|rucula|canonigo|perejil|cilantro|albahaca"),
        ("carne y pescado", "pollo|ternera|cerdo|cordero|pavo|carne|filete|hamburguesa|salchicha|chorizo|jamon|lomo|bacon|pescado|salmon|merluza|atun fresco|gamba|langostino|calamar|sepia|mejillon|bacalao|dorada|lubina|pechuga|muslo|costilla|embutido|fuet|pavo"),
        ("lacteos y huevos", "leche|yogur|queso|mantequilla|nata|huevo|kefir|requeson|cuajada|flan|natillas"),
        ("panaderia", "pan|baguette|barra|croissant|magdalena|bolleria|tostada|bizcocho|galleta"),
        ("despensa", "arroz|pasta|macarron|espagueti|harina|azucar|sal|aceite|vinagre|cafe|te|infusion|cacao|cereal|avena|legumbre|garbanzo|lenteja|alubia|atun|sardina|conserva|tomate frito|especia|pimienta|mermelada|miel|chocolate|frutos secos|nuez|almendra|caldo|quinoa|cuscus|tortilla de trigo|salsa|mayonesa|ketchup|mostaza"),
        ("congelados", "congelad|helado|pizza|hielo|croqueta|guisante"),
        ("bebidas", "agua|cerveza|vino|refresco|zumo|cola|tonica|gaseosa|cava|bebida"),
        ("limpieza", "lavavajillas|detergente|suavizante|lejia|friegasuelos|limpia|estropajo|bayeta|papel de cocina|servilleta|bolsa de basura|bolsas de basura|fregona|insecticida|ambientador|papel de aluminio|papel film|pastillas"),
        ("higiene", "champu|gel|jabon|pasta de dientes|dentifrico|cepillo|desodorante|papel higienico|compresa|tampon|cuchilla|crema|colonia|algodon|toallita|panal|enjuague|seda dental"),
    ]

    static func sectionId(for productName: String, in sections: [ShoppingSection]) -> String? {
        let name = " \(TextFold.fold(productName).replacingOccurrences(of: "ñ", with: "n")) "
        var best: String?
        var bestLength = 0
        for (section, words) in keywords {
            for keyword in words.split(separator: "|") where keyword.count > bestLength && name.contains(" \(keyword)") {
                best = section
                bestLength = keyword.count
            }
        }
        guard let best else { return nil }
        return sections.first { TextFold.fold($0.name) == best }?.id
    }
}
