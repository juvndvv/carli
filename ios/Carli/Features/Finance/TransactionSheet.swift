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
                }

                if model.isReadOnly {
                    readOnlyDetails
                } else if model.kind == .transfer {
                    transferFields
                } else {
                    movementFields
                }

                if !model.isReadOnly {
                    Section {
                        DatePicker("Fecha", selection: $model.date, displayedComponents: .date)
                        Toggle("Pendiente", isOn: $model.pending)
                    } footer: {
                        Text("Los pendientes aún no han pasado por el banco y no cuentan en el saldo confirmado.")
                    }

                    Section {
                        TextField("Concepto", text: $model.descriptionText)
                        TextField("Notas", text: $model.notes, axis: .vertical)
                            .lineLimit(1...4)
                    }
                }

                if let error = model.error {
                    Section { Text(error).foregroundStyle(CarliColor.negative) }
                }

                if model.isEditing {
                    Section {
                        Button("Eliminar movimiento", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
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
            .confirmationDialog("¿Eliminar este movimiento?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    Task {
                        if await model.delete() {
                            onSaved(model.editing?.isTransfer == true ? "Transferencia eliminada" : "Movimiento eliminado")
                            dismiss()
                        }
                    }
                }
            }
        }
        .task { await model.load() }
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
                .disabled(model.isReadOnly)
            Text("€").foregroundStyle(CarliColor.text3)
        }
        .font(.system(size: 44, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(model.kind == .income ? CarliColor.positive : CarliColor.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, CarliSpace.s8)
        .contentShape(.rect)
        .onTapGesture { amountFocused = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Importe")
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
            if model.isSplit {
                LabeledContent("Categoría", value: "\(model.editing?.splits?.count ?? 0) categorías")
            } else {
                NavigationLink {
                    CategoryPickerView(categories: model.categories, kind: model.categoryKind, selection: $model.categoryId)
                } label: {
                    LabeledContent("Categoría") {
                        Text(model.categoryLabel ?? "Elegir")
                            .foregroundStyle(model.categoryId == nil ? CarliColor.text3 : CarliColor.text2)
                    }
                }
            }
            accountPicker("Cuenta", selection: $model.accountId)
        }
    }

    @ViewBuilder
    private var transferFields: some View {
        Section {
            accountPicker("Desde", selection: $model.accountId)
            accountPicker("Hacia", selection: $model.toAccountId)
        } footer: {
            if model.toAccountId != nil, model.toAccountId == model.accountId {
                Text("Elige dos cuentas distintas.").foregroundStyle(CarliColor.negative)
            }
        }
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
                Text(editing.isTransfer
                     ? "Las transferencias se editan desde la app web por ahora. Puedes eliminarla y volver a crearla."
                     : "Los ajustes de saldo no se editan; puedes eliminarlo.")
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
