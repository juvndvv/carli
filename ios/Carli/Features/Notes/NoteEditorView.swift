import SwiftUI

/// Opens a note by id: text editor, checklist or shopping list, with a banner when archived or in the trash.
struct NoteEditorView: View {
    var store: NotesStore
    var noteId: String
    var fresh = false

    var body: some View {
        if let note = store.snapshot?.note(noteId) {
            switch note.kind {
            case .text: TextNoteEditor(store: store, note: note, fresh: fresh)
            case .list: ListNoteEditor(store: store, note: note, fresh: fresh)
            case .shopping: ShoppingListView(store: store, noteId: note.id, switchable: false, fresh: fresh)
            }
        } else if store.snapshot == nil {
            ProgressView()
        } else {
            ContentUnavailableView("Esta nota ya no existe", systemImage: "note.text",
                                   description: Text("Puede que la hayas borrado definitivamente."))
        }
    }
}

private struct RemovedBanner: View {
    var store: NotesStore
    var note: Note

    var body: some View {
        if note.deleted || note.archived {
            HStack {
                Text(note.deleted ? "Está en la papelera." : "Está archivada.").font(.footnote)
                Spacer()
                Button(note.deleted ? "Restaurar" : "Sacar del archivo") {
                    store.setFlag(note.id, note.deleted ? "deleted" : "archived", false)
                }
                .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(CarliColor.text)
            .padding(CarliSpace.s12)
            .background(CarliColor.surface2, in: .rect(cornerRadius: CarliRadius.control, style: .continuous))
        }
    }
}

// MARK: Texto

private struct TextNoteEditor: View {
    var store: NotesStore
    var note: Note
    var fresh: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var bodyText: String
    @State private var dirty = false
    @State private var moving = false
    @FocusState private var focus: Field?

    private enum Field { case title, body }

    init(store: NotesStore, note: Note, fresh: Bool) {
        self.store = store
        self.note = note
        self.fresh = fresh
        _title = State(initialValue: note.title ?? "")
        _bodyText = State(initialValue: note.body ?? "")
    }

    var body: some View {
        let path = store.snapshot?.folderPath(of: note) ?? []
        let edited = "Editada \(CarliDate.relative(note.updated).replacingOccurrences(of: "ahora", with: "ahora mismo"))"
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                RemovedBanner(store: store, note: note)
                Text(([edited] + (note.pinned ? ["Fijada"] : []) + (path.isEmpty ? [] : [path.joined(separator: " › ")]))
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(CarliColor.text2)
                TextField("Título", text: $title)
                    .font(.title.weight(.bold))
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focus = .body }
                TextField("Escribe aquí", text: $bodyText, axis: .vertical)
                    .font(.body)
                    .lineSpacing(4)
                    .focused($focus, equals: .body)
                    .frame(maxWidth: .infinity, minHeight: 300, alignment: .topLeading)
            }
            .padding(.horizontal, CarliSpace.s20)
            .padding(.bottom, CarliSpace.s48)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(CarliColor.surface)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(dirty ? "Guardando…" : "Guardado").font(.caption).foregroundStyle(CarliColor.text2)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(note.pinned ? "Quitar de fijadas" : "Fijar", systemImage: note.pinned ? "pin.fill" : "pin") {
                    store.setFlag(note.id, "pinned", !note.pinned)
                }
                Menu {
                    NoteMenuItems(store: store, note: note, onMove: { moving = true }, onRemoved: { dismiss() })
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Más opciones")
            }
            if focus != nil {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Listo") { focus = nil }
                    }
                }
            }
        }
        .onAppear { if fresh { focus = .title } }
        .onChange(of: title) { dirty = true }
        .onChange(of: bodyText) { dirty = true }
        .task(id: "\(title)\u{1F}\(bodyText)") {
            guard dirty else { return }
            try? await Task.sleep(for: .milliseconds(600))
            flush()
        }
        .onDisappear {
            flush()
            store.discardIfEmpty(note.id)
        }
        .sheet(isPresented: $moving) {
            FolderPicker(store: store, title: "Mover a", current: note.folderId) { store.moveNote(note.id, to: $0) }
        }
        .notesFeedback(store)
    }

    private func flush() {
        guard dirty else { return }
        dirty = false
        let newTitle = title != (note.title ?? "") ? title : nil
        let newBody = bodyText != (note.body ?? "") ? bodyText : nil
        if newTitle != nil || newBody != nil { store.updateNote(note.id, title: newTitle, body: newBody) }
    }
}

// MARK: Lista

private struct ListNoteEditor: View {
    var store: NotesStore
    var note: Note
    var fresh: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var newItem = ""
    @State private var showDone = false
    @State private var confirmingStartOver = false
    @State private var moving = false
    @FocusState private var focus: String?

    init(store: NotesStore, note: Note, fresh: Bool) {
        self.store = store
        self.note = note
        self.fresh = fresh
        _title = State(initialValue: note.title ?? "")
    }

    var body: some View {
        let moves = note.movesChecked
        let visible = moves ? note.items.filter { !$0.checked } : note.items
        let done = moves ? note.items.filter(\.checked) : []
        List {
            Section {
                RemovedBanner(store: store, note: note)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                TextField("Título", text: $title)
                    .font(.title.weight(.bold))
                    .focused($focus, equals: "title")
                    .submitLabel(.next)
                    .onSubmit { focus = "new" }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: CarliSpace.s4, bottom: CarliSpace.s8, trailing: CarliSpace.s4))
            }
            Section {
                ForEach(visible) { item in
                    ItemRow(store: store, item: item, focus: $focus) { focus = store.addItem(note.id, "", at: item.position + 1) }
                        .swipeActions { DeleteSwipeButton("Borrar") { store.deleteItem(item) } }
                }
                .onMove { from, to in
                    var ordered = visible
                    ordered.move(fromOffsets: from, toOffset: to)
                    store.reorderItems(ordered + done)
                }
                HStack(spacing: CarliSpace.s12) {
                    Image(systemName: "plus").foregroundStyle(CarliColor.text2).frame(width: 24)
                    TextField("Nuevo elemento", text: $newItem)
                        .focused($focus, equals: "new")
                        .submitLabel(.next)
                        .onSubmit {
                            let text = newItem.trimmingCharacters(in: .whitespaces)
                            guard !text.isEmpty else { return }
                            store.addItem(note.id, text)
                            newItem = ""
                            focus = "new"
                        }
                }
            }
            if !done.isEmpty {
                Section {
                    if showDone {
                        ForEach(done) { item in
                            ItemRow(store: store, item: item, focus: $focus, onSubmit: nil)
                                .swipeActions { DeleteSwipeButton("Borrar") { store.deleteItem(item) } }
                        }
                    }
                } header: {
                    HStack {
                        Text("Hechos · \(done.count)")
                        Spacer()
                        Button(showDone ? "Ocultar" : "Mostrar") { withAnimation { showDone.toggle() } }.textCase(nil)
                    }
                }
            }
            Section {
                Button { confirmingStartOver = true } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Empezar de nuevo")
                            Text("Desmarca todo. Se reinicia a mano.").font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                    } icon: { Image(systemName: "arrow.counterclockwise") }
                }
                .foregroundStyle(CarliColor.text)
                .disabled(note.checkedCount == 0)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(note.pinned ? "Quitar de fijadas" : "Fijar", systemImage: note.pinned ? "pin.fill" : "pin") {
                    store.setFlag(note.id, "pinned", !note.pinned)
                }
                Menu {
                    Button("Empezar de nuevo", systemImage: "arrow.counterclockwise") { confirmingStartOver = true }
                    if note.movesChecked {
                        Button("Dejar los marcados en su sitio", systemImage: "list.bullet") { store.setCheckedBehavior(note.id, inline: true) }
                    } else {
                        Button("Bajar los marcados a “Hechos”", systemImage: "arrow.down.to.line") { store.setCheckedBehavior(note.id, inline: false) }
                    }
                    Divider()
                    NoteMenuItems(store: store, note: note, onMove: { moving = true }, onRemoved: { dismiss() })
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("Más opciones")
            }
        }
        .onAppear { if fresh { focus = (note.title ?? "").isEmpty ? "title" : "new" } }
        .onChange(of: focus) { old, _ in
            if old == "title", title != (note.title ?? "") { store.updateNote(note.id, title: title) }
        }
        .onDisappear {
            if title != (note.title ?? "") { store.updateNote(note.id, title: title) }
            store.discardIfEmpty(note.id)
        }
        .confirmationDialog("Empezar de nuevo", isPresented: $confirmingStartOver, titleVisibility: .visible) {
            Button("Desmarcar todo") { store.uncheckAll(note) }
        } message: {
            Text("Se desmarcan todos los elementos de la lista.")
        }
        .sheet(isPresented: $moving) {
            FolderPicker(store: store, title: "Mover a", current: note.folderId) { store.moveNote(note.id, to: $0) }
        }
        .notesFeedback(store)
    }
}

/// A checklist row: tap the circle to mark, edit the text in place, Return adds a row below.
private struct ItemRow: View {
    var store: NotesStore
    var item: NoteItem
    var focus: FocusState<String?>.Binding
    var onSubmit: (() -> Void)?

    @State private var text: String

    init(store: NotesStore, item: NoteItem, focus: FocusState<String?>.Binding, onSubmit: (() -> Void)?) {
        self.store = store
        self.item = item
        self.focus = focus
        self.onSubmit = onSubmit
        _text = State(initialValue: item.text)
    }

    var body: some View {
        HStack(spacing: CarliSpace.s12) {
            Button { store.setChecked(item, !item.checked) } label: {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.checked ? CarliColor.text2 : CarliColor.text3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.checked ? "Desmarcar" : "Marcar")
            TextField("", text: $text)
                .strikethrough(item.checked)
                .foregroundStyle(item.checked ? CarliColor.text2 : CarliColor.text)
                .focused(focus, equals: item.id)
                .submitLabel(.next)
                .onSubmit {
                    commit()
                    onSubmit?()
                }
        }
        .onChange(of: focus.wrappedValue) { old, _ in if old == item.id { commit() } }
        .onChange(of: item.text) { _, fresh in if focus.wrappedValue != item.id { text = fresh } }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            store.deleteItem(item)
        } else if trimmed != item.text {
            store.renameItem(item, trimmed)
        }
    }
}
