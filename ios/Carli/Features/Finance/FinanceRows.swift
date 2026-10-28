import SwiftUI

struct TransactionLine: View {
    var transaction: FinanceTransaction
    var accounts: [AccountRef]

    var body: some View {
        RowLayout(symbol: transaction.symbol, soft: transaction.needsCategory,
                  title: transaction.title, subtitle: transaction.subtitle(accounts: accounts),
                  titleBadge: transaction.fromBank ? "building.columns" : nil) {
            Text(transaction.amountLabel)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.isTransfer ? CarliColor.text2
                                 : transaction.amountCents > 0 ? CarliColor.positive : CarliColor.text)
        }
    }
}

/// Icon circle, title and subtitle, trailing figure: the list row shared by movements and charges.
struct RowLayout<Trailing: View>: View {
    var symbol: String
    var soft: Bool
    var title: String
    var subtitle: String
    var titleBadge: String? = nil
    var subtitleLines = 1
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: CarliSpace.s12) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(soft ? CarliColor.text2 : CarliColor.text)
                .frame(width: 40, height: 40)
                .background(CarliColor.surface2, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: CarliSpace.s4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(CarliColor.text)
                        .lineLimit(1)
                    if let titleBadge {
                        Image(systemName: titleBadge)
                            .font(.caption2)
                            .foregroundStyle(CarliColor.text3)
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                    .lineLimit(subtitleLines)
            }
            Spacer(minLength: CarliSpace.s8)
            trailing
        }
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, CarliSpace.s12)
        .accessibilityElement(children: .combine)
    }
}


/// Glass chevrons around a period menu. Periods come newest first.
struct PeriodBar: View {
    var periods: [FinancePeriod]
    var selected: FinancePeriod?
    var select: (FinancePeriod) -> Void

    var body: some View {
        HStack(spacing: CarliSpace.s8) {
            Button("Periodo anterior", systemImage: "chevron.left") {
                if let older = neighbour(+1) { select(older) }
            }
            .labelStyle(.iconOnly)
            .disabled(neighbour(+1) == nil)
            .opacity(neighbour(+1) == nil ? 0.35 : 1)

            Menu {
                Picker("Periodo", selection: Binding(
                    get: { selected?.id ?? "" },
                    set: { id in if let period = periods.first(where: { $0.id == id }) { select(period) } }
                )) {
                    ForEach(periods) { period in
                        Text(period.isCurrent == true ? "\(period.name) · en curso" : period.name).tag(period.id)
                    }
                }
            } label: {
                HStack(spacing: CarliSpace.s4) {
                    Text(selected?.name ?? "Periodo")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(CarliColor.text3)
                }
                .foregroundStyle(CarliColor.text)
                .frame(maxWidth: .infinity)
            }
            .disabled(periods.isEmpty)

            Button("Periodo siguiente", systemImage: "chevron.right") {
                if let newer = neighbour(-1) { select(newer) }
            }
            .labelStyle(.iconOnly)
            .disabled(neighbour(-1) == nil)
            .opacity(neighbour(-1) == nil ? 0.35 : 1)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .tint(CarliColor.text)
    }

    private func neighbour(_ offset: Int) -> FinancePeriod? {
        guard let selected, let index = periods.firstIndex(where: { $0.id == selected.id }) else { return nil }
        let target = index + offset
        return periods.indices.contains(target) ? periods[target] : nil
    }
}

struct BudgetLine: View {
    var row: BudgetRow
    /// Current period only: mention the projection when it changes the outlook.
    var showProjection = false
    var badge: CarliBadge? = nil

    var body: some View {
        let state = row.state
        let figureColor = state == .exceeded ? CarliColor.negative : state == .warning ? CarliColor.warning : CarliColor.text2
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: CarliSpace.s8) {
                Text(row.category.label)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CarliColor.text)
                    .lineLimit(1)
                Spacer(minLength: CarliSpace.s8)
                HStack(spacing: CarliSpace.s4) {
                    if state != .ok {
                        Image(systemName: state == .exceeded ? "exclamationmark.circle.fill" : "exclamationmark.triangle.fill")
                    }
                    Text("\(Money.format(row.spentCents)) / \(Money.format(row.limitCents))")
                        .monospacedDigit()
                }
                .font(.subheadline.weight(state == .ok ? .regular : .semibold))
                .foregroundStyle(figureColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            }
            ProgressBar(ratio: row.barRatio)
            HStack(alignment: .firstTextBaseline, spacing: CarliSpace.s8) {
                Text(row.note(showProjection: showProjection))
                    .font(.caption)
                    .foregroundStyle(CarliColor.text2)
                Spacer(minLength: 0)
                badge
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Neutral progress bar: the state is told by the figure, never by the bar's colour.
struct ProgressBar: View {
    var ratio: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(CarliColor.surface2)
                Capsule().fill(CarliColor.text)
                    .frame(width: proxy.size.width * min(max(ratio, 0), 1))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

struct UncategorizedNotice: View {
    var summary: UncategorizedSummary
    var review: () -> Void

    var body: some View {
        HStack(spacing: CarliSpace.s12) {
            Image(systemName: "circle.dashed")
                .font(.title3)
                .foregroundStyle(CarliColor.text2)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(Money.format(summary.expenseCents)) sin categorizar")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CarliColor.text)
                Text("\(summary.count == 1 ? "1 gasto" : "\(summary.count) gastos") aún no cuenta\(summary.count == 1 ? "" : "n") en ningún presupuesto.")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
            }
            Spacer(minLength: 0)
            Button("Revisar", action: review)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CarliColor.brandInk)
        }
        .padding(CarliSpace.s12)
        .background(CarliColor.surface2, in: .rect(cornerRadius: CarliRadius.control, style: .continuous))
    }
}
