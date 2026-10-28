import AppIntents
import WidgetKit

enum InlineContent: String, AppEnum {
    case spent, latest

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Contenido"
    static let caseDisplayRepresentations: [InlineContent: DisplayRepresentation] = [
        .spent: "Gastado en el periodo",
        .latest: "Último gasto",
    ]
}

enum RingContent: String, AppEnum {
    case remaining, percent, days

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Contenido"
    static let caseDisplayRepresentations: [RingContent: DisplayRepresentation] = [
        .remaining: "Lo que queda",
        .percent: "Porcentaje usado",
        .days: "Días hasta la nómina",
    ]
}

enum RectangleContent: String, AppEnum {
    case latestAndToday, lastTwo

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Contenido"
    static let caseDisplayRepresentations: [RectangleContent: DisplayRepresentation] = [
        .latestAndToday: "Último gasto y hoy",
        .lastTwo: "Dos últimos gastos",
    ]
}

struct InlineIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Gasto del periodo"

    @Parameter(title: "Mostrar", default: .spent)
    var content: InlineContent
}

struct RingIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Presupuesto"

    @Parameter(title: "Mostrar", default: .remaining)
    var content: RingContent
}

struct RectangleIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Últimos gastos"

    @Parameter(title: "Mostrar", default: .latestAndToday)
    var content: RectangleContent
}
