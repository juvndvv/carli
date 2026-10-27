import Foundation

extension Notification.Name {
    /// Posted after the notes snapshot changes so Inicio and every notes screen refresh.
    static let notesChanged = Notification.Name("carli.notesChanged")
}

enum NoteType: String, CaseIterable, Identifiable {
    case text, list, shopping

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: "Texto"
        case .list: "Lista"
        case .shopping: "Compra"
        }
    }

    var symbol: String {
        switch self {
        case .text: "note.text"
        case .list: "checklist"
        case .shopping: "cart"
        }
    }

    static func of(_ value: String?) -> NoteType { value.flatMap(NoteType.init(rawValue:)) ?? .text }
}

enum RestockMode: String, CaseIterable, Identifiable {
    case none, everyTrip = "every_trip", interval

    var id: String { rawValue }

    static func of(_ value: String?) -> RestockMode { value.flatMap(RestockMode.init(rawValue:)) ?? .none }
}

struct NoteFolder: Decodable, Identifiable, Hashable {
    var id: String
    var parentId: String?
    var name: String
    var position: Int
    var updatedAt: String?

    private enum CodingKeys: String, CodingKey { case id, parentId, name, position, updatedAt }

    init(id: String, parentId: String?, name: String, position: Int, updatedAt: String? = nil) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.position = position
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct NoteItem: Decodable, Identifiable, Equatable, Hashable {
    var id: String
    var noteId: String
    var productId: String?
    var text: String
    var quantity: String?
    var sectionId: String?
    var checkedAt: String?
    var position: Int
    var updatedAt: String?

    var checked: Bool { checkedAt != nil }

    private enum CodingKeys: String, CodingKey { case id, noteId, productId, text, quantity, sectionId, checkedAt, position, updatedAt }

    init(id: String, noteId: String, productId: String? = nil, text: String, quantity: String? = nil, sectionId: String? = nil,
         checkedAt: String? = nil, position: Int, updatedAt: String? = nil) {
        self.id = id
        self.noteId = noteId
        self.productId = productId
        self.text = text
        self.quantity = quantity
        self.sectionId = sectionId
        self.checkedAt = checkedAt
        self.position = position
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        noteId = try c.decodeIfPresent(String.self, forKey: .noteId) ?? ""
        productId = try c.decodeIfPresent(String.self, forKey: .productId)
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        quantity = try c.decodeIfPresent(String.self, forKey: .quantity)
        sectionId = try c.decodeIfPresent(String.self, forKey: .sectionId)
        checkedAt = try c.decodeIfPresent(String.self, forKey: .checkedAt)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct Note: Decodable, Identifiable, Equatable, Hashable {
    var id: String
    var type: String
    var folderId: String?
    var title: String?
    var body: String?
    var pinnedAt: String?
    var archivedAt: String?
    var deletedAt: String?
    var checkedBehavior: String?
    var isPrimary: Bool?
    var sort: Int?
    var createdAt: String?
    var updatedAt: String?
    var items: [NoteItem]

    private enum CodingKeys: String, CodingKey {
        case id, type, folderId, title, body, pinnedAt, archivedAt, deletedAt, checkedBehavior, isPrimary, sort, createdAt, updatedAt, items
    }

    init(id: String, type: NoteType, folderId: String? = nil, title: String? = nil, body: String? = nil, checkedBehavior: String? = nil,
         at: String) {
        self.id = id
        self.type = type.rawValue
        self.folderId = folderId
        self.title = title
        self.body = body
        self.checkedBehavior = checkedBehavior
        createdAt = at
        updatedAt = at
        items = []
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decodeIfPresent(String.self, forKey: .type) ?? "text"
        folderId = try c.decodeIfPresent(String.self, forKey: .folderId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        pinnedAt = try c.decodeIfPresent(String.self, forKey: .pinnedAt)
        archivedAt = try c.decodeIfPresent(String.self, forKey: .archivedAt)
        deletedAt = try c.decodeIfPresent(String.self, forKey: .deletedAt)
        checkedBehavior = try c.decodeIfPresent(String.self, forKey: .checkedBehavior)
        isPrimary = try c.decodeIfPresent(Bool.self, forKey: .isPrimary)
        sort = try c.decodeIfPresent(Int.self, forKey: .sort)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        items = (try c.decodeIfPresent([NoteItem].self, forKey: .items) ?? []).sorted { $0.position < $1.position }
    }

    var kind: NoteType { .of(type) }
    var pinned: Bool { pinnedAt != nil }
    var archived: Bool { archivedAt != nil }
    var deleted: Bool { deletedAt != nil }
    var active: Bool { archivedAt == nil && deletedAt == nil }
    var isShopping: Bool { kind == .shopping }
    var primary: Bool { isPrimary == true }
    var movesChecked: Bool { checkedBehavior != "inline" }
    var checkedCount: Int { items.filter(\.checked).count }
    var openCount: Int { items.count - checkedCount }
    var updated: Date { updatedAt.flatMap(CarliDate.instant) ?? .distantPast }

    var displayTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty { return title }
        let firstLine = (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").first
        if let firstLine, !firstLine.trimmingCharacters(in: .whitespaces).isEmpty { return firstLine.trimmingCharacters(in: .whitespaces) }
        switch kind {
        case .shopping: return "Lista de la compra"
        case .list: return "Lista sin título"
        case .text: return "Nota sin título"
        }
    }

    var isEmpty: Bool {
        (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && items.isEmpty
    }

    /// One line under the title in lists of notes.
    var preview: String {
        switch kind {
        case .text:
            return (body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s*\n\s*"#, with: " · ", options: .regularExpression)
        case .list: return items.isEmpty ? "Sin elementos" : "\(checkedCount) de \(items.count)"
        case .shopping: return openCount == 0 ? "Nada por comprar" : "\(openCount) por comprar"
        }
    }
}

struct ShoppingSection: Decodable, Identifiable, Hashable {
    var id: String
    var name: String
    var position: Int
}

struct ShoppingProduct: Decodable, Identifiable, Hashable {
    var id: String
    var noteId: String
    var name: String
    var sectionId: String?
    var defaultQuantity: String?
    var restockMode: String?
    var restockIntervalDays: Int?
    var lastBoughtAt: String?
    var timesBought: Int?
    var restockedFor: String?

    var restock: RestockMode { .of(restockMode) }
    var lastBought: Date? { lastBoughtAt.flatMap(CarliDate.instant) }

    var restockLabel: String {
        switch restock {
        case .none: "Sin repetir"
        case .everyTrip: "Cada compra"
        case .interval: Self.intervalLabel(restockIntervalDays ?? 7)
        }
    }

    /// The day the product comes back to its list, counted from the local date of its last purchase.
    var restockDate: Date? {
        guard let bought = lastBought else { return nil }
        let day = CarliDate.calendar.startOfDay(for: bought)
        switch restock {
        case .none: return nil
        case .everyTrip: return day
        case .interval:
            guard let days = restockIntervalDays, days >= 1 else { return nil }
            return CarliDate.calendar.date(byAdding: .day, value: days, to: day)
        }
    }

    static func intervalLabel(_ days: Int) -> String {
        if days % 30 == 0 { return days == 30 ? "Cada mes" : "Cada \(days / 30) meses" }
        if days % 7 == 0 { return days == 7 ? "Cada semana" : "Cada \(days / 7) semanas" }
        return days == 1 ? "Cada día" : "Cada \(days) días"
    }
}

struct NotesSnapshot: Decodable, Equatable {
    var folders: [NoteFolder]
    var notes: [Note]
    var sections: [ShoppingSection]
    var products: [ShoppingProduct]

    private enum CodingKeys: String, CodingKey { case folders, notes, sections, products }

    init(folders: [NoteFolder] = [], notes: [Note] = [], sections: [ShoppingSection] = [], products: [ShoppingProduct] = []) {
        self.folders = folders
        self.notes = notes
        self.sections = sections
        self.products = products
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        folders = try c.decodeIfPresent([NoteFolder].self, forKey: .folders) ?? []
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
        sections = (try c.decodeIfPresent([ShoppingSection].self, forKey: .sections) ?? []).sorted { $0.position < $1.position }
        products = try c.decodeIfPresent([ShoppingProduct].self, forKey: .products) ?? []
    }

    static func == (lhs: NotesSnapshot, rhs: NotesSnapshot) -> Bool {
        lhs.notes == rhs.notes && lhs.folders == rhs.folders && lhs.sections == rhs.sections && lhs.products == rhs.products
    }

    func note(_ id: String) -> Note? { notes.first { $0.id == id } }
    func folder(_ id: String?) -> NoteFolder? { id.flatMap { id in folders.first { $0.id == id } } }
    func products(of noteId: String) -> [ShoppingProduct] { products.filter { $0.noteId == noteId } }

    private static func byPinnedThenRecent(_ a: Note, _ b: Note) -> Bool {
        if a.pinned != b.pinned { return a.pinned }
        return a.updated > b.updated
    }

    var activeNotes: [Note] { notes.filter(\.active).sorted(by: Self.byPinnedThenRecent) }
    var archivedNotes: [Note] { notes.filter { $0.archived && !$0.deleted }.sorted(by: Self.byPinnedThenRecent) }
    var trashedNotes: [Note] { notes.filter(\.deleted).sorted { ($0.deletedAt ?? "") > ($1.deletedAt ?? "") } }
    var pinned: [Note] { activeNotes.filter(\.pinned) }
    var recent: [Note] { activeNotes.filter { !$0.pinned } }
    func notes(in folderId: String) -> [Note] { activeNotes.filter { $0.folderId == folderId } }
    var shoppingNotes: [Note] { activeNotes.filter(\.isShopping) }

    var primaryShopping: Note? {
        let lists = notes.filter { $0.active && $0.isShopping }
        return lists.first { $0.primary } ?? lists.first
    }

    // MARK: Folder tree

    func children(of parentId: String?) -> [NoteFolder] {
        let ids = Set(folders.map(\.id))
        return folders
            .filter { (($0.parentId).map(ids.contains) == true ? $0.parentId : nil) == parentId }
            .sorted { $0.position != $1.position ? $0.position < $1.position : $0.name < $1.name }
    }

    /// From the top folder down to `id`, both included.
    func path(to id: String?) -> [NoteFolder] {
        var path: [NoteFolder] = []
        var seen = Set<String>()
        var current = folder(id)
        while let folder = current, seen.insert(folder.id).inserted {
            path.insert(folder, at: 0)
            current = self.folder(folder.parentId)
        }
        return path
    }

    func descendantsAndSelf(_ id: String) -> Set<String> {
        var result: Set<String> = [id]
        var pending = [id]
        while let next = pending.popLast() {
            for child in children(of: next) where result.insert(child.id).inserted { pending.append(child.id) }
        }
        return result
    }

    /// Depth-first order for the folder picker, with each folder's depth.
    func flattenedFolders(excluding: String? = nil) -> [(NoteFolder, Int)] {
        var result: [(NoteFolder, Int)] = []
        func visit(_ parent: String?, _ depth: Int) {
            for folder in children(of: parent) where folder.id != excluding {
                result.append((folder, depth))
                visit(folder.id, depth + 1)
            }
        }
        visit(nil, 0)
        return result
    }

    func recursiveCount(_ folderId: String) -> Int {
        let ids = descendantsAndSelf(folderId)
        return activeNotes.filter { $0.folderId.map(ids.contains) == true }.count
    }

    func folderPath(of note: Note) -> [String] { path(to: note.folderId).map(\.name) }

    /// Accent-insensitive search over title, body and items, active and archived.
    func search(_ query: String, filter: NoteType?) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return (activeNotes + archivedNotes).filter { note in
            (filter == nil || note.kind == filter)
                && (trimmed.isEmpty || TextFold.contains(([note.title ?? "", note.body ?? ""] + note.items.map(\.text))
                    .joined(separator: "\n"), trimmed))
        }
    }
}

enum TextFold {
    /// Lower case without accents and with single spaces.
    static func fold(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    static func contains(_ haystack: String, _ needle: String) -> Bool {
        let folded = fold(haystack)
        return fold(needle).split(separator: " ").allSatisfy { folded.contains($0) }
    }
}

struct NoteSearchHit: Decodable, Identifiable {
    var id: String
    var type: String?
    var title: String?
    var snippet: String?
    var folderPath: [String]?
    var archived: Bool?
}
