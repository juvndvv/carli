import SwiftUI

@Observable
final class CategoriesModel {
    var categories: [FinanceCategory] = []
    var tags: [FinanceTag] = []
    var loaded = false
    var error: String?
    let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        async let categories: Void = loadCategories()
        async let tags: Void = loadTags()
        _ = await (categories, tags)
        loaded = true
    }

    func roots(kind: String, showArchived: Bool) -> [FinanceCategory] {
        categories.filter { $0.kind == kind && (showArchived || !$0.isArchived) }.map { parent in
            var copy = parent
            copy.children = (parent.children ?? []).filter { showArchived || !$0.isArchived }
            return copy
        }
    }

    func archivedCount(kind: String) -> Int {
        categories.filter { $0.kind == kind }.reduce(0) { count, parent in
            count + (parent.isArchived ? 1 : 0) + (parent.children ?? []).filter(\.isArchived).count
        }
    }

    /// Where a deleted category's movements can go: same kind, active, not itself.
    func reassignTargets(for category: FinanceCategory) -> [(id: String, label: String, icon: String)] {
        typealias Target = (id: String, label: String, icon: String)
        let parents = categories.filter { $0.kind == category.kind && !$0.isArchived }
        let targets = parents.flatMap { parent -> [Target] in
            let own: Target = (parent.id, parent.name, parent.icon ?? "tag")
            let children: [Target] = (parent.children ?? []).filter { !$0.isArchived }.map { child in
                (child.id, "\(parent.name) › \(child.name)", child.icon ?? parent.icon ?? "tag")
            }
            return [own] + children
        }
        return targets.filter { $0.id != category.id }
    }

    func setArchived(_ category: FinanceCategory, _ archived: Bool) async throws {
        let _: Empty = try await api.patch("v1/finance/categories/\(category.id)", body: ["archived": archived])
        changed()
        await loadCategories()
    }

    func delete(_ category: FinanceCategory, reassignTo: String?) async throws {
        let query = reassignTo.map { ["reassign_to": $0] } ?? [:]
        let _: Empty = try await api.request("DELETE", "v1/finance/categories/\(category.id)", query: query, body: Optional<Empty>.none)
        changed()
        await loadCategories()
    }

    func renameTag(_ tag: FinanceTag, to name: String) async throws {
        let _: Empty = try await api.patch("v1/finance/tags/\(tag.id)", body: ["name": Self.normalizeTag(name)])
        changed()
        await loadTags()
    }

    func mergeTag(_ tag: FinanceTag, into target: FinanceTag) async throws {
        let _: Empty = try await api.post("v1/finance/tags/\(tag.id)/merge", body: ["into_tag_id": target.id])
        changed()
        await loadTags()
    }

    func deleteTag(_ tag: FinanceTag) async throws {
        try await api.delete("v1/finance/tags/\(tag.id)")
        changed()
        await loadTags()
    }

    static func normalizeTag(_ raw: String) -> String {
        var name = raw.trimmingCharacters(in: .whitespaces)
        while name.hasPrefix("#") { name.removeFirst() }
        return name.trimmingCharacters(in: .whitespaces).lowercased()
    }

    func loadCategories() async {
        do {
            let envelope: DataEnvelope<[FinanceCategory]> = try await api.get("v1/finance/categories", query: ["include_archived": "1"])
            categories = envelope.data
            error = nil
        } catch {
            if categories.isEmpty { self.error = error.apiMessage(fallback: "Comprueba tu conexión e inténtalo de nuevo.") }
        }
    }

    private func loadTags() async {
        if let envelope: DataEnvelope<[FinanceTag]> = try? await api.get("v1/finance/tags") {
            tags = envelope.data
        }
    }

    private func changed() {
        NotificationCenter.default.post(name: .financeChanged, object: nil)
    }
}

/// Más › Categorías y etiquetas.
struct CategoriesView: View {
    enum Tab: String, CaseIterable { case expense = "Gastos", income = "Ingresos", tags = "Etiquetas" }

    @State var model: CategoriesModel
    @State private var tab: Tab = .expense
    @State private var showArchived = false
    @State private var form: CategoryFormTarget?
    @State private var deleting: FinanceCategory?
    @State private var renaming: FinanceTag?
    @State private var merging: FinanceTag?
    @State private var deletingTag: FinanceTag?
    @State private var toast: String?
    @State private var tagName = ""

    private var kind: String { tab == .income ? "income" : "expense" }

    var body: some View {
        List {
            Section {
                Picker("Vista", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if let error = model.error {
                Section { Text(error).foregroundStyle(CarliColor.negative) }
            } else if tab == .tags {
                tagsSection
            } else {
                categoriesSection
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, CarliSpace.s4, for: .scrollContent)
        .navigationTitle("Categorías y etiquetas")
        .toolbar {
            if tab != .tags {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nueva categoría", systemImage: "plus") { form = .new(kind: kind, parentId: nil) }
                }
            }
        }
        .refreshable { await model.load() }
        .task { if !model.loaded { await model.load() } }
        .sheet(item: $form) { target in
            CategoryFormView(model: model, target: target) { toast = $0 }
        }
        .sheet(item: $deleting) { category in
            DeleteCategoryView(model: model, category: category) { toast = $0 }
        }
        .alert("Renombrar etiqueta", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } }), presenting: renaming) { tag in
            TextField("Nombre", text: $tagName)
                .textInputAutocapitalization(.never)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                let name = tagName
                Task {
                    do {
                        try await model.renameTag(tag, to: name)
                        toast = "Etiqueta renombrada"
                    } catch { toast = error.apiMessage(fallback: "No se ha podido renombrar la etiqueta.") }
                }
            }
        }
        .confirmationDialog("¿Eliminar #\(deletingTag?.name ?? "")?", isPresented: Binding(get: { deletingTag != nil }, set: { if !$0 { deletingTag = nil } }),
                            titleVisibility: .visible, presenting: deletingTag) { tag in
            Button("Eliminar", role: .destructive) {
                Task {
                    do {
                        try await model.deleteTag(tag)
                        toast = "Etiqueta eliminada"
                    } catch { toast = error.apiMessage(fallback: "No se ha podido eliminar la etiqueta.") }
                }
            }
        } message: { _ in
            Text("Se quitará de todos sus movimientos. Esta acción no se puede deshacer.")
        }
        .sheet(item: $merging) { tag in
            MergeTagView(model: model, tag: tag) { toast = $0 }
        }
        .carliToast($toast)
    }

    @ViewBuilder
    private var categoriesSection: some View {
        let roots = model.roots(kind: kind, showArchived: showArchived)
        if model.loaded, roots.isEmpty {
            Section {
                ContentUnavailableView {
                    Label("Sin categorías", systemImage: "tag")
                } actions: {
                    Button("Nueva categoría") { form = .new(kind: kind, parentId: nil) }.buttonStyle(.glass)
                }
            }
        }
        ForEach(roots) { parent in
            Section {
                categoryRow(parent, isChild: false)
                ForEach(parent.children ?? []) { child in
                    categoryRow(child, isChild: true, parent: parent)
                }
            }
        }
        let archived = model.archivedCount(kind: kind)
        if archived > 0 {
            Section {
                Button(showArchived ? "Ocultar archivadas" : "Mostrar \(archived == 1 ? "1 archivada" : "\(archived) archivadas")") {
                    withAnimation { showArchived.toggle() }
                }
                .foregroundStyle(CarliColor.text2)
            }
        }
    }

    private func categoryRow(_ category: FinanceCategory, isChild: Bool, parent: FinanceCategory? = nil) -> some View {
        HStack(spacing: CarliSpace.s12) {
            Image(systemName: CarliIcon.symbol(category.icon ?? parent?.icon ?? "tag"))
                .font(.system(size: isChild ? 14 : 16))
                .foregroundStyle(CarliColor.text)
                .frame(width: isChild ? 30 : 36, height: isChild ? 30 : 36)
                .background(CarliColor.surface2, in: .circle)
            VStack(alignment: .leading, spacing: 1) {
                Text(category.name)
                    .font(isChild ? .body : .body.weight(.semibold))
                    .foregroundStyle(CarliColor.text)
                let count = category.children?.count ?? 0
                if !isChild, count > 0 || category.opensPeriod == true {
                    Text([count > 0 ? (count == 1 ? "1 subcategoría" : "\(count) subcategorías") : nil,
                          category.opensPeriod == true ? "abre periodo" : nil].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(CarliColor.text3)
                }
            }
            Spacer()
            if category.isArchived { CarliBadge(label: "Archivada", symbol: "archivebox") }
            Menu {
                Button("Editar", systemImage: "pencil") { form = .edit(category) }
                if !isChild {
                    Button("Añadir subcategoría", systemImage: "plus") { form = .new(kind: category.kind, parentId: category.id) }
                }
                Button(category.isArchived ? "Desarchivar" : "Archivar", systemImage: "archivebox") {
                    Task {
                        do {
                            try await model.setArchived(category, !category.isArchived)
                            toast = category.isArchived ? "\(category.name) recuperada" : "\(category.name) archivada"
                        } catch { toast = error.apiMessage(fallback: "No se ha podido actualizar la categoría.") }
                    }
                }
                Button("Eliminar", systemImage: "trash", role: .destructive) {
                    if !(category.children ?? []).isEmpty {
                        toast = "Tiene subcategorías. Muévelas o elimínalas antes de borrar esta categoría."
                    } else {
                        deleting = category
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(CarliColor.text2)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Opciones de \(category.name)")
        }
        .padding(.leading, isChild ? CarliSpace.s24 : 0)
        .opacity(category.isArchived ? 0.6 : 1)
        .contentShape(.rect)
        .onTapGesture { form = .edit(category) }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if model.tags.isEmpty {
            Section {
                ContentUnavailableView("Sin etiquetas", systemImage: "number",
                                       description: Text("Añade etiquetas desde un movimiento para agrupar gastos que cruzan categorías, como un viaje."))
            }
        } else {
            Section {
                ForEach(model.tags) { tag in
                    HStack {
                        Text("#\(tag.name)").foregroundStyle(CarliColor.text)
                        Spacer()
                        Text(Plural.movements(tag.transactionsCount ?? 0))
                            .font(.footnote)
                            .foregroundStyle(CarliColor.text3)
                        Menu {
                            Button("Renombrar", systemImage: "pencil") {
                                tagName = tag.name
                                renaming = tag
                            }
                            Button("Fusionar con…", systemImage: "arrow.triangle.merge") { merging = tag }
                            Button("Eliminar", systemImage: "trash", role: .destructive) { deletingTag = tag }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(CarliColor.text2)
                                .frame(width: 32, height: 32)
                                .contentShape(.rect)
                        }
                    }
                }
            } footer: {
                Text("Las etiquetas se crean al añadirlas a un movimiento.")
            }
        }
    }
}

private struct MergeTagView: View {
    let model: CategoriesModel
    let tag: FinanceTag
    var onDone: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.tags.filter { $0.id != tag.id }) { target in
                Button {
                    Task {
                        do {
                            try await model.mergeTag(tag, into: target)
                            onDone("#\(tag.name) fusionada con #\(target.name)")
                            dismiss()
                        } catch { onDone(error.apiMessage(fallback: "No se han podido fusionar las etiquetas.")) }
                    }
                } label: {
                    HStack {
                        Text("#\(target.name)").foregroundStyle(CarliColor.text)
                        Spacer()
                        Text(Plural.movements(target.transactionsCount ?? 0)).font(.footnote).foregroundStyle(CarliColor.text3)
                    }
                }
            }
            .navigationTitle("Fusionar #\(tag.name) con…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

enum CategoryFormTarget: Identifiable {
    case new(kind: String, parentId: String?)
    case edit(FinanceCategory)

    var id: String {
        switch self {
        case .new(let kind, let parent): "new-\(kind)-\(parent ?? "")"
        case .edit(let category): category.id
        }
    }
}

struct CategoryFormView: View {
    let model: CategoriesModel
    let target: CategoryFormTarget
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind = "expense"
    @State private var parentId: String?
    @State private var icon: String?
    @State private var opensPeriod = false
    @State private var saving = false
    @State private var error: String?

    private var editing: FinanceCategory? {
        if case .edit(let category) = target { category } else { nil }
    }

    /// A parent with children can't become a child itself.
    private var canChangeParent: Bool { (editing?.children ?? []).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name)
                        .textInputAutocapitalization(.sentences)
                    if editing == nil, parentId == nil {
                        Picker("Tipo", selection: $kind) {
                            Text("Gasto").tag("expense")
                            Text("Ingreso").tag("income")
                        }
                        .pickerStyle(.segmented)
                    }
                    if canChangeParent {
                        Picker("Dentro de", selection: $parentId) {
                            Text("Ninguna (principal)").tag(String?.none)
                            ForEach(model.categories.filter { $0.kind == kind && !$0.isArchived && $0.id != editing?.id }) { parent in
                                Text(parent.name).tag(Optional(parent.id))
                            }
                        }
                    }
                    if kind == "income" {
                        Toggle("Abre un periodo nuevo", isOn: $opensPeriod)
                    }
                } footer: {
                    if kind == "income" {
                        Text("Si un ingreso de esta categoría llega (la nómina, por ejemplo), empieza un periodo financiero nuevo.")
                    }
                }

                Section("Icono") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: CarliSpace.s12) {
                        ForEach(CarliIcon.distinct(CarliIcon.categoryChoices, keeping: icon), id: \.self) { name in
                            let selected = icon == name
                            Button {
                                icon = selected ? nil : name
                            } label: {
                                Image(systemName: CarliIcon.symbol(name))
                                    .font(.system(size: 16))
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(selected ? CarliColor.onPrimary : CarliColor.text)
                                    .background(selected ? CarliColor.primary : CarliColor.surface2, in: .circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, CarliSpace.s4)
                }

                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle(editing == nil ? "Nueva categoría" : "Editar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if saving { ProgressView() } else {
                        Button("Guardar", role: .confirm) { save() }
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .onAppear(perform: fill)
        .onChange(of: kind) { _, _ in
            if editing == nil, case .new(_, nil) = target { parentId = nil; opensPeriod = false }
        }
    }

    private func fill() {
        switch target {
        case .new(let kind, let parent):
            self.kind = kind
            parentId = parent
        case .edit(let category):
            name = category.name
            kind = category.kind
            parentId = category.parentId
            icon = category.icon
            opensPeriod = category.opensPeriod == true
        }
    }

    private struct Payload: Encodable {
        var name: String
        var icon: String?
        var kind: String?
        var parentId: String?
        var opensPeriod: Bool?
        var sendParent: Bool

        private enum CodingKeys: String, CodingKey { case name, icon, kind, parentId, opensPeriod }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(icon, forKey: .icon)
            try container.encodeIfPresent(kind, forKey: .kind)
            if sendParent { try container.encode(parentId, forKey: .parentId) }
            try container.encodeIfPresent(opensPeriod, forKey: .opensPeriod)
        }
    }

    private func save() {
        saving = true
        error = nil
        let payload = Payload(name: name.trimmingCharacters(in: .whitespaces), icon: icon,
                              kind: editing == nil && parentId == nil ? kind : nil,
                              parentId: parentId, opensPeriod: kind == "income" ? opensPeriod : nil,
                              sendParent: canChangeParent && (editing != nil || parentId != nil))
        Task {
            do {
                if let editing {
                    let _: Empty = try await model.api.patch("v1/finance/categories/\(editing.id)", body: payload)
                } else {
                    let _: Empty = try await model.api.post("v1/finance/categories", body: payload)
                }
                NotificationCenter.default.post(name: .financeChanged, object: nil)
                await model.loadCategories()
                onSaved(editing == nil ? "Categoría creada" : "Categoría actualizada")
                dismiss()
            } catch {
                self.error = error.apiMessage(fallback: "No se ha podido guardar la categoría.")
            }
            saving = false
        }
    }
}

private struct DeleteCategoryView: View {
    let model: CategoriesModel
    let category: FinanceCategory
    var onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var target: String?
    @State private var deleting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mover sus movimientos a", selection: $target) {
                        Text("No mover (solo si no tiene movimientos)").tag(String?.none)
                        ForEach(model.reassignTargets(for: category), id: \.id) { entry in
                            Label(entry.label, systemImage: CarliIcon.symbol(entry.icon)).tag(Optional(entry.id))
                        }
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text("Si tiene movimientos o presupuestos, pasarán a la categoría que elijas.")
                }
                if let error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }
                Section {
                    Button("Eliminar \(category.name)", role: .destructive) { delete() }
                        .disabled(deleting)
                        .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Eliminar categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", role: .cancel) { dismiss() } }
            }
        }
        .presentationDetents([.medium])
    }

    private func delete() {
        deleting = true
        Task {
            do {
                try await model.delete(category, reassignTo: target)
                onDone("Categoría eliminada")
                dismiss()
            } catch {
                self.error = error.apiMessage(fallback: "Tiene movimientos: elige una categoría a la que moverlos.")
            }
            deleting = false
        }
    }
}
