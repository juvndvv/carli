import SwiftUI
import UIKit

/// "Más filtros": status, amount range and a date range that replaces the period.
struct MoreFiltersSheet: View {
    @Binding var filters: TransactionFilters

    @Environment(\.dismiss) private var dismiss
    @State private var status = 0
    @State private var minText = ""
    @State private var maxText = ""
    @State private var from: Date?
    @State private var to: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("Estado") {
                    Picker("Estado", selection: $status) {
                        Text("Todos").tag(0)
                        Text("Pendientes").tag(1)
                        Text("Confirmados").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                Section {
                    TextField("Importe mínimo", text: $minText).keyboardType(.decimalPad)
                    TextField("Importe máximo", text: $maxText).keyboardType(.decimalPad)
                } header: {
                    Text("Importe")
                } footer: {
                    Text("El importe se compara sin signo: sirve igual para gastos e ingresos.")
                }
                Section {
                    dateRow("Desde", $from)
                    dateRow("Hasta", $to)
                } header: {
                    Text("Fechas")
                } footer: {
                    Text("Un rango de fechas sustituye al periodo.")
                }
                Section {
                    Button("Limpiar", role: .destructive) {
                        status = 0
                        minText = ""
                        maxText = ""
                        from = nil
                        to = nil
                    }
                }
            }
            .navigationTitle("Más filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Aplicar", systemImage: "checkmark") { apply() } }
            }
            .onAppear(perform: read)
        }
        .presentationDetents([.large])
    }

    private func dateRow(_ title: String, _ value: Binding<Date?>) -> some View {
        HStack {
            if let date = value.wrappedValue {
                DatePicker(title, selection: Binding(get: { date }, set: { value.wrappedValue = $0 }), displayedComponents: .date)
                Button("Quitar \(title.lowercased())", systemImage: "xmark.circle.fill") { value.wrappedValue = nil }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(CarliColor.text3)
            } else {
                Text(title)
                Spacer()
                Button("Elegir") { value.wrappedValue = .now }
            }
        }
    }

    private func read() {
        status = filters.pendingOnly ? 1 : filters.clearedOnly ? 2 : 0
        minText = filters.minCents.map(Money.input) ?? ""
        maxText = filters.maxCents.map(Money.input) ?? ""
        from = filters.from.flatMap(CarliDate.day)
        to = filters.to.flatMap(CarliDate.day)
    }

    private func apply() {
        var next = filters
        next.pendingOnly = status == 1
        next.clearedOnly = status == 2
        next.minCents = Money.parse(minText)
        next.maxCents = Money.parse(maxText)
        next.from = from.map(CarliDate.isoDay)
        next.to = to.map(CarliDate.isoDay)
        if next.from != nil || next.to != nil { next.allPeriods = true }
        filters = next
        dismiss()
    }
}

/// "Editar en bloque": one change (category, account, tags or status) for every selected movement.
struct BulkEditSheet: View {
    var count: Int
    var categories: [FinanceCategory]
    var accounts: [AccountRef]
    var onApply: ([String: JSONValue]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var field = Field.category
    @State private var category: String?
    @State private var account: String?
    @State private var addTags = ""
    @State private var removeTags = ""
    @State private var cleared = true

    enum Field: String, CaseIterable {
        case category = "Categoría", account = "Cuenta", tags = "Etiquetas", status = "Estado"
    }

    static func parseTags(_ raw: String) -> [String] {
        raw.split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map { $0.replacing(/^#+/, with: "").lowercased() }
            .filter { !$0.isEmpty }
    }

    private var result: [String: JSONValue]? {
        switch field {
        case .category: return category.map { ["category_id": .string($0)] }
        case .account: return account.map { ["account_id": .string($0)] }
        case .tags:
            let add = Self.parseTags(addTags), remove = Self.parseTags(removeTags)
            if add.isEmpty && remove.isEmpty { return nil }
            var body: [String: JSONValue] = [:]
            if !add.isEmpty { body["add_tags"] = .array(add.map(JSONValue.string)) }
            if !remove.isEmpty { body["remove_tags"] = .array(remove.map(JSONValue.string)) }
            return body
        case .status: return ["status": .string(cleared ? "cleared" : "pending")]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Cambiar", selection: $field) {
                        ForEach(Field.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                } footer: {
                    Text(count == 1 ? "1 movimiento seleccionado" : "\(count) movimientos seleccionados")
                }
                switch field {
                case .category:
                    Section {
                        Picker("Nueva categoría", selection: $category) {
                            Text("Elige una categoría").tag(String?.none)
                            ForEach(options, id: \.id) { option in
                                Text(option.label).tag(Optional(option.id))
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } footer: {
                        Text("Las transferencias no cambian de categoría.")
                    }
                case .account:
                    Section {
                        Picker("Nueva cuenta", selection: $account) {
                            Text("Elige una cuenta").tag(String?.none)
                            ForEach(accounts) { Text($0.name).tag(Optional($0.id)) }
                        }
                        .pickerStyle(.navigationLink)
                    } footer: {
                        Text("Las transferencias no cambian de cuenta.")
                    }
                case .tags:
                    Section {
                        TextField("Añadir etiquetas", text: $addTags, prompt: Text("vacaciones, casa"))
                            .textInputAutocapitalization(.never)
                        TextField("Quitar etiquetas", text: $removeTags, prompt: Text("Opcional"))
                            .textInputAutocapitalization(.never)
                    } footer: {
                        Text("Separa varias con comas.")
                    }
                case .status:
                    Section {
                        Picker("Estado", selection: $cleared) {
                            Text("Confirmado").tag(true)
                            Text("Pendiente").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("Editar en bloque")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar", systemImage: "checkmark") {
                        if let result { onApply(result) }
                        dismiss()
                    }
                    .disabled(result == nil)
                }
            }
        }
    }

    private var options: [(id: String, label: String)] {
        categories.filter { $0.archived != true }.flatMap { parent in
            let suffix = parent.kind == "income" ? " · Ingreso" : ""
            return [(parent.id, parent.name + suffix)]
                + (parent.children ?? []).filter { $0.archived != true }.map { ($0.id, "\(parent.name) › \($0.name)\(suffix)") }
        }
    }
}

/// The system share sheet for a file (CSV export).
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SharedFile: Identifiable {
    let id = UUID()
    var url: URL
}
