import SwiftUI
import WidgetKit

/// Whole euros for the tight Lock Screen slots: "1.234 €".
private func euros(_ cents: Int) -> String {
    let units = Int((Double(abs(cents)) / 100).rounded())
    return "\(cents < 0 ? Money.minus : "")\(Money.grouped(units))\u{00A0}€"
}

/// "Hoy", "Ayer" or "26 oct" for an expense date.
private func dayLabel(_ iso: String, now: Date) -> String {
    guard let day = CarliDate.day(iso) else { return "" }
    let calendar = CarliDate.calendar
    if calendar.isDate(day, inSameDayAs: now) { return "Hoy" }
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
        return "Ayer"
    }
    return CarliDate.short(day)
}

/// Share of the period already elapsed, for the days ring.
private func periodElapsed(_ period: WidgetSnapshot.Period, now: Date) -> Double {
    guard let start = CarliDate.day(period.startDate), let end = CarliDate.day(period.endDate) else { return 0 }
    let total = end.timeIntervalSince(start) + 24 * 60 * 60
    guard total > 0 else { return 1 }
    return min(max(now.timeIntervalSince(start) / total, 0), 1)
}

// MARK: - A · line above the clock

struct InlineView: View {
    var entry: SpendingEntry<InlineIntent>

    var body: some View {
        switch entry.state {
        case .loaded(let snapshot):
            switch entry.configuration.content {
            case .spent:
                Text("Gastado \(euros(snapshot.period.spentCents)) · \(Plural.daysLeft(snapshot.period.remainingDays))")
            case .latest:
                if let last = snapshot.latest.first {
                    Text("Último: \(Money.format(last.amountCents)) \(last.name)")
                } else {
                    Text("Sin gastos este periodo")
                }
            }
        case .signedOut:
            Text("carli · inicia sesión")
        case .unavailable:
            Text("carli · sin conexión")
        }
    }
}

// MARK: - B · small ring

struct CircularView: View {
    var entry: SpendingEntry<RingIntent>

    var body: some View {
        switch entry.state {
        case .loaded(let snapshot):
            ring(snapshot)
        case .signedOut, .unavailable:
            Image(systemName: "eurosign")
                .font(.title2.weight(.semibold))
        }
    }

    @ViewBuilder
    private func ring(_ snapshot: WidgetSnapshot) -> some View {
        switch (entry.configuration.content, snapshot.budgetFraction) {
        case (.remaining, let used?):
            gauge(used, value: euros(snapshot.period.budgetRemainingCents).replacingOccurrences(of: "\u{00A0}€", with: ""),
                  caption: "quedan €")
        case (.percent, let used?):
            gauge(used, value: Plural.percent(basisPoints: snapshot.period.budgetPercentBp), caption: "usado")
        case (.days, _):
            gauge(periodElapsed(snapshot.period, now: entry.date), value: "\(snapshot.period.remainingDays)",
                  caption: snapshot.period.remainingDays == 1 ? "día" : "días")
        default:
            // Without budgets there is nothing to fill: show what the period has cost against the days gone.
            gauge(periodElapsed(snapshot.period, now: entry.date),
                  value: euros(snapshot.period.spentCents).replacingOccurrences(of: "\u{00A0}€", with: ""), caption: "gastado €")
        }
    }

    private func gauge(_ fraction: Double, value: String, caption: String) -> some View {
        Gauge(value: fraction) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(caption)
                    .font(.system(size: 8, weight: .medium))
                    .opacity(0.75)
            }
            .padding(.horizontal, 2)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}

// MARK: - C · rectangle

struct RectangularView: View {
    var entry: SpendingEntry<RectangleIntent>

    var body: some View {
        switch entry.state {
        case .loaded(let snapshot):
            content(snapshot)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .signedOut:
            message("carli", "Abre la app e inicia sesión")
        case .unavailable:
            message("carli", "Sin conexión")
        }
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let today = "Hoy llevas \(Money.format(snapshot.today.spentCents))"
        if snapshot.latest.isEmpty {
            message("Sin gastos este periodo", today)
        } else {
            switch entry.configuration.content {
            case .latestAndToday:
                let last = snapshot.latest[0]
                VStack(alignment: .leading, spacing: 1) {
                    Text("Último gasto · \(dayLabel(last.date, now: entry.date))")
                        .font(.caption2)
                        .opacity(0.7)
                    line(last)
                        .font(.headline)
                    Text(today)
                        .font(.caption2)
                        .opacity(0.7)
                }
            case .lastTwo:
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(snapshot.latest.prefix(2)) { expense in
                        line(expense)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("Hoy \(Money.format(snapshot.today.spentCents)) · \(snapshot.today.count == 1 ? "1 gasto" : "\(snapshot.today.count) gastos")")
                        .font(.caption2)
                        .opacity(0.7)
                }
            }
        }
    }

    private func line(_ expense: WidgetSnapshot.Expense) -> some View {
        Text("\(Money.format(expense.amountCents)) \(expense.name)")
            .lineLimit(1)
            .monospacedDigit()
    }

    private func message(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.headline)
            Text(detail).font(.caption2).opacity(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("A", as: .accessoryInline) {
    SpendingInlineWidget()
} timeline: {
    SpendingEntry(date: .now, state: .loaded(.sample), configuration: InlineIntent())
}

#Preview("B", as: .accessoryCircular) {
    SpendingCircularWidget()
} timeline: {
    SpendingEntry(date: .now, state: .loaded(.sample), configuration: RingIntent())
}

#Preview("C", as: .accessoryRectangular) {
    SpendingRectangularWidget()
} timeline: {
    SpendingEntry(date: .now, state: .loaded(.sample), configuration: RectangleIntent())
}
