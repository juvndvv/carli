import SwiftUI

struct NoteRoute: Hashable { var id: String; var fresh = false }
struct FolderRoute: Hashable { var id: String }
struct NotesCollectionRoute: Hashable { var trash: Bool }
struct NotesSettingsRoute: Hashable {}

extension View {
    /// Pages every Notas section can push, plus the store's toasts and "Deshacer".
    func notesDestinations(_ store: NotesStore) -> some View {
        navigationDestination(for: NoteRoute.self) { NoteEditorView(store: store, noteId: $0.id, fresh: $0.fresh) }
            .navigationDestination(for: FolderRoute.self) { FolderView(store: store, folderId: $0.id) }
            .navigationDestination(for: NotesCollectionRoute.self) { NotesCollectionView(store: store, trash: $0.trash) }
            .navigationDestination(for: NotesSettingsRoute.self) { _ in NotesSettingsView(store: store) }
    }

    func notesFeedback(_ store: NotesStore) -> some View { modifier(NotesFeedback(store: store)) }
}

private struct NotesFeedback: ViewModifier {
    @Bindable var store: NotesStore

    func body(content: Content) -> some View {
        content
            .undoBar($store.undo, seconds: 4)
            .carliToast($store.toast)
    }
}

/// "When" for note rows: the time today, then Ayer, the weekday this week and the date before that.
enum NoteWhen {
    static func label(_ date: Date, now: Date = .now) -> String {
        let calendar = CarliDate.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return TaskDates.time(date)
        case 1: return "Ayer"
        case 2..<7: return String(TaskDates.weekdaysLongMondayFirst[FrequencyDraft.isoWeekday(date) - 1].prefix(3)).capitalizedFirst
        default:
            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            return sameYear ? CarliDate.short(date) : "\(CarliDate.short(date)) \(calendar.component(.year, from: date))"
        }
    }
}

/// Asks for a name in an alert; used for folders, sections and list names.
struct NamePrompt: ViewModifier {
    var title: String
    @Binding var isPresented: Bool
    var initial = ""
    var placeholder = "Nombre"
    var confirm = "Guardar"
    var save: (String) -> Void
    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                TextField(placeholder, text: $text)
                Button("Cancelar", role: .cancel) {}
                Button(confirm) {
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { save(trimmed) }
                }
            }
            .onChange(of: isPresented) { _, shown in if shown { text = initial } }
    }
}

extension View {
    func namePrompt(_ title: String, isPresented: Binding<Bool>, initial: String = "", placeholder: String = "Nombre",
                    confirm: String = "Guardar", save: @escaping (String) -> Void) -> some View {
        modifier(NamePrompt(title: title, isPresented: isPresented, initial: initial, placeholder: placeholder, confirm: confirm, save: save))
    }
}

// MARK: Rows

struct NoteRow: View {
    var note: Note
    var path: [String] = []
    var preview: String?

    var body: some View {
        HStack(spacing: CarliSpace.s12) {
            Image(systemName: note.kind.symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .background(CarliColor.surface2, in: .rect(cornerRadius: CarliRadius.chip, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(note.displayTitle).font(.body.weight(.semibold))
                let subtitle = preview ?? note.preview
                if !subtitle.isEmpty {
                    Text(subtitle).font(.footnote).foregroundStyle(CarliColor.text2)
                }
                if !path.isEmpty {
                    Label(path.joined(separator: " › "), systemImage: "folder")
                        .font(.caption)
                        .foregroundStyle(CarliColor.text3)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Text(NoteWhen.label(note.updated)).font(.footnote).foregroundStyle(CarliColor.text2)
        }
        .foregroundStyle(CarliColor.text)
        .contentShape(.rect)
    }
}

/// Menu entries shared by a note's "···" button and its context menu.
struct NoteMenuItems: View {
    var store: NotesStore
    var note: Note
    var onMove: () -> Void
    var onOpen: (String) -> Void = { _ in }
    var onRemoved: () -> Void = {}

    var body: some View {
        Button(note.pinned ? "Quitar de fijadas" : "Fijar", systemImage: note.pinned ? "pin.slash" : "pin") {
            store.setFlag(note.id, "pinned", !note.pinned)
        }
        Button("Mover a carpeta", systemImage: "folder") { onMove() }
        Button("Duplicar", systemImage: "plus.square.on.square") { onOpen(store.duplicate(note)) }
        if note.kind == .text {
            Button("Convertir en lista", systemImage: "checklist") { store.convert(note) }
        } else if note.kind == .list {
            Button("Convertir en texto", systemImage: "note.text") { store.convert(note) }
        }
        Button(note.archived ? "Sacar del archivo" : "Archivar", systemImage: "archivebox") {
            store.archive(note)
            if !note.archived { onRemoved() }
        }
        Button("Borrar", systemImage: "trash", role: .destructive) {
            store.delete(note)
            onRemoved()
        }
    }
}

/// Tree of folders to move a note or a folder into.
struct FolderPicker: View {
    var store: NotesStore
    var title: String
    var current: String?
    var excluding: String?
    var pick: (String?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row(id: nil, name: "Notas (sin carpeta)", depth: 0, symbol: "house")
                ForEach(store.snapshot?.flattenedFolders(excluding: excluding) ?? [], id: \.0.id) { folder, depth in
                    row(id: folder.id, name: folder.name, depth: depth, symbol: "folder")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(id: String?, name: String, depth: Int, symbol: String) -> some View {
        Button {
            pick(id)
            dismiss()
        } label: {
            HStack {
                Label(name, systemImage: symbol).padding(.leading, CGFloat(depth) * 20)
                Spacer()
                if id == current { Image(systemName: "checkmark").foregroundStyle(CarliColor.text) }
            }
            .foregroundStyle(CarliColor.text)
        }
    }
}

/// "Nueva": text, list or shopping list.
struct NewNoteSheet: View {
    var pick: (NoteType) -> Void
    @Environment(\.dismiss) private var dismiss

    private let options: [(NoteType, String, String)] = [
        (.text, "Texto", "Apuntes, datos, ideas"),
        (.list, "Lista", "Elementos que marcas. Reutilizable con \"Empezar de nuevo\""),
        (.shopping, "Lista de la compra", "Por secciones, con habituales y sugerencias"),
    ]

    var body: some View {
        NavigationStack {
            List(options, id: \.0) { type, title, subtitle in
                Button {
                    dismiss()
                    pick(type)
                } label: {
                    HStack(spacing: CarliSpace.s12) {
                        IconBubble(symbol: type.symbol, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.headline)
                            Text(subtitle).font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                    }
                    .foregroundStyle(CarliColor.text)
                }
            }
            .navigationTitle("Nueva")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

// MARK: Notas

struct NotesHomeView: View {
    var store: NotesStore
    var create: () -> Void

    @State private var query = ""
    @State private var filter: NoteType?
    @State private var hits: [NoteSearchHit]?
    @State private var newFolder = false
    @State private var moving: Note?

    var body: some View {
        List {
            Section {
                ScrollView(.horizontal) {
                    HStack(spacing: CarliSpace.s8) {
                        Chip(label: "Todas", selected: filter == nil) { filter = nil }
                        Chip(label: "Texto", selected: filter == .text) { filter = .text }
                        Chip(label: "Listas", selected: filter == .list) { filter = .list }
                        Chip(label: "Compra", selected: filter == .shopping) { filter = .shopping }
                    }
                }
                .scrollIndicators(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: CarliSpace.s4, bottom: 0, trailing: CarliSpace.s4))
            }
            if let snapshot = store.snapshot {
                if query.trimmingCharacters(in: .whitespaces).isEmpty && filter == nil {
                    browse(snapshot)
                } else {
                    results(snapshot)
                }
            } else if let failed = store.failed {
                ContentUnavailableView {
                    Label("No se han podido cargar las notas", systemImage: "exclamationmark.circle")
                } description: { Text(failed) } actions: {
                    Button("Reintentar") { Task { await store.load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar en notas")
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { hits = nil; return }
            try? await Task.sleep(for: .milliseconds(250))
            if let found: DataEnvelope<[NoteSearchHit]> = try? await store.api.get("v1/notes/search", query: ["q": trimmed]) {
                hits = found.data
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Nueva carpeta", systemImage: "folder.badge.plus") { newFolder = true }
                    NavigationLink(value: NotesCollectionRoute(trash: false)) { Label("Archivadas", systemImage: "archivebox") }
                    NavigationLink(value: NotesCollectionRoute(trash: true)) { Label("Papelera", systemImage: "trash") }
                    NavigationLink(value: NotesSettingsRoute()) { Label("Ajustes de Notas", systemImage: "gearshape") }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Más opciones")
            }
        }
        .refreshable { await store.load() }
        .task { await store.load() }
        .notesDestinations(store)
        .notesFeedback(store)
        .namePrompt("Nueva carpeta", isPresented: $newFolder, confirm: "Crear") { store.createFolder($0) }
        .sheet(item: $moving) { note in
            FolderPicker(store: store, title: "Mover a", current: note.folderId) { folder in
                store.moveNote(note.id, to: folder)
                store.toast = "Movida a \(store.snapshot?.folder(folder)?.name ?? "Notas")"
            }
        }
    }

    @ViewBuilder
    private func browse(_ snapshot: NotesSnapshot) -> some View {
        let folders = snapshot.children(of: nil)
        if snapshot.pinned.isEmpty && folders.isEmpty && snapshot.recent.isEmpty {
            ContentUnavailableView {
                Label("Sin notas todavía", systemImage: "note.text")
            } description: {
                Text("Apuntes, listas que reutilizas y la lista de la compra. Pulsa + para empezar.")
            } actions: {
                Button("Nueva nota", action: create).buttonStyle(.glass)
            }
        }
        if !snapshot.pinned.isEmpty {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: CarliSpace.s8), GridItem(.flexible())], spacing: CarliSpace.s8) {
                    ForEach(snapshot.pinned) { note in
                        NavigationLink(value: NoteRoute(id: note.id)) { PinnedCard(note: note) }
                            .buttonStyle(.plain)
                            .contextMenu { NoteMenuItems(store: store, note: note) { moving = note } }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: { header("Fijadas") }
        }
        Section {
            if folders.isEmpty {
                Text("Agrupa notas en carpetas, también unas dentro de otras.")
                    .font(.footnote).foregroundStyle(CarliColor.text2)
            }
            ForEach(folders) { folder in
                NavigationLink(value: FolderRoute(id: folder.id)) {
                    FolderRowLabel(folder: folder, count: snapshot.recursiveCount(folder.id))
                }
            }
        } header: {
            HStack {
                header("Carpetas")
                Spacer()
                Button("Nueva") { newFolder = true }.font(.subheadline).textCase(nil)
            }
        }
        if !snapshot.recent.isEmpty {
            Section {
                ForEach(snapshot.recent) { note in
                    NavigationLink(value: NoteRoute(id: note.id)) { NoteRow(note: note, path: snapshot.folderPath(of: note)) }
                        .swipeActions { Button("Borrar", systemImage: "trash", role: .destructive) { store.delete(note) } }
                        .contextMenu { NoteMenuItems(store: store, note: note) { moving = note } }
                }
            } header: { header("Recientes") }
        }
    }

    @ViewBuilder
    private func results(_ snapshot: NotesSnapshot) -> some View {
        let rows: [(Note, String?)] = if let hits, !query.trimmingCharacters(in: .whitespaces).isEmpty {
            hits.compactMap { hit in snapshot.note(hit.id).flatMap { filter == nil || $0.kind == filter ? ($0, hit.snippet) : nil } }
        } else {
            snapshot.search(query, filter: filter).map { ($0, nil) }
        }
        if rows.isEmpty {
            ContentUnavailableView("Nada por aquí", systemImage: "magnifyingglass",
                                   description: Text("Prueba con otra palabra o cambia el filtro."))
        } else {
            Section {
                ForEach(rows, id: \.0.id) { note, snippet in
                    NavigationLink(value: NoteRoute(id: note.id)) {
                        NoteRow(note: note, path: snapshot.folderPath(of: note), preview: snippet)
                    }
                }
            }
        }
    }

    private func header(_ title: String) -> some View {
        Text(title).font(.title3.weight(.bold)).foregroundStyle(CarliColor.text).textCase(nil)
    }
}

private struct PinnedCard: View {
    var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: CarliSpace.s8) {
            Label(note.kind.label, systemImage: note.kind.symbol).font(.footnote).foregroundStyle(CarliColor.text2)
            Text(note.displayTitle).font(.headline).lineLimit(1)
            switch note.kind {
            case .shopping:
                Text("\(Text("\(note.openCount)").font(.title2.weight(.semibold))) \(Text("por comprar").font(.footnote).foregroundStyle(CarliColor.text2))")
            case .list where !note.items.isEmpty:
                Text("\(Text("\(note.checkedCount)").font(.title2.weight(.semibold))) \(Text("de \(note.items.count)").font(.footnote).foregroundStyle(CarliColor.text2))")
            default:
                Text(note.preview).font(.footnote).foregroundStyle(CarliColor.text2).lineLimit(2)
            }
        }
        .foregroundStyle(CarliColor.text)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(CarliColor.surface, in: .rect(cornerRadius: CarliRadius.card, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(note.displayTitle), fijada")
    }
}

private struct FolderRowLabel: View {
    var folder: NoteFolder
    var count: Int

    var body: some View {
        HStack(spacing: CarliSpace.s12) {
            Image(systemName: "folder.fill")
                .frame(width: 32, height: 32)
                .background(CarliColor.surface2, in: .rect(cornerRadius: CarliRadius.chip, style: .continuous))
            Text(folder.name).font(.body.weight(.semibold))
            Spacer()
            Text("\(count)").font(.footnote).foregroundStyle(CarliColor.text2)
        }
        .foregroundStyle(CarliColor.text)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Carpeta

struct FolderView: View {
    var store: NotesStore
    var folderId: String

    @Environment(\.dismiss) private var dismiss
    @State private var newSubfolder = false
    @State private var renaming = false
    @State private var movingFolder = false
    @State private var confirmingDelete = false
    @State private var movingNote: Note?
    @State private var addingNote = false
    @State private var opened: NoteRoute?

    var body: some View {
        let snapshot = store.snapshot ?? NotesSnapshot()
        Group {
            if let folder = snapshot.folder(folderId) {
                content(snapshot, folder)
            } else {
                ContentUnavailableView("Esta carpeta ya no existe", systemImage: "folder",
                                       description: Text("Puede que la hayas borrado o movido desde otro sitio."))
            }
        }
        .navigationTitle(snapshot.folder(folderId)?.name ?? "Carpeta")
        .navigationDestination(item: $opened) { NoteEditorView(store: store, noteId: $0.id, fresh: $0.fresh) }
    }

    private func content(_ snapshot: NotesSnapshot, _ folder: NoteFolder) -> some View {
        let path = snapshot.path(to: folder.parentId)
        let subfolders = snapshot.children(of: folder.id)
        let notes = snapshot.notes(in: folder.id)
        let parentName = snapshot.folder(folder.parentId)?.name ?? "Notas"
        return List {
            if !path.isEmpty {
                Text((["Notas"] + path.map(\.name)).joined(separator: " › "))
                    .font(.footnote).foregroundStyle(CarliColor.text2)
                    .listRowBackground(Color.clear)
            }
            if !subfolders.isEmpty {
                Section("Carpetas") {
                    ForEach(subfolders) { child in
                        NavigationLink(value: FolderRoute(id: child.id)) {
                            FolderRowLabel(folder: child, count: snapshot.recursiveCount(child.id))
                        }
                    }
                }
            }
            Section("Notas") {
                if notes.isEmpty {
                    Text("Pulsa + para crear una nota en esta carpeta.").font(.footnote).foregroundStyle(CarliColor.text2)
                }
                ForEach(notes) { note in
                    NavigationLink(value: NoteRoute(id: note.id)) { NoteRow(note: note) }
                        .swipeActions { Button("Borrar", systemImage: "trash", role: .destructive) { store.delete(note) } }
                        .contextMenu { NoteMenuItems(store: store, note: note) { movingNote = note } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Nueva nota", systemImage: "square.and.pencil") { addingNote = true }
                Menu {
                    Button("Nueva subcarpeta", systemImage: "folder.badge.plus") { newSubfolder = true }
                    Button("Renombrar", systemImage: "pencil") { renaming = true }
                    Button("Mover", systemImage: "folder") { movingFolder = true }
                    Button("Borrar carpeta", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Opciones de la carpeta")
            }
        }
        .namePrompt("Nueva subcarpeta", isPresented: $newSubfolder, confirm: "Crear") { store.createFolder($0, parentId: folder.id) }
        .namePrompt("Renombrar carpeta", isPresented: $renaming, initial: folder.name) { store.renameFolder(folder.id, $0) }
        .sheet(isPresented: $movingFolder) {
            FolderPicker(store: store, title: "Mover carpeta a", current: folder.parentId, excluding: folder.id) { parent in
                if !store.moveFolder(folder.id, to: parent) { store.toast = "No se puede mover dentro de sí misma." }
            }
        }
        .sheet(item: $movingNote) { note in
            FolderPicker(store: store, title: "Mover a", current: note.folderId) { store.moveNote(note.id, to: $0) }
        }
        .sheet(isPresented: $addingNote) {
            NewNoteSheet { type in opened = NoteRoute(id: store.createNote(type, folderId: folder.id), fresh: true) }
        }
        .confirmationDialog("Borrar “\(folder.name)”", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Borrar carpeta", role: .destructive) {
                store.deleteFolder(folder.id)
                dismiss()
            }
        } message: {
            Text("Sus notas y subcarpetas pasan a \(parentName). No se borra ninguna nota.")
        }
    }
}

// MARK: Archivadas y papelera

struct NotesCollectionView: View {
    var store: NotesStore
    var trash: Bool

    @State private var purging: Note?
    @State private var confirmingEmpty = false

    var body: some View {
        let notes = trash ? (store.snapshot?.trashedNotes ?? []) : (store.snapshot?.archivedNotes ?? [])
        List {
            Section {
                ForEach(notes) { note in
                    HStack(spacing: CarliSpace.s12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.displayTitle).font(.body.weight(.semibold)).lineLimit(1)
                            let when = (trash ? note.deletedAt : note.archivedAt).flatMap(CarliDate.instant) ?? note.updated
                            Text("\(trash ? "Borrada" : "Archivada") \(NoteWhen.label(when).lowercased())")
                                .font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                        Spacer()
                        Button(trash ? "Restaurar" : "Sacar") {
                            store.setFlag(note.id, trash ? "deleted" : "archived", false)
                        }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        Button("Borrar definitivamente", systemImage: "trash") { purging = note }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(CarliColor.negative)
                            .buttonStyle(.borderless)
                    }
                    .foregroundStyle(CarliColor.text)
                }
            } footer: {
                Text(trash ? "Las notas se borran definitivamente a los 30 días."
                     : "Fuera de la vista principal, pero siguen apareciendo en la búsqueda.")
            }
        }
        .overlay {
            if notes.isEmpty {
                ContentUnavailableView(trash ? "La papelera está vacía" : "No hay notas archivadas",
                                       systemImage: trash ? "trash" : "archivebox",
                                       description: Text(trash ? "Lo que borres aparecerá aquí 30 días." : "Archiva lo que ya no usas a diario."))
            }
        }
        .navigationTitle(trash ? "Papelera" : "Archivadas")
        .toolbar {
            if trash && !notes.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Vaciar papelera", role: .destructive) { confirmingEmpty = true }
                }
            }
        }
        .confirmationDialog("Borrar definitivamente", isPresented: Binding(get: { purging != nil }, set: { if !$0 { purging = nil } }),
                            titleVisibility: .visible, presenting: purging) { note in
            Button("Borrar", role: .destructive) { store.purge(note.id) }
        } message: { note in
            Text("“\(note.displayTitle)” no se podrá recuperar.")
        }
        .confirmationDialog("Vaciar papelera", isPresented: $confirmingEmpty, titleVisibility: .visible) {
            Button("Vaciar", role: .destructive) { store.record(notes.map { NoteOperation(type: "note.purge", payload: ["id": .string($0.id)]) }) }
        } message: {
            Text("Se borran definitivamente \(notes.count) notas.")
        }
        .notesFeedback(store)
    }
}
