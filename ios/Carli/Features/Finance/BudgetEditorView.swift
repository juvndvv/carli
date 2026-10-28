import SwiftUI

/// Sheet to set every expense category's limit for the period at once.
struct BudgetEditorView: View {
    var model: BudgetsModel
    var overview: BudgetOverview
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var lines: [BudgetEditorLine] = []
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($lines) { $line in
                        EditorRow(line: $line)
                    }
                } header: {
                    HStack {
                        Text("Categoría")
                        Spacer()
                        Text("Límite")
                            .frame(width: 110, alignment: .trailing)
                        Text("Arrastrar")
                            .frame(width: 64, alignment: .trailing)
                    }
                } footer: {
                    Text("Deja el importe vacío para quitar el presupuesto. Un presupuesto de categoría principal incluye sus subcategorías. Activa \"Arrastrar\" para pasar el sobrante o el exceso al siguiente periodo.")
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(CarliColor.negative)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Editar presupuestos")
            .navigationSubtitle(overview.meta.period.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if saving {
                        ProgressView()
                    } else {
                        Button("Guardar", role: .confirm) { save() }
                            .disabled(lines.isEmpty || lines.contains { !$0.isValid })
                    }
                }
            }
            .overlay {
                if lines.isEmpty, model.categories.isEmpty { ProgressView() }
            }
        }
        .onAppear {
            if lines.isEmpty { lines = BudgetEditorLine.build(categories: model.categories, rows: overview.data) }
        }
        .onChange(of: model.categories) {
            if lines.isEmpty { lines = BudgetEditorLine.build(categories: model.categories, rows: overview.data) }
        }
        .interactiveDismissDisabled(!BudgetEditorLine.changes(lines).isEmpty)
    }

    private func save() {
        let changes = BudgetEditorLine.changes(lines)
        guard !changes.isEmpty else { dismiss(); return }
        saving = true
        error = nil
        Task {
            do {
                try await model.save(changes)
                onSaved()
                dismiss()
            } catch {
                self.error = error.apiMessage(fallback: "No se han podido guardar los presupuestos.")
            }
            saving = false
        }
    }
}

private struct EditorRow: View {
    @Binding var line: BudgetEditorLine

    var body: some View {
        HStack(spacing: CarliSpace.s8) {
            Image(systemName: CarliIcon.symbol(line.icon))
                .font(.system(size: 14))
                .foregroundStyle(CarliColor.text)
                .frame(width: 30, height: 30)
                .background(CarliColor.surface2, in: .circle)
            Text(line.name)
                .font(.body.weight(line.isChild ? .regular : .medium))
                .lineLimit(1)
            Spacer(minLength: CarliSpace.s4)
            TextField("Sin límite", text: $line.amountText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .foregroundStyle(line.isValid ? CarliColor.text : CarliColor.negative)
                .frame(width: 110)
                .accessibilityLabel("Límite de \(line.name)")
            Toggle("Arrastrar sobrante o exceso de \(line.name)", isOn: $line.rollover)
                .labelsHidden()
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.leading, line.isChild ? CarliSpace.s24 : 0)
    }
}
