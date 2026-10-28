import SwiftUI

/// Finanzas › Presupuestos: totals for the period, projection, and a line per budgeted category.
struct BudgetsView: View {
    @State var model: BudgetsModel
    var go: (FinanceRoute) -> Void
    @State private var editing = false
    @State private var toast: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                PeriodBar(periods: model.periods, selected: model.selectedPeriod) { period in
                    Task { await model.select(period) }
                }
                switch model.state {
                case .loading:
                    BudgetsSkeleton()
                case .failed(let message):
                    CarliCard {
                        ContentUnavailableView {
                            Label("No se han podido cargar los presupuestos", systemImage: "exclamationmark.circle")
                        } description: {
                            Text(message)
                        } actions: {
                            Button("Reintentar") { Task { await model.loadOverview() } }.buttonStyle(.glass)
                        }
                    }
                case .loaded(let overview):
                    content(overview)
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .refreshable { await model.loadOverview() }
        .onReceive(NotificationCenter.default.publisher(for: .financeChanged)) { _ in
            Task { await model.loadOverview() }
        }
        .task { if model.overview == nil { await model.load() } }
        .sheet(isPresented: $editing) {
            if let overview = model.overview {
                BudgetEditorView(model: model, overview: overview) { toast = "Presupuestos guardados" }
            }
        }
        .carliToast($toast)
    }

    @ViewBuilder
    private func content(_ overview: BudgetOverview) -> some View {
        let rows = overview.data.sorted { ($0.category.sortKey ?? 0) < ($1.category.sortKey ?? 0) }
        let budgeted = rows.reduce(0) { $0 + $1.limitCents }
        let totals = overview.meta.totals
        let period = overview.meta.period
        let isCurrent = period.isCurrent == true

        Grid(horizontalSpacing: CarliSpace.s12, verticalSpacing: CarliSpace.s12) {
            GridRow {
                StatCard(label: "Presupuestado", value: Money.format(budgeted),
                         note: rows.count == 1 ? "1 categoría" : "\(rows.count) categorías")
                StatCard(label: "Gastado", value: Money.format(totals.spentCents),
                         note: spentNote(totals: totals, budgeted: budgeted, period: period))
            }
        }

        if isCurrent {
            let projected = totals.projectedCents ?? totals.spentCents
            let gap = projected - budgeted
            let over = budgeted > 0 && gap > 0
            StatCard(label: "Proyección fin de periodo", value: Money.format(projected),
                     valueColor: over ? CarliColor.warning : CarliColor.text,
                     note: budgeted == 0 ? "Según tu ritmo de gasto"
                         : gap > 0 ? "Superarías el total en \(Money.format(gap))" : "Te sobrarían \(Money.format(-gap))",
                     noteSymbol: over ? "exclamationmark.triangle.fill" : "checkmark.circle",
                     noteColor: over ? CarliColor.warning : CarliColor.text2)
        } else {
            StatCard(label: "Resultado", value: Money.format(totals.remainingCents),
                     valueColor: totals.remainingCents < 0 ? CarliColor.negative : CarliColor.positive,
                     note: totals.remainingCents < 0 ? "Te pasaste del total" : "Te sobró del total")
        }

        if let summary = overview.meta.uncategorized, summary.expenseCents != 0 {
            UncategorizedNotice(summary: summary) {
                go(.transactions(TransactionFilters(periodId: period.id, uncategorized: true)))
            }
        }

        CarliCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: CarliSpace.s8) {
                    Text("Por categoría")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(CarliColor.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    if let previous = overview.meta.previousPeriod, !rows.isEmpty {
                        Button("Copiar de \(previous.shortName ?? previous.name)", systemImage: "doc.on.doc") {
                            copy(previous)
                        }
                        .labelStyle(.iconOnly)
                        .disabled(model.copying)
                    }
                    if !rows.isEmpty {
                        Button("Editar", systemImage: "pencil") { editing = true }
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .padding(.horizontal, CarliSpace.s16)
                .padding(.top, CarliSpace.s16)
                .padding(.bottom, CarliSpace.s8)

                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("Aún no hay presupuestos en este periodo", systemImage: "gauge.with.dots.needle.50percent")
                    } description: {
                        Text("Pon un límite a cada categoría y te avisaremos al llegar al \(model.warningThreshold) % y al superarlo.")
                    } actions: {
                        Button("Crear presupuestos") { editing = true }.buttonStyle(.glassProminent)
                        if let previous = overview.meta.previousPeriod {
                            Button("Copiar de \(previous.shortName ?? previous.name)", systemImage: "doc.on.doc") {
                                copy(previous)
                            }
                            .buttonStyle(.glass)
                            .disabled(model.copying)
                        }
                    }
                } else {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider().padding(.leading, 68) }
                        Button {
                            go(.transactions(TransactionFilters(periodId: period.id,
                                                                categoryIds: row.categoryId.map { [$0] } ?? [],
                                                                kinds: [.expense])))
                        } label: {
                            BudgetRowTile(row: row, showProjection: isCurrent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Ver movimientos")
                    }
                    .padding(.bottom, CarliSpace.s8)
                }
            }
        }
    }

    private func spentNote(totals: BudgetTotals, budgeted: Int, period: FinancePeriod) -> String? {
        var parts: [String] = []
        if budgeted > 0 {
            parts.append("\(Plural.percent(basisPoints: Int((Double(totals.spentCents) * 10000 / Double(budgeted)).rounded()))) del total")
        }
        if period.isCurrent == true, let end = period.expectedEndDate.flatMap(CarliDate.day) {
            if model.settings?.periodMode == "calendar" {
                parts.append("termina el \(CarliDate.short(end))")
            } else if let payday = CarliDate.calendar.date(byAdding: .day, value: 1, to: end) {
                parts.append("nómina prevista el \(CarliDate.short(payday))")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func copy(_ previous: FinancePeriod) {
        Task { toast = await model.copy(from: previous) }
    }
}

private struct BudgetRowTile: View {
    var row: BudgetRow
    var showProjection: Bool

    var body: some View {
        HStack(alignment: .top, spacing: CarliSpace.s12) {
            Image(systemName: CarliIcon.symbol(row.category.icon ?? "tag"))
                .font(.system(size: 17))
                .foregroundStyle(CarliColor.text)
                .frame(width: 40, height: 40)
                .background(CarliColor.surface2, in: .circle)
            BudgetLine(row: row, showProjection: showProjection,
                       badge: CarliBadge(label: row.usageLabel, symbol: symbol))
        }
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, CarliSpace.s12)
        .contentShape(.rect)
    }

    private var symbol: String {
        switch row.state {
        case .ok: "checkmark"
        case .warning: "exclamationmark.triangle"
        case .exceeded: "xmark.circle"
        }
    }
}

/// Label, big figure and a note: the stat tile used across Finanzas.
struct StatCard: View {
    var label: String
    var value: String
    var valueColor: Color = CarliColor.text
    var note: String?
    var noteSymbol: String?
    var noteColor: Color = CarliColor.text2

    var body: some View {
        CarliCard {
            VStack(alignment: .leading, spacing: CarliSpace.s4) {
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(CarliColor.text2)
                Text(value)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let note {
                    Label {
                        Text(note)
                    } icon: {
                        if let noteSymbol { Image(systemName: noteSymbol) }
                    }
                    .labelStyle(.titleAndIcon)
                    .font(.caption)
                    .foregroundStyle(noteColor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BudgetsSkeleton: View {
    var body: some View {
        VStack(spacing: CarliSpace.s12) {
            HStack(spacing: CarliSpace.s12) {
                ForEach(0..<2, id: \.self) { _ in
                    CarliCard {
                        SkeletonBar(width: 90, height: 13)
                        SkeletonBar(width: 120, height: 26).padding(.top, CarliSpace.s8)
                    }
                }
            }
            CarliCard { SkeletonBar(width: 300, height: 60) }
            CarliCard { SkeletonBar(width: 300, height: 240) }
        }
    }
}
