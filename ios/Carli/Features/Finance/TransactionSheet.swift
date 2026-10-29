import SwiftUI

/// New or edit movement: big amount first, then who, what and where.
struct TransactionSheet: View {
    @State var model: TransactionFormModel
    var onSaved: (String) -> Void = { _ in }
    /// Called after an uncategorized import gets a category (transaction, category, category name).
    var onCategorized: ((String, String, String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                if !model.isEditing {
                    Section {
                        Picker("Tipo", selection: $model.kind) {
                            ForEach(TransactionFormModel.Kind.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section {
                    amountField
                } footer: {
                    notices
                }

                if model.isReadOnly {
                    readOnlyDetails
                } else if model.kind == .transfer {
                    transferFields
                } else {
                    movementFields
                    if model.splitting { splitFields }
                    if model.kind == .expense { shareFields }
                }

                if !model.isReadOnly {
                    Section {
                        DatePicker("Fecha", selection: $model.date, displayedComponents: .date)
                            .disabled(model.bankLocked)
                        Toggle("Pendiente", isOn: $model.pending)
                    } footer: {
                        Text("Los pendientes aún no han pasado por el banco y no cuentan en el saldo confirmado.")
                    }

                    Section {
                        TextField("Concepto", text: $model.descriptionText)
                        TextField("Notas", text: $model.notes, axis: .vertical)
                            .lineLimit(1...4)
                    }

                    tagFields
                }

                if let error = model.error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }

                if let editing = model.editing {
                    actions(editing)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                if !model.isReadOnly {
                    ToolbarItem(placement: .confirmationAction) {
                        if model.saving {
                            ProgressView()
                        } else {
                            Button("Guardar", role: .confirm) { save() }
                                .disabled(!model.canSave)
                        }
                    }
                }
            }
            .confirmationDialog(model.isTransferEdit ? "¿Eliminar esta transferencia?" : "¿Eliminar este movimiento?",
                                isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    Task {
                        if await model.delete() {
                            onSaved(model.isTransferEdit ? "Transferencia eliminada" : "Movimiento eliminado")
                            dismiss()
                        }
                    }
                }
            } message: {
                if model.fromBank { Text("No volverá en la siguiente sincronización.") }
            }
        }
        .task(id: ObjectIdentifier(model)) { await model.load() }
        .task(id: model.payee) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await model.suggest()
        }
        .onAppear { if !model.isEditing { amountFocused = true } }
    }

    private var title: String {
        if let editing = model.editing { return editing.isTransfer ? "Transferencia" : "Editar movimiento" }
        return "Nuevo movimiento"
    }

    private var amountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: CarliSpace.s4) {
            if model.kind != .transfer {
                Text(model.kind == .expense ? Money.minus : "+")
                    .foregroundStyle(CarliColor.text3)
            }
            TextField("0", text: $model.amountText)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .multilineTextAlignment(.center)
                .fixedSize()
                .disabled(model.isReadOnly || model.bankLocked)
            Text("€").foregroundStyle(CarliColor.text3)
        }
        .font(.system(size: 44, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(model.kind == .income ? CarliColor.positive : CarliColor.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, CarliSpace.s8)
        .contentShape(.rect)
        .onTapGesture { if !model.bankLocked { amountFocused = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Importe")
    }

    @ViewBuilder
    private var notices: some View {
        if let editing = model.editing {
            VStack(alignment: .leading, spacing: CarliSpace.s8) {
                if editing.fromBank {
                    Label {
                        Text("\(editing.bank?.aspspName.map { "Importado de \($0)" } ?? "Importado del banco"). Importe, fecha y cuenta vienen del banco. Si lo eliminas, no volverá en la siguiente sincronización.")
                    } icon: {
                        Image(systemName: "building.columns.fill")
                    }
                }
                if editing.transferUndoable == true, let source = editing.transferSource {
                    Label {
                        Text(Self.transferNotice(source))
                    } icon: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(CarliColor.text3)
        }
    }

    static func transferNotice(_ source: String) -> String {
        switch source {
        case "auto":
            "Detectada como transferencia entre tus cuentas (mismo importe y fecha, y la contraparte, el titular o el concepto apuntan a tu otra cuenta): no cuenta como gasto ni como ingreso."
        case "confirmed": "Confirmaste que es una transferencia entre tus cuentas."
        default: "Transferencia con una cuenta sin conexión al banco."
        }
    }

    @ViewBuilder
    private var movementFields: some View {
        Section {
            TextField(model.kind == .income ? "Pagador" : "Comercio", text: $model.payee)
                .textInputAutocapitalization(.words)
            ForEach(model.suggestions) { suggestion in
                Button {
                    model.apply(suggestion)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(CarliColor.text3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.payee).foregroundStyle(CarliColor.text)
                            if let category = suggestion.category {
                                Text(category.label).font(.caption).foregroundStyle(CarliColor.text2)
                            }
                        }
                        Spacer()
                        if let last = suggestion.lastAmountCents {
                            Text(Money.format(last, .signed))
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(CarliColor.text3)
                        }
                    }
                }
            }
            if !model.splitting {
                NavigationLink {
                    CategoryPickerView(categories: model.categories, kind: model.categoryKind, selection: $model.categoryId)
                } label: {
                    LabeledContent("Categoría") {
                        Text(model.categoryLabel ?? "Elegir")
                            .foregroundStyle(model.categoryId == nil ? CarliColor.text3 : CarliColor.text2)
                    }
                }
            }
            Toggle("Dividir en varias categorías", isOn: Binding(get: { model.splitEnabled }, set: { model.setSplitEnabled($0) }))
            accountPicker("Cuenta", selection: $model.accountId)
                .disabled(model.bankLocked)
        }
    }

    @ViewBuilder
    private var splitFields: some View {
        Section {
            ForEach($model.splits) { $split in
                HStack(spacing: CarliSpace.s12) {
                    NavigationLink {
                        CategoryPickerView(categories: model.categories, kind: model.categoryKind, selection: $split.categoryId)
                    } label: {
                        Text(model.label(for: split.categoryId) ?? "Categoría")
                            .foregroundStyle(split.categoryId == nil ? CarliColor.text3 : CarliColor.text)
                            .lineLimit(1)
                    }
                    TextField("0,00", text: $split.amountText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 90)
                        .onChange(of: split.amountText) { model.splitsDirty = true }
                }
                .swipeActions {
                    DeleteSwipeButton("Quitar") { model.removeSplit(split) }
                }
            }
            Button("Añadir parte", systemImage: "plus") {
                model.splits.append(.init())
                model.splitsDirty = true
            }
        } header: {
            Text("Reparto entre categorías")
        } footer: {
            let remaining = model.splitRemaining
            Text(remaining == 0 ? "Reparto completo"
                 : remaining > 0 ? "Quedan \(Money.format(remaining)) por asignar" : "Te pasas en \(Money.format(-remaining))")
                .foregroundStyle(remaining < 0 ? CarliColor.negative : CarliColor.text3)
        }
        .onChange(of: model.splits.map(\.categoryId)) { model.splitsDirty = true }
    }

    @ViewBuilder
    private var shareFields: some View {
        Section {
            Toggle("Gasto compartido", isOn: Binding(get: { model.shareEnabled }, set: {
                model.shareEnabled = $0
                model.sharesDirty = true
            }))
            .disabled(model.sharesLocked)
            if model.shareEnabled && !model.sharesLocked {
                if model.contacts.isEmpty {
                    Text("Añade contactos en Finanzas › Compartidos para repartir gastos.")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text3)
                } else {
                    Menu {
                        ForEach(model.contacts) { contact in
                            Button {
                                model.toggleShare(contact)
                            } label: {
                                if model.shares.contains(where: { $0.contactId == contact.id }) {
                                    Label(contact.name, systemImage: "checkmark")
                                } else {
                                    Text(contact.name)
                                }
                            }
                        }
                    } label: {
                        LabeledContent("Con") {
                            Text(model.shares.isEmpty ? "Elegir contactos" : model.shares.map(\.name).formatted(.list(type: .and)))
                                .foregroundStyle(model.shares.isEmpty ? CarliColor.text3 : CarliColor.text2)
                                .lineLimit(1)
                        }
                    }
                    if !model.shares.isEmpty {
                        Picker("Reparto", selection: Binding(get: { model.shareMode }, set: {
                            model.shareMode = $0
                            model.sharesDirty = true
                        })) {
                            ForEach(TransactionFormModel.ShareMode.allCases) { Text($0.label).tag($0) }
                        }
                        if model.shareMode == .equal {
                            Toggle("Incluirme en el reparto", isOn: Binding(get: { model.includeSelf }, set: {
                                model.includeSelf = $0
                                model.sharesDirty = true
                            }))
                        }
                        ForEach($model.shares) { $share in
                            shareRow($share)
                        }
                    }
                }
            }
        } footer: {
            if model.sharesLocked {
                Text("Este gasto ya tiene partes liquidadas y no se puede cambiar el reparto.")
            } else if model.shareEnabled, let summary = model.shareSummary {
                Text(summary)
            }
        }
    }

    private func shareRow(_ share: Binding<TransactionFormModel.ShareDraft>) -> some View {
        let preview = model.sharePreview.first { $0.name == share.wrappedValue.name }?.cents ?? 0
        return HStack {
            Text(share.wrappedValue.name)
            Spacer()
            switch model.shareMode {
            case .equal:
                Text(Money.format(preview)).monospacedDigit().foregroundStyle(CarliColor.text2)
            case .percentage:
                TextField("0", text: share.percentText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                    .onChange(of: share.wrappedValue.percentText) { model.sharesDirty = true }
                Text("%").foregroundStyle(CarliColor.text3)
            case .amount:
                TextField("0,00", text: share.amountText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                    .onChange(of: share.wrappedValue.amountText) { model.sharesDirty = true }
                Text("€").foregroundStyle(CarliColor.text3)
            }
        }
        .monospacedDigit()
    }

    @ViewBuilder
    private var tagFields: some View {
        Section {
            if !model.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CarliSpace.s8) {
                        ForEach(model.tags, id: \.self) { tag in
                            Button {
                                model.tags.removeAll { $0 == tag }
                            } label: {
                                Label("#\(tag)", systemImage: "xmark")
                                    .labelStyle(TrailingIconLabelStyle())
                                    .font(.subheadline)
                                    .padding(.horizontal, CarliSpace.s12)
                                    .padding(.vertical, 6)
                                    .background(CarliColor.surface2, in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Quitar etiqueta \(tag)")
                        }
                    }
                }
            }
            TextField("Añadir etiqueta", text: $model.tagDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { model.commitTagDraft() }
                .onChange(of: model.tagDraft) { _, value in
                    if value.hasSuffix(",") || value.hasSuffix(" ") { model.commitTagDraft() }
                }
            ForEach(tagSuggestions, id: \.self) { name in
                Button("#\(name)") {
                    model.tags.append(name)
                    model.tagDraft = ""
                }
            }
        } header: {
            Text("Etiquetas")
        }
    }

    private var tagSuggestions: [String] {
        let draft = model.tagDraft.trimmingCharacters(in: .whitespaces).replacing(/^#+/, with: "").lowercased()
        guard !draft.isEmpty else { return [] }
        return model.allTags.map(\.name)
            .filter { $0.lowercased().hasPrefix(draft) && !model.tags.contains($0) }
            .prefix(4)
            .map { $0 }
    }

    @ViewBuilder
    private var transferFields: some View {
        if model.isTransferEdit {
            Section {
                LabeledContent("Desde", value: accountName(model.accountId))
                LabeledContent("Hacia", value: accountName(model.toAccountId))
            } footer: {
                Text("Para cambiar las cuentas, elimina la transferencia y vuelve a crearla.")
            }
        } else {
            Section {
                accountPicker("Desde", selection: $model.accountId)
                accountPicker("Hacia", selection: $model.toAccountId)
            } footer: {
                if model.toAccountId != nil, model.toAccountId == model.accountId {
                    Text("Elige dos cuentas distintas.").foregroundStyle(CarliColor.negative)
                }
            }
        }
    }

    private func accountName(_ id: String?) -> String {
        model.accounts.first { $0.id == id }?.name ?? "—"
    }

    @ViewBuilder
    private var readOnlyDetails: some View {
        if let editing = model.editing {
            Section {
                LabeledContent("Movimiento", value: editing.title)
                LabeledContent("Detalle", value: editing.subtitle(accounts: model.accounts.map(\.ref)))
                LabeledContent("Fecha", value: CarliDate.day(editing.date).map(CarliDate.long) ?? editing.date)
                if let notes = editing.notes, !notes.isEmpty { LabeledContent("Notas", value: notes) }
            } footer: {
                Text("Los ajustes de saldo no se editan; puedes eliminarlo.")
            }
        }
    }

    @ViewBuilder
    private func actions(_ editing: FinanceTransaction) -> some View {
        Section {
            if editing.transferUndoable == true {
                Button("Deshacer transferencia", systemImage: "arrow.uturn.backward") {
                    Task {
                        if let message = await model.undoTransfer() {
                            onSaved(message)
                            dismiss()
                        }
                    }
                }
                .disabled(model.working)
            } else if editing.canBecomeTransfer && !model.manualAccounts.isEmpty {
                Menu {
                    ForEach(model.manualAccounts) { account in
                        Button(account.name, systemImage: account.symbol) {
                            Task {
                                if let message = await model.convertToTransfer(account) {
                                    onSaved(message)
                                    dismiss()
                                }
                            }
                        }
                    }
                } label: {
                    Label(editing.amountCents < 0 ? "Es una transferencia a…" : "Es una transferencia desde…",
                          systemImage: "arrow.left.arrow.right")
                }
                .disabled(model.working)
            }
            if !model.isReadOnly {
                Button("Duplicar", systemImage: "doc.on.doc") {
                    model = TransactionFormModel(api: model.api, duplicating: editing)
                }
            }
            Button(model.isTransferEdit ? "Eliminar transferencia" : "Eliminar movimiento", systemImage: "trash", role: .destructive) {
                confirmingDelete = true
            }
        }
    }

    private func accountPicker(_ title: String, selection: Binding<String?>) -> some View {
        Picker(title, selection: selection) {
            if selection.wrappedValue == nil { Text("Elegir").tag(String?.none) }
            ForEach(model.activeAccounts) { account in
                Label(account.name, systemImage: account.symbol).tag(Optional(account.id))
            }
        }
    }

    private func save() {
        Task {
            let categorized = model.categorizedImport
            if await model.save() {
                if let categorized { onCategorized?(categorized.transactionId, categorized.categoryId, categorized.name) }
                onSaved(model.isEditing ? "Movimiento guardado" : model.kind == .transfer ? "Transferencia creada" : "Movimiento añadido")
                dismiss()
            }
        }
    }
}

/// Text first, icon after (tag chips with a trailing ✕).
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

/// Searchable list of categories of one kind: parents with their children indented.
struct CategoryPickerView: View {
    var categories: [FinanceCategory]
    var kind: String
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        List {
            ForEach(filtered, id: \.category.id) { entry in
                Button {
                    selection = entry.category.id
                    dismiss()
                } label: {
                    HStack(spacing: CarliSpace.s12) {
                        Image(systemName: CarliIcon.symbol(entry.category.icon ?? entry.parentIcon ?? "tag"))
                            .font(.system(size: 15))
                            .foregroundStyle(CarliColor.text)
                            .frame(width: 30, height: 30)
                            .background(CarliColor.surface2, in: .circle)
                        Text(entry.category.name)
                            .font(.body.weight(entry.isChild ? .regular : .medium))
                            .foregroundStyle(CarliColor.text)
                        Spacer()
                        if selection == entry.category.id {
                            Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(CarliColor.brandInk)
                        }
                    }
                    .padding(.leading, entry.isChild ? CarliSpace.s24 : 0)
                }
            }
        }
        .overlay {
            if categories.isEmpty { ProgressView() }
            else if filtered.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar categoría")
        .navigationTitle("Categoría")
        .navigationBarTitleDisplayMode(.inline)
    }

    private struct Entry {
        var category: FinanceCategory
        var isChild: Bool
        var parentIcon: String?
    }

    private var filtered: [Entry] {
        let all = categories.filter { $0.kind == kind && $0.archived != true }.flatMap { parent in
            [Entry(category: parent, isChild: false, parentIcon: nil)]
                + (parent.children ?? []).filter { $0.archived != true }.map { Entry(category: $0, isChild: true, parentIcon: parent.icon) }
        }
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return all }
        return all.filter { $0.category.name.localizedStandardContains(term) }
    }
}
