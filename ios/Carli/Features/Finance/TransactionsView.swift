import SwiftUI

/// Finanzas › Movimientos: search, filter chips, period totals and the list by day.
/// Swipe left deletes with a few seconds to undo.
struct TransactionsView: View {
    @State var model: TransactionsModel
    @State private var deleted: FinanceTransaction?
    @State private var toast: String?

    var body: some View {
        List {
            Section {
                FilterChips(model: model)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            content
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .searchable(text: $model.filters.query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Buscar por comercio, concepto o nota")
        .refreshable { await model.reload() }
        .task(id: model.filters) {
            if model.state == .loading, model.periods.isEmpty {
                await model.load()
                return
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await model.reload()
        }
        .overlay(alignment: .bottom) { undoBar }
        .carliToast($toast)
        .animation(.smooth, value: deleted?.id)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            Section { ListSkeleton() }
                .listRowInsets(EdgeInsets())
                .listRowBackground(CarliColor.surface)
        case .failed(let message):
            Section {
                ContentUnavailableView {
                    Label("No se han podido cargar los movimientos", systemImage: "exclamationmark.circle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Reintentar") { Task { await model.reload() } }.buttonStyle(.glass)
                }
            }
            .listRowBackground(CarliColor.surface)
        case .loaded:
            if let totals = model.totals {
                Section { TotalsRow(totals: totals) }
                    .listRowBackground(CarliColor.surface)
            }
            let groups = model.groups
            if groups.isEmpty {
                Section { emptyState }
                    .listRowBackground(CarliColor.surface)
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.items) { transaction in
                            row(transaction)
                        }
                    } header: {
                        DayHeader(group: group)
                    }
                }
                if model.hasMore {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .onAppear { Task { await model.loadMore() } }
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
    }

    private func row(_ transaction: FinanceTransaction) -> some View {
        TransactionLine(transaction: transaction, accounts: model.accounts)
            .listRowInsets(EdgeInsets())
            .listRowBackground(CarliColor.surface)
            .alignmentGuide(.listRowSeparatorLeading) { _ in 68 }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    delete(transaction)
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            }
    }

    @ViewBuilder
    private var emptyState: some View {
        let filters = model.filters
        if filters.uncategorized, filters.activeCount == 1, filters.trimmedQuery.isEmpty {
            ContentUnavailableView {
                Label("Todo categorizado", systemImage: "checkmark.circle")
            } description: {
                Text("No quedan movimientos sin categoría en lo que estás viendo.")
            } actions: {
                Button("Ver todos los movimientos") { model.filters.uncategorized = false }.buttonStyle(.glass)
            }
        } else if filters.isFiltering {
            ContentUnavailableView {
                Label("Nada coincide con los filtros", systemImage: "magnifyingglass")
            } description: {
                Text("Prueba con otro periodo o quita algún filtro.")
            } actions: {
                Button("Quitar filtros") { model.filters = filters.cleared() }.buttonStyle(.glass)
            }
        } else {
            ContentUnavailableView("Aún no hay movimientos", systemImage: "tray",
                                   description: Text("Apunta tu primer gasto y empezarás a ver tu resumen."))
        }
    }

    @ViewBuilder
    private var undoBar: some View {
        if let deleted {
            HStack(spacing: CarliSpace.s16) {
                Text(deleted.isTransfer ? "Transferencia eliminada" : "Movimiento eliminado")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CarliColor.text)
                Button("Deshacer") { restore(deleted) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CarliColor.brandInk)
            }
            .padding(.horizontal, CarliSpace.s20)
            .padding(.vertical, CarliSpace.s12)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: deleted.id) {
                try? await Task.sleep(for: .seconds(5))
                if self.deleted?.id == deleted.id { self.deleted = nil }
            }
        }
    }

    private func delete(_ transaction: FinanceTransaction) {
        deleted = transaction
        Task {
            do {
                try await model.delete(transaction)
            } catch {
                if deleted?.id == transaction.id { deleted = nil }
                toast = error.apiMessage(fallback: "No se ha podido eliminar el movimiento.")
            }
        }
    }

    private func restore(_ transaction: FinanceTransaction) {
        deleted = nil
        Task {
            do {
                try await model.restore(transaction)
            } catch {
                toast = error.apiMessage(fallback: "No se ha podido recuperar el movimiento.")
            }
        }
    }
}

// MARK: Filters

/// Horizontal row of glass chips. Multi-choice menus stay open while ticking.
private struct FilterChips: View {
    @Bindable var model: TransactionsModel

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: CarliSpace.s8) {
                HStack(spacing: CarliSpace.s8) {
                    periodMenu
                    accountMenu
                    categoryMenu
                    kindMenu
                    Button {
                        model.filters.pendingOnly.toggle()
                    } label: {
                        Chip(symbol: "clock", text: "Pendientes\(model.pendingCount.map { " (\($0))" } ?? "")",
                             selected: model.filters.pendingOnly)
                    }
                    Button {
                        model.filters.uncategorized.toggle()
                    } label: {
                        Chip(symbol: "circle.dashed", text: "Sin categoría", selected: model.filters.uncategorized)
                    }
                    if model.filters.isFiltering {
                        Button {
                            model.filters = model.filters.cleared()
                        } label: {
                            Chip(symbol: "xmark", text: "Limpiar", selected: false)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, CarliSpace.s16)
                .padding(.vertical, CarliSpace.s4)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var periodMenu: some View {
        Menu {
            Picker("Periodo", selection: periodSelection) {
                ForEach(model.periods) { period in
                    Text(period.name).tag(period.id)
                }
                Text("Todos los periodos").tag("all")
            }
        } label: {
            Chip(symbol: "calendar", text: periodLabel, selected: true)
        }
    }

    private var periodSelection: Binding<String> {
        Binding {
            model.filters.allPeriods ? "all" : (model.filters.periodId ?? model.currentPeriod?.id ?? "")
        } set: { value in
            model.filters.allPeriods = value == "all"
            model.filters.periodId = value == "all" || value == model.currentPeriod?.id ? nil : value
        }
    }

    private var periodLabel: String {
        if model.filters.allPeriods { return "Todos los periodos" }
        if let id = model.filters.periodId, let period = model.periods.first(where: { $0.id == id }) { return period.name }
        return model.currentPeriod?.name ?? "Periodo actual"
    }

    private var accountMenu: some View {
        Menu {
            ForEach(model.accounts) { account in
                Toggle(account.name, isOn: member(account.id, of: \.accountIds))
            }
            if !model.filters.accountIds.isEmpty {
                Divider()
                Button("Todas las cuentas") { model.filters.accountIds = [] }
            }
        } label: {
            Chip(symbol: "wallet.bifold", text: accountLabel, selected: !model.filters.accountIds.isEmpty)
        }
        .menuActionDismissBehavior(.disabled)
    }

    private var accountLabel: String {
        let ids = model.filters.accountIds
        switch ids.count {
        case 0: return "Todas las cuentas"
        case 1: return model.accounts.first { $0.id == ids.first }?.name ?? "1 cuenta"
        default: return "\(ids.count) cuentas"
        }
    }

    private var categoryMenu: some View {
        Menu {
            Toggle("Sin categoría", systemImage: "circle.dashed",
                   isOn: member(TransactionFilters.noCategory, of: \.categoryIds))
            ForEach([("expense", "Gastos"), ("income", "Ingresos")], id: \.0) { kind, title in
                Section(title) {
                    ForEach(model.categories.filter { $0.kind == kind && $0.archived != true }) { parent in
                        let children = (parent.children ?? []).filter { $0.archived != true }
                        if children.isEmpty {
                            categoryToggle(parent)
                        } else {
                            Menu {
                                categoryToggle(parent, title: "Todo \(parent.name)")
                                ForEach(children) { categoryToggle($0) }
                            } label: {
                                Label(parent.name, systemImage: CarliIcon.symbol(parent.icon ?? "tag"))
                            }
                        }
                    }
                }
            }
            if !model.filters.categoryIds.isEmpty {
                Divider()
                Button("Quitar filtro") { model.filters.categoryIds = [] }
            }
        } label: {
            Chip(symbol: "tag", text: categoryLabel, selected: !model.filters.categoryIds.isEmpty)
        }
        .menuActionDismissBehavior(.disabled)
    }

    private func categoryToggle(_ category: FinanceCategory, title: String? = nil) -> some View {
        Toggle(title ?? category.name, systemImage: CarliIcon.symbol(category.icon ?? "tag"),
               isOn: member(category.id, of: \.categoryIds))
    }

    private var categoryLabel: String {
        let ids = model.filters.categoryIds
        switch ids.count {
        case 0: return "Categoría"
        case 1:
            if ids.first == TransactionFilters.noCategory { return "Sin categoría" }
            return model.categoryOptions.first { $0.category.id == ids.first }?.category.name ?? "1 categoría"
        default: return "\(ids.count) categorías"
        }
    }

    private var kindMenu: some View {
        Menu {
            ForEach(TransactionKind.allCases) { kind in
                Toggle(kind.plural, isOn: Binding {
                    model.filters.kinds.contains(kind)
                } set: { on in
                    if on { model.filters.kinds.insert(kind) } else { model.filters.kinds.remove(kind) }
                })
            }
        } label: {
            Chip(symbol: "arrow.up.arrow.down", text: kindLabel, selected: !model.filters.kinds.isEmpty)
        }
        .menuActionDismissBehavior(.disabled)
    }

    private var kindLabel: String {
        let kinds = TransactionKind.allCases.filter(model.filters.kinds.contains)
        return kinds.isEmpty ? "Tipo" : kinds.map(\.plural).joined(separator: " y ")
    }

    private func member(_ id: String, of keyPath: WritableKeyPath<TransactionFilters, Set<String>>) -> Binding<Bool> {
        Binding {
            model.filters[keyPath: keyPath].contains(id)
        } set: { on in
            if on { model.filters[keyPath: keyPath].insert(id) } else { model.filters[keyPath: keyPath].remove(id) }
        }
    }
}

private struct Chip: View {
    var symbol: String
    var text: String
    var selected: Bool

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(selected ? CarliColor.onPrimary : CarliColor.text)
            .padding(.horizontal, CarliSpace.s12)
            .padding(.vertical, CarliSpace.s8)
            .glassEffect(selected ? .regular.tint(CarliColor.primary).interactive() : .regular.interactive(), in: .capsule)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: Rows

private struct TotalsRow: View {
    var totals: TransactionTotals

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                count
                Spacer()
                sums
            }
            VStack(alignment: .leading, spacing: CarliSpace.s4) {
                count
                sums
            }
        }
        .font(.footnote)
    }

    private var count: some View {
        Text(Plural.movements(totals.count)).foregroundStyle(CarliColor.text2)
    }

    private var sums: some View {
        HStack(spacing: CarliSpace.s12) {
            sum("Ingresos", totals.incomeCents, CarliColor.positive)
            sum("Gastos", totals.expenseCents, CarliColor.text)
        }
    }

    private func sum(_ label: String, _ cents: Int, _ color: Color) -> some View {
        HStack(spacing: CarliSpace.s4) {
            Text(label).foregroundStyle(CarliColor.text2)
            Text(Money.format(cents, .signed))
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

private struct DayHeader: View {
    var group: DayGroup

    var body: some View {
        HStack {
            Text(CarliDate.dayTitle(group.date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CarliColor.text2)
            Spacer()
            Text(Money.format(group.totalCents, .signed))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(CarliColor.text3)
        }
        .textCase(nil)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct ListSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: CarliSpace.s12) {
                    Circle().fill(CarliColor.surface2).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: CarliSpace.s8) {
                        SkeletonBar(width: 150, height: 14)
                        SkeletonBar(width: 100, height: 12)
                    }
                    Spacer()
                    SkeletonBar(width: 70, height: 14)
                }
                .padding(.horizontal, CarliSpace.s16)
                .padding(.vertical, CarliSpace.s12)
            }
        }
    }
}
