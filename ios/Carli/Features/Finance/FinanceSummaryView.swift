import Charts
import SwiftUI

/// Finanzas › Resumen: period picker, the three rings, key figures and the period's detail.
struct FinanceSummaryView: View {
    @State var model: FinanceSummaryModel
    /// Switches the module header to another section, carrying the filters the link implies.
    var go: (FinanceRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                PeriodBar(periods: model.periods, selected: model.selectedPeriod) { period in
                    Task { await model.select(period) }
                }
                switch model.state {
                case .loading:
                    SummarySkeleton()
                case .failed(let message):
                    ContentUnavailableView {
                        Label("No se ha podido cargar el resumen", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Reintentar") { Task { await model.loadDashboard() } }
                            .buttonStyle(.glass)
                    }
                case .loaded(let data):
                    if model.accounts?.isEmpty == true {
                        CarliCard {
                            ContentUnavailableView("Empieza por tus cuentas", systemImage: "wallet.bifold",
                                                   description: Text("Añade tu cuenta corriente, tus tarjetas o el efectivo y apunta tu primer movimiento para ver aquí tu resumen."))
                        }
                    } else {
                        SummaryBody(data: data, model: model, go: go)
                    }
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
        .background(CarliColor.bg)
        .refreshable { await model.load() }
        .task { if model.state.dashboard == nil { await model.load() } }
    }
}

// MARK: Period

// MARK: Body

private struct SummaryBody: View {
    var data: Dashboard
    var model: FinanceSummaryModel
    var go: (FinanceRoute) -> Void

    var body: some View {
        let period = data.period
        Text((period.isCurrent == true
              ? "\(period.name) · \(Plural.daysLeft(period.daysRemaining ?? 0))"
              : "\(period.name) · \(period.rangeLabel ?? "")").uppercased())
            .font(.footnote.weight(.semibold))
            .tracking(0.3)
            .foregroundStyle(CarliColor.text2)
            .padding(.top, CarliSpace.s4)

        MetricsGrid(data: data, go: go)

        SummarySection(title: "Próximos cargos", padded: data.upcoming.isEmpty) {
            if data.upcoming.isEmpty {
                Muted("No hay cargos recurrentes en los próximos 7 días.")
            } else {
                ForEach(Array(data.upcoming.enumerated()), id: \.element.id) { index, charge in
                    if index > 0 { Divider().padding(.leading, 68) }
                    RowLayout(symbol: CarliIcon.symbol(charge.category?.icon ?? "repeat"), soft: false,
                              title: charge.name, subtitle: charge.subtitle) {
                        Text(Money.format(charge.amountCents, .signed))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(charge.amountCents > 0 ? CarliColor.positive : CarliColor.text)
                    }
                }
            }
        }

        SummarySection(title: "Últimos movimientos", action: ("Ver todos", { go(.transactions(TransactionFilters(periodId: data.period.id))) }),
                       padded: data.recentTransactions.isEmpty) {
            if data.recentTransactions.isEmpty {
                ContentUnavailableView("Aún no hay movimientos", systemImage: "tray",
                                       description: Text("Apunta tu primer gasto y empezarás a ver tu resumen."))
            } else {
                ForEach(Array(data.recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                    if index > 0 { Divider().padding(.leading, 68) }
                    TransactionLine(transaction: transaction, accounts: model.accounts ?? [])
                }
            }
        }

        RingsCard(rings: RingFigures(data, savingsTargetPercent: model.savingsTargetPercent)) { go(.budgets) }

        if let summary = data.uncategorized, summary.expenseCents != 0 {
            UncategorizedNotice(summary: summary) {
                go(.transactions(TransactionFilters(periodId: data.period.id, uncategorized: true)))
            }
        }

        SummarySection(title: "Ingresos y gastos") {
            if data.history.isEmpty {
                Muted("Aún no hay periodos anteriores con los que comparar.")
            } else {
                IncomeExpenseChart(history: data.history)
            }
        }

        SummarySection(title: "Gasto por categoría") {
            let slices = DonutSlice.build(data.byCategory)
            if slices.isEmpty {
                ContentUnavailableView("Sin gastos en este periodo", systemImage: "chart.pie",
                                       description: Text("Cuando apuntes gastos verás aquí en qué se va el dinero."))
            } else {
                CategoryDonut(slices: slices)
            }
        }

        SummarySection(title: "Presupuestos", action: ("Ver todos", { go(.budgets) })) {
            let rows = data.budgets?.top ?? []
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("Sin presupuestos", systemImage: "gauge.with.dots.needle.50percent")
                } description: {
                    Text("Pon un límite a las categorías en las que más gastas.")
                } actions: {
                    Button("Crear presupuestos") { go(.budgets) }.buttonStyle(.glass)
                }
            } else {
                VStack(spacing: CarliSpace.s16) {
                    ForEach(rows) { BudgetLine(row: $0) }
                }
            }
        }

        SummarySection(title: "Patrimonio") {
            if data.history.count > 1 {
                NetWorthChart(history: data.history)
            } else {
                Muted("La evolución aparecerá cuando tengas más de un periodo.")
            }
        }
    }
}

// MARK: Rings

private struct RingsCard: View {
    var rings: RingFigures
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            CarliCard {
                HStack(spacing: CarliSpace.s16) {
                    RingStack(values: [(rings.available, CarliColor.rings[0]),
                                       (rings.savings, CarliColor.rings[1]),
                                       (rings.pace, CarliColor.rings[2])])
                    VStack(alignment: .leading, spacing: CarliSpace.s8) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(entry.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CarliColor.ringInk[index])
                                Text(entry.value)
                                    .font(.title3.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(CarliColor.text)
                                    .minimumScaleFactor(0.6)
                                    .lineLimit(1)
                                Label {
                                    Text(entry.note).lineLimit(1)
                                } icon: {
                                    if entry.warning { Image(systemName: "arrow.up.right") }
                                }
                                .labelStyle(.titleAndIcon)
                                .font(.caption.weight(entry.warning ? .semibold : .medium))
                                .foregroundStyle(entry.warning ? CarliColor.negative : CarliColor.text2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entries.map { "\($0.label): \($0.value), \($0.note)" }.joined(separator: ". "))
        .accessibilityHint("Abrir presupuestos")
    }

    private var entries: [(label: String, value: String, note: String, warning: Bool)] {
        let pace = rings.pace
        return [
            ("Disponible", rings.hasBudget ? Money.format(rings.remainingCents) : "—",
             rings.hasBudget ? "de \(Money.format(rings.budgetedCents))" : "Sin presupuestos", false),
            ("Ahorro", rings.hasSavingsTarget ? Money.format(rings.savingsCents) : "—",
             rings.hasSavingsTarget ? "objetivo \(Money.format(rings.savingsTargetCents))" : "Sin ingresos en este periodo", false),
            ("Ritmo", pace.map { Plural.percent(basisPoints: Int(($0 * 10_000).rounded())) } ?? "—",
             pace == nil ? "Sin presupuestos" : rings.aheadOfPlan ? "Por encima de lo previsto" : "Dentro de lo previsto",
             rings.aheadOfPlan),
        ]
    }
}

// MARK: Metrics

private struct MetricsGrid: View {
    var data: Dashboard
    var go: (FinanceRoute) -> Void

    var body: some View {
        let previous = data.previousPeriod?.shortName
        let history = data.history
        Grid(horizontalSpacing: CarliSpace.s12, verticalSpacing: CarliSpace.s12) {
            GridRow {
                MetricCard(label: "Patrimonio", value: Money.format(data.netWorthCents),
                           note: data.netWorthDeltaCents.map { "\(Money.format($0, .signed))\(previous.map { " vs \($0)" } ?? "")" },
                           trend: Trend(data.netWorthDeltaCents.map { $0 >= 0 ? 1 : -1 }),
                           series: history.map(\.netWorthCents))
                MetricCard(label: "Ingresos", value: Money.format(data.incomeCents), valueColor: CarliColor.positive,
                           note: delta(data.deltasBp?.income, previous),
                           trend: Trend(bp: data.deltasBp?.income, higherIsBetter: true),
                           series: history.map(\.incomeCents))
            }
            GridRow {
                MetricCard(label: "Gastos", value: Money.format(data.expenseCents),
                           note: delta(data.deltasBp?.expense, previous),
                           trend: Trend(bp: data.deltasBp?.expense, higherIsBetter: false),
                           series: history.map(\.expenseCents)) {
                    go(.transactions(TransactionFilters(periodId: data.period.id, kinds: [.expense])))
                }
                MetricCard(label: "Ahorro", value: Money.format(data.savingsCents),
                           valueColor: data.savingsCents < 0 ? CarliColor.negative : CarliColor.text,
                           note: data.savingsRateBp.map { "Tasa \(Percent.format($0))" } ?? "Sin ingresos este periodo",
                           trend: .flat,
                           series: history.map { $0.incomeCents - $0.expenseCents })
            }
        }
    }

    private func delta(_ bp: Int?, _ previous: String?) -> String? {
        guard let bp, let previous else { return nil }
        return "\(Percent.format(bp, signed: true)) vs \(previous)"
    }
}

/// Direction of a metric's change and whether that direction is good news.
private struct Trend: Equatable {
    var symbol: String
    var color: Color

    static let flat = Trend(symbol: "", color: CarliColor.text2)

    init(symbol: String, color: Color) {
        self.symbol = symbol
        self.color = color
    }

    /// From a signed change where up is good.
    init(_ sign: Int?) {
        guard let sign else { self = .flat; return }
        self = Trend(symbol: sign >= 0 ? "arrow.up.right" : "arrow.down.right",
                     color: sign >= 0 ? CarliColor.positive : CarliColor.negative)
    }

    /// From a change in basis points; under 0,5 % counts as flat.
    init(bp: Int?, higherIsBetter: Bool) {
        guard let bp else { self = .flat; return }
        guard abs(bp) >= 50 else { self = Trend(symbol: "minus", color: CarliColor.text2); return }
        self = Trend(symbol: bp > 0 ? "arrow.up.right" : "arrow.down.right",
                     color: (bp > 0) == higherIsBetter ? CarliColor.positive : CarliColor.negative)
    }
}

private struct MetricCard: View {
    var label: String
    var value: String
    var valueColor: Color = CarliColor.text
    var note: String?
    var trend: Trend
    var series: [Int]
    var action: (() -> Void)?

    var body: some View {
        let card = CarliCard(padding: CarliSpace.s12) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(CarliColor.text2)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let note {
                Label {
                    Text(note).lineLimit(2)
                } icon: {
                    if !trend.symbol.isEmpty { Image(systemName: trend.symbol) }
                }
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.medium))
                .foregroundStyle(trend.color)
                .padding(.top, 2)
            }
            Spacer(minLength: CarliSpace.s8)
            if series.count > 1 {
                Sparkline(values: series)
                    .frame(height: 28)
            }
        }
        .frame(maxHeight: .infinity)

        if let action {
            Button(action: action) { card }.buttonStyle(.plain)
        } else {
            card
        }
    }
}

private struct Sparkline: View {
    var values: [Int]

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { index, value in
            LineMark(x: .value("Periodo", index), y: .value("Importe", value))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .foregroundStyle(CarliColor.text3)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityHidden(true)
    }
}

// MARK: Charts

private struct IncomeExpenseChart: View {
    var history: [HistoryPoint]

    var body: some View {
        Chart {
            ForEach(history) { point in
                BarMark(x: .value("Periodo", point.label), y: .value("Importe", Double(point.incomeCents) / 100))
                    .foregroundStyle(by: .value("Serie", "Ingresos"))
                    .position(by: .value("Serie", "Ingresos"))
                    .cornerRadius(4)
                BarMark(x: .value("Periodo", point.label), y: .value("Importe", Double(point.expenseCents) / 100))
                    .foregroundStyle(by: .value("Serie", "Gastos"))
                    .position(by: .value("Serie", "Gastos"))
                    .cornerRadius(4)
            }
        }
        .chartForegroundStyleScale(["Ingresos": CarliColor.chartIncome, "Gastos": CarliColor.chartAccent])
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(CarliColor.border)
                AxisValueLabel {
                    if let euros = value.as(Double.self) { Text(compact(euros)) }
                }
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 200)
        .accessibilityLabel("Ingresos y gastos de los últimos periodos")
    }
}

private struct CategoryDonut: View {
    var slices: [DonutSlice]

    var body: some View {
        let total = slices.reduce(0) { $0 + $1.amountCents }
        VStack(spacing: CarliSpace.s12) {
            Chart(slices) { slice in
                SectorMark(angle: .value("Gasto", slice.amountCents), innerRadius: .ratio(0.64), angularInset: 1.5)
                    .foregroundStyle(by: .value("Categoría", slice.id))
                    .cornerRadius(4)
            }
            .chartForegroundStyleScale(domain: slices.map(\.id), range: slices.map(color))
            .chartLegend(.hidden)
            .chartBackground { _ in
                VStack(spacing: 0) {
                    Text("Gastado")
                        .font(.caption)
                        .foregroundStyle(CarliColor.text2)
                    Text(Money.format(total))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(CarliColor.text)
                }
            }
            .frame(height: 180)
            .accessibilityLabel("Gasto por categoría")

            ForEach(slices) { slice in
                HStack(spacing: CarliSpace.s8) {
                    Circle().fill(color(slice)).frame(width: 10, height: 10)
                    Text(slice.label)
                        .font(.subheadline)
                        .foregroundStyle(CarliColor.text)
                    Spacer()
                    Text(Money.format(slice.amountCents))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(CarliColor.text2)
                }
            }
        }
    }

    private func color(_ slice: DonutSlice) -> Color {
        slice.slot.map { CarliColor.chart[$0 - 1] } ?? CarliColor.chartRest
    }
}

private struct NetWorthChart: View {
    var history: [HistoryPoint]

    var body: some View {
        Chart(history) { point in
            AreaMark(x: .value("Periodo", point.label), y: .value("Patrimonio", Double(point.netWorthCents) / 100))
                .interpolationMethod(.monotone)
                .foregroundStyle(LinearGradient(colors: [CarliColor.chartAccent.opacity(0.25), CarliColor.chartAccent.opacity(0)],
                                                startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Periodo", point.label), y: .value("Patrimonio", Double(point.netWorthCents) / 100))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .foregroundStyle(CarliColor.chartAccent)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(CarliColor.border)
                AxisValueLabel {
                    if let euros = value.as(Double.self) { Text(compact(euros)) }
                }
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Evolución del patrimonio")
    }
}

/// Axis labels: "850 €", "1,2 k€".
private func compact(_ euros: Double) -> String {
    let sign = euros < 0 ? Money.minus : ""
    let value = abs(euros)
    if value >= 1000 {
        var text = String(format: "%.1f", value / 1000)
        if text.hasSuffix(".0") { text.removeLast(2) }
        return "\(sign)\(text.replacingOccurrences(of: ".", with: ","))\u{00A0}k€"
    }
    return "\(sign)\(Int(value.rounded()))\u{00A0}€"
}

// MARK: Rows

// MARK: Layout helpers

private struct SummarySection<Content: View>: View {
    var title: String
    var action: (String, () -> Void)? = nil
    var padded = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: CarliSpace.s8) {
            HStack {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(CarliColor.text)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let action {
                    Button(action.0, action: action.1)
                        .font(.subheadline.weight(.medium))
                }
            }
            CarliCard(padding: padded ? CarliSpace.s16 : 0) {
                content
            }
        }
        .padding(.top, CarliSpace.s12)
    }
}

private struct Muted: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(CarliColor.text2)
    }
}

private struct SummarySkeleton: View {
    var body: some View {
        VStack(spacing: CarliSpace.s12) {
            CarliCard { SkeletonBar(width: 300, height: 136) }
            Grid(horizontalSpacing: CarliSpace.s12, verticalSpacing: CarliSpace.s12) {
                ForEach(0..<2, id: \.self) { _ in
                    GridRow {
                        ForEach(0..<2, id: \.self) { _ in
                            CarliCard {
                                SkeletonBar(width: 90, height: 13)
                                SkeletonBar(width: 130, height: 26).padding(.top, CarliSpace.s8)
                            }
                        }
                    }
                }
            }
        }
    }
}
