import SwiftUI
import WidgetKit

@main
struct CarliWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SpendingInlineWidget()
        SpendingCircularWidget()
        SpendingRectangularWidget()
    }
}

/// Line above the clock: what the period has cost so far, or the latest expense.
struct SpendingInlineWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "spending-inline", intent: InlineIntent.self, provider: SpendingProvider<InlineIntent>()) { entry in
            InlineView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Gasto del periodo")
        .description("Lo gastado en el periodo o tu último gasto, encima de la hora.")
        .supportedFamilies([.accessoryInline])
        .pushHandler(CarliWidgetPushHandler.self)
    }
}

/// Small ring: what is left of the budget, the share used, or the days to payday.
struct SpendingCircularWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "spending-circular", intent: RingIntent.self, provider: SpendingProvider<RingIntent>()) { entry in
            CircularView(entry: entry)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        }
        .configurationDisplayName("Presupuesto")
        .description("Lo que te queda del presupuesto, el porcentaje usado o los días hasta la nómina.")
        .supportedFamilies([.accessoryCircular])
        .pushHandler(CarliWidgetPushHandler.self)
    }
}

/// Two or three lines: the latest expenses and today's total.
struct SpendingRectangularWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "spending-rectangular", intent: RectangleIntent.self, provider: SpendingProvider<RectangleIntent>()) { entry in
            RectangularView(entry: entry)
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        }
        .configurationDisplayName("Últimos gastos")
        .description("Tu último gasto o los dos últimos, con lo que llevas hoy.")
        .supportedFamilies([.accessoryRectangular])
        .pushHandler(CarliWidgetPushHandler.self)
    }
}

/// Sends the WidgetKit push token to the server, which pushes a reload whenever a transaction changes.
struct CarliWidgetPushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        guard !widgets.isEmpty else { return }
        let token = pushInfo.token.map { String(format: "%02x", $0) }.joined()
        Task { await WidgetAPI.registerPushToken(token) }
    }
}
