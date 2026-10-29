import Charts
import SwiftUI

struct MeasurementRoute: Hashable { var id: String }
struct HealthSettingsRoute: Hashable {}

extension View {
    /// Pages every Salud section can push.
    func healthDestinations(api: APIClient) -> some View {
        navigationDestination(for: MeasurementRoute.self) { MeasurementDetailView(api: api, id: $0.id) }
            .navigationDestination(for: HealthSettingsRoute.self) { _ in HealthSettingsView(api: api) }
            .habitsDestinations(api: api)
    }

    func onHealthChanged(_ reload: @escaping () async -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .healthChanged)) { _ in Task { await reload() } }
    }

    fileprivate func healthSettingsButton() -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: HealthSettingsRoute()) { Image(systemName: "gearshape") }
                    .accessibilityLabel("Ajustes de Salud")
            }
        }
    }
}

/// Scrolling page shell shared by the Salud sections.
private struct HealthPage<Content: View>: View {
    var loaded: Bool
    var failed: String?
    var retry: () async -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s16) {
                if loaded {
                    content
                } else if let failed {
                    ContentUnavailableView {
                        Label("No se ha podido cargar Salud", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(failed)
                    } actions: {
                        Button("Reintentar") { Task { await retry() } }
                    }
                    .padding(.top, CarliSpace.s48)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, CarliSpace.s48)
                }
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s48)
        }
        .background(CarliColor.bg)
    }
}

// MARK: Resumen

/// Resumen: the weight chart on top, then the latest weigh-in, its composition and today's habits.
struct HealthSummaryView: View {
    let api: APIClient
    var habitsOn: Bool
    var weigh: () -> Void

    @State private var summary: HealthSummary?
    @State private var points: [BodyMeasurement] = []
    @State private var range: HealthRange = .quarter
    @State private var habits: HabitsToday?
    @State private var failed: String?
    @State private var habitActions: HabitActions

    init(api: APIClient, habitsOn: Bool, weigh: @escaping () -> Void) {
        self.api = api
        self.habitsOn = habitsOn
        self.weigh = weigh
        _habitActions = State(initialValue: HabitActions(api: api))
    }

    var body: some View {
        HealthPage(loaded: summary != nil, failed: failed, retry: load) {
            if let summary { content(summary) }
        }
        .healthSettingsButton()
        .refreshable { await load() }
        .task { await load() }
        .task(id: range) { await loadPoints() }
        .onHealthChanged { await load() }
        .onHabitsChanged { await loadHabits() }
        .healthDestinations(api: api)
    }

    @ViewBuilder
    private func content(_ summary: HealthSummary) -> some View {
        CarliCard {
            VStack(alignment: .leading, spacing: CarliSpace.s12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Peso").font(.footnote).foregroundStyle(CarliColor.text2)
                        Text(summary.latest.map { WeightFormat.kg($0.weightKg) } ?? "Sin pesadas")
                            .font(.largeTitle.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(CarliColor.text)
                    }
                    Spacer()
                    if let latest = summary.latest {
                        Text(relative(latest.date))
                            .font(.footnote)
                            .foregroundStyle(CarliColor.text2)
                    }
                }
                Picker("Periodo", selection: $range) {
                    ForEach(HealthRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                MetricChart(points: points, metric: .weight, goal: summary.goalKg)
                    .frame(height: 200)
                HStack(spacing: CarliSpace.s16) {
                    change("7 días", summary.weekChange)
                    change("30 días", summary.monthChange)
                    if let toGoal = summary.toGoalKg, let goal = summary.goalKg {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Objetivo \(WeightFormat.kg(goal, digits: 0))").font(.caption).foregroundStyle(CarliColor.text2)
                            Text(toGoal <= 0 ? "Conseguido" : "Faltan \(WeightFormat.kg(toGoal))")
                                .font(.subheadline.weight(.semibold)).monospacedDigit()
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }

        if !summary.weighedToday {
            Button(action: weigh) {
                Label("Pesarse ahora", systemImage: "scalemass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(CarliColor.primary)
            .foregroundStyle(CarliColor.onPrimary)
            .controlSize(.large)
        }

        if let measured = summary.latestWithMetrics {
            CarliCard {
                VStack(alignment: .leading, spacing: CarliSpace.s12) {
                    CardHeader(title: "Composición", subtitle: CarliDate.long(measured.date))
                    CompositionGrid(fat: measured.fatPercent, muscle: measured.musclePercent,
                                    water: measured.waterPercent, bmi: measured.bmi)
                    if let kcal = measured.basalKcal {
                        Text("Metabolismo basal: \(kcal) kcal")
                            .font(.footnote)
                            .foregroundStyle(CarliColor.text2)
                    }
                }
            }
        }

        if !summary.profileComplete {
            NavigationLink(value: HealthSettingsRoute()) {
                CarliCard {
                    HStack {
                        Label("Completa tu perfil para que la báscula calcule bien la composición", systemImage: "person.crop.circle")
                            .font(.subheadline)
                            .foregroundStyle(CarliColor.text)
                        Spacer()
                        Chevron()
                    }
                }
            }
            .buttonStyle(.plain)
        }

        if habitsOn, let habits, !habits.habits.isEmpty {
            CarliCard {
                VStack(alignment: .leading, spacing: CarliSpace.s12) {
                    CardHeader(title: "Hábitos de hoy", subtitle: "\(habits.summary.done) de \(habits.summary.total)")
                    if habits.pending.isEmpty {
                        Text("Todo hecho").font(.subheadline).foregroundStyle(CarliColor.text2)
                    } else {
                        HabitRingStrip(habits: habits.pending, actions: habitActions)
                    }
                }
            }
        }
    }

    private func change(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(CarliColor.text2)
            Text(value.map(WeightFormat.change) ?? "–")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(CarliColor.text)
        }
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            summary = try await HealthAPI.summary(api)
            failed = nil
        } catch {
            if summary == nil { failed = error.apiMessage(fallback: "Comprueba la conexión.") }
        }
        await loadPoints()
        await loadHabits()
    }

    private func loadPoints() async {
        if let list = try? await HealthAPI.measurements(api, from: range.start) { points = list }
    }

    private func loadHabits() async {
        guard habitsOn else { return }
        if let envelope: DataEnvelope<HabitsToday> = try? await api.get("v1/habits/today") { habits = envelope.data }
    }
}

private func relative(_ date: Date) -> String {
    let calendar = CarliDate.calendar
    let time = date.formatted(date: .omitted, time: .shortened)
    if calendar.isDateInToday(date) { return "Hoy, \(time)" }
    if calendar.isDateInYesterday(date) { return "Ayer, \(time)" }
    return CarliDate.short(date)
}

private struct ChartPoint: Identifiable {
    var date: Date
    var value: Double
    var id: Date { date }
}

/// Line chart of one metric over time, with the goal as a dashed rule.
struct MetricChart: View {
    var points: [BodyMeasurement]
    var metric: BodyMetric
    var goal: Double?

    var body: some View {
        let values = points.compactMap { point in point.value(metric).map { ChartPoint(date: point.date, value: $0) } }
        if values.count < 2 {
            Text(values.isEmpty ? "Aún no hay datos en este periodo." : "Con una pesada más verás la evolución.")
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let all = values.map(\.value) + (metric == .weight ? [goal].compactMap { $0 } : [])
            let low = (all.min() ?? 0), high = (all.max() ?? 1)
            let pad = max((high - low) * 0.15, metric == .weight ? 1 : 0.5)
            Chart {
                ForEach(values) { point in
                    AreaMark(x: .value("Fecha", point.date), yStart: .value("Base", low - pad), yEnd: .value(metric.title, point.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [CarliColor.chartAccent.opacity(0.25), CarliColor.chartAccent.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Fecha", point.date), y: .value(metric.title, point.value))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .foregroundStyle(CarliColor.chartAccent)
                }
                if metric == .weight, let goal {
                    RuleMark(y: .value("Objetivo", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(CarliColor.text3)
                }
            }
            .chartYScale(domain: (low - pad)...(high + pad))
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(CarliColor.border)
                    AxisValueLabel {
                        if let number = value.as(Double.self) { Text(number.formatted(.number.precision(.fractionLength(0)))) }
                    }
                }
            }
            .accessibilityLabel("Evolución de \(metric.title.lowercased())")
        }
    }
}

// MARK: Mediciones

struct MeasurementsView: View {
    let api: APIClient

    @State private var items: [BodyMeasurement]?
    @State private var failed: String?
    @State private var toast: String?

    var body: some View {
        Group {
            if let items {
                if items.isEmpty {
                    ContentUnavailableView("Sin pesadas", systemImage: "scalemass",
                                           description: Text("Súbete a la báscula con carli abierta o añade el peso con +."))
                } else {
                    List {
                        ForEach(months(items), id: \.title) { month in
                            Section(month.title) {
                                ForEach(month.items) { item in
                                    NavigationLink(value: MeasurementRoute(id: item.id)) { MeasurementRow(item: item) }
                                        .swipeActions {
                                            DeleteSwipeButton("Borrar") { Task { await delete(item) } }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            } else if let failed {
                ContentUnavailableView("No se han podido cargar las pesadas", systemImage: "wifi.exclamationmark", description: Text(failed))
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(CarliColor.bg)
        .healthSettingsButton()
        .refreshable { await load() }
        .task { await load() }
        .onHealthChanged { await load() }
        .healthDestinations(api: api)
        .carliToast($toast)
    }

    private func months(_ items: [BodyMeasurement]) -> [(title: String, items: [BodyMeasurement])] {
        let calendar = CarliDate.calendar
        var order: [String] = []
        var groups: [String: [BodyMeasurement]] = [:]
        for item in items {
            let c = calendar.dateComponents([.year, .month], from: item.date)
            let title = "\(CarliDate.months[c.month! - 1].capitalizedFirst) \(c.year!)"
            if groups[title] == nil { order.append(title) }
            groups[title, default: []].append(item)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    private func load() async {
        do {
            items = try await HealthAPI.measurements(api)
        } catch {
            if items == nil { failed = error.apiMessage(fallback: "Comprueba la conexión.") }
        }
    }

    private func delete(_ item: BodyMeasurement) async {
        do {
            try await HealthAPI.delete(api, id: item.id)
            toast = "Pesada borrada"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido borrar la pesada.")
        }
    }
}

private struct MeasurementRow: View {
    var item: BodyMeasurement

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(WeightFormat.kg(item.weightKg))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(CarliColor.text)
                Text("\(CarliDate.long(item.date)) · \(item.date.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
            }
            Spacer()
            if let fat = item.fatPercent {
                Text("Grasa \(BodyMetric.fat.format(fat))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(CarliColor.text2)
            } else if !item.fromScale {
                CarliBadge(label: "A mano")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct MeasurementDetailView: View {
    let api: APIClient
    let id: String

    @Environment(\.dismiss) private var dismiss
    @State private var item: BodyMeasurement?
    @State private var confirming = false
    @State private var error: String?

    var body: some View {
        List {
            if let item {
                Section {
                    LabeledContent("Peso", value: WeightFormat.kg(item.weightKg, digits: 2))
                    LabeledContent("Fecha", value: "\(CarliDate.long(item.date)), \(item.date.formatted(date: .omitted, time: .shortened))")
                    LabeledContent("Origen", value: item.fromScale ? "Báscula" : "A mano")
                }
                if item.hasComposition || item.bmi != nil {
                    Section("Composición (calculada por la báscula)") {
                        ForEach([BodyMetric.fat, .muscle, .water, .bmi]) { metric in
                            if let value = item.value(metric) { LabeledContent(metric.title, value: metric.format(value)) }
                        }
                        if let kcal = item.basalKcal { LabeledContent("Metabolismo basal", value: "\(kcal) kcal") }
                        if let other = item.visceralOrBone {
                            // The scale's display shows it next to bone and visceral fat; its meaning is still unconfirmed.
                            LabeledContent("Índice 9 (sin confirmar)", value: "\(other)")
                        }
                    }
                }
                if let impedances = item.impedances, !impedances.isEmpty {
                    Section {
                        Text(impedances.map { String(format: "%.1f", Double($0) / 10) }.joined(separator: " · "))
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                    } header: {
                        Text("Impedancias (Ω)")
                    } footer: {
                        Text([item.device, item.firmware].compactMap { $0 }.joined(separator: " · "))
                    }
                }
                Section {
                    Button("Borrar pesada", role: .destructive) { confirming = true }
                }
            } else if let error {
                Text(error).foregroundStyle(CarliColor.negative)
            } else {
                ProgressView()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Pesada")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("¿Borrar esta pesada?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Borrar", role: .destructive) { Task { await delete() } }
        }
        .task {
            do { item = try await HealthAPI.measurement(api, id: id) } catch { self.error = error.apiMessage(fallback: "No se ha podido cargar.") }
        }
    }

    private func delete() async {
        do {
            try await HealthAPI.delete(api, id: id)
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido borrar la pesada.")
        }
    }
}

// MARK: Tendencias

struct HealthTrendsView: View {
    let api: APIClient

    @State private var metric: BodyMetric = .weight
    @State private var range: HealthRange = .quarter
    @State private var points: [BodyMeasurement]?
    @State private var goal: Double?
    @State private var failed: String?

    var body: some View {
        HealthPage(loaded: points != nil, failed: failed, retry: load) {
            if let points { content(points) }
        }
        .healthSettingsButton()
        .refreshable { await load() }
        .task(id: range) { await load() }
        .onHealthChanged { await load() }
        .healthDestinations(api: api)
    }

    @ViewBuilder
    private func content(_ points: [BodyMeasurement]) -> some View {
        Picker("Medida", selection: $metric) {
            ForEach(BodyMetric.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        Picker("Periodo", selection: $range) {
            ForEach(HealthRange.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)

        CarliCard {
            MetricChart(points: points, metric: metric, goal: goal)
                .frame(height: 240)
        }

        let values = points.compactMap { $0.value(metric) }
        if let first = values.last, let last = values.first {
            CarliCard {
                Grid(alignment: .leading, horizontalSpacing: CarliSpace.s16, verticalSpacing: CarliSpace.s12) {
                    GridRow {
                        stat("Ahora", metric.format(last))
                        stat("Cambio", signed(last - first))
                    }
                    GridRow {
                        stat("Mínimo", metric.format(values.min() ?? last))
                        stat("Máximo", metric.format(values.max() ?? last))
                    }
                    GridRow {
                        stat("Media", metric.format(values.reduce(0, +) / Double(values.count)))
                        stat("Pesadas", "\(values.count)")
                    }
                }
            }
        }
    }

    private func signed(_ value: Double) -> String {
        if abs(value) < 0.05 { return "Sin cambios" }
        return "\(value < 0 ? "−" : "+")\(metric.format(abs(value)))"
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.footnote).foregroundStyle(CarliColor.text2)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(CarliColor.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func load() async {
        do {
            points = try await HealthAPI.measurements(api, from: range.start)
            failed = nil
        } catch {
            if points == nil { failed = error.apiMessage(fallback: "Comprueba la conexión.") }
        }
        if goal == nil { goal = try? await HealthAPI.profile(api).goalKg }
    }
}

// MARK: Ajustes

/// Ajustes de Salud: the profile the scale needs, the goal, the weigh-in reminder and Hábitos.
struct HealthSettingsView: View {
    let api: APIClient

    @State private var profile: HealthProfile?
    @State private var failed: String?
    @State private var toast: String?
    @State private var reminderTime = Date.now

    /// ISO weekday 1…7 → initial.
    private static let initials = ["L", "M", "X", "J", "V", "S", "D"]

    var body: some View {
        List {
            if let profile {
                Section {
                    Picker("Altura", selection: binding("height_cm", profile.heightCm ?? 0) { $0 == 0 ? .null : .int($0) }) {
                        Text("Sin indicar").tag(0)
                        ForEach(120...220, id: \.self) { Text("\($0) cm").tag($0) }
                    }
                    DatePicker("Nacimiento", selection: Binding(get: { birth(profile) }, set: { date in
                        Task { await save(["birth_date": .string(HealthDate.day(date))]) }
                    }), in: ...Date.now, displayedComponents: .date)
                    Picker("Sexo", selection: binding("sex", profile.sex ?? "") { $0.isEmpty ? .null : .string($0) }) {
                        Text("Sin indicar").tag("")
                        Text("Hombre").tag("male")
                        Text("Mujer").tag("female")
                    }
                } header: {
                    Text("Perfil")
                } footer: {
                    Text("La báscula usa tu altura, edad y sexo para calcular la grasa, el músculo y el agua.")
                }

                Section("Objetivo") {
                    Picker("Peso objetivo", selection: binding("goal_kg", Int(profile.goalKg ?? 0)) { $0 == 0 ? .null : .int($0) }) {
                        Text("Sin objetivo").tag(0)
                        ForEach(40...200, id: \.self) { Text("\($0) kg").tag($0) }
                    }
                }

                Section {
                    Toggle("Recordar pesarme", isOn: binding("reminder_enabled", profile.reminderEnabled) { .bool($0) })
                    if profile.reminderEnabled {
                        DatePicker("Hora", selection: Binding(get: { reminderTime }, set: { date in
                            reminderTime = date
                            let c = CarliDate.calendar.dateComponents([.hour, .minute], from: date)
                            Task { await save(["reminder_time": .string(String(format: "%02d:%02d", c.hour!, c.minute!))]) }
                        }), displayedComponents: .hourAndMinute)
                        HStack(spacing: CarliSpace.s8) {
                            ForEach(1...7, id: \.self) { day in
                                let on = profile.reminderDays.contains(day)
                                Button(Self.initials[day - 1]) { Task { await toggle(day, in: profile) } }
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(on ? CarliColor.onPrimary : CarliColor.text)
                                    .background(on ? CarliColor.primary : CarliColor.surface2, in: .circle)
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(CarliDate.weekdays[day % 7])
                                    .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                } header: {
                    Text("Recordatorio")
                } footer: {
                    Text("Solo avisa si ese día aún no te has pesado.")
                }

                Section("Hábitos") {
                    NavigationLink("Ajustes de Hábitos", value: HabitsSettingsRoute())
                }

                #if DEBUG
                Section("Pruebas") {
                    NavigationLink(value: SettingsPage.scaleLab) { Label("Báscula (registro de tramas)", systemImage: "scalemass") }
                }
                #endif
            } else if let failed {
                Text(failed).foregroundStyle(CarliColor.negative)
            } else {
                ProgressView()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Ajustes de Salud")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SettingsPage.self) { _ in ScaleLabView() }
        .carliToast($toast)
        .task { await load() }
    }

    private func binding<T>(_ key: String, _ value: T, _ encode: @escaping (T) -> JSONValue) -> Binding<T> {
        Binding(get: { value }, set: { new in Task { await save([key: encode(new)]) } })
    }

    private func birth(_ profile: HealthProfile) -> Date {
        profile.birthDate.flatMap { HealthDate.parse("\($0)T12:00:00Z") }
            ?? CarliDate.calendar.date(byAdding: .year, value: -30, to: .now) ?? .now
    }

    private func toggle(_ day: Int, in profile: HealthProfile) async {
        var days = Set(profile.reminderDays)
        if days.contains(day) { days.remove(day) } else { days.insert(day) }
        guard !days.isEmpty else {
            toast = "Elige al menos un día"
            return
        }
        await save(["reminder_days": .array(days.sorted().map { .int($0) })])
    }

    private func load() async {
        do {
            let loaded = try await HealthAPI.profile(api)
            apply(loaded)
        } catch {
            failed = error.apiMessage(fallback: "No se han podido cargar los ajustes.")
        }
    }

    private func save(_ fields: [String: JSONValue]) async {
        do {
            apply(try await HealthAPI.saveProfile(api, fields))
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido guardar.")
        }
    }

    private func apply(_ loaded: HealthProfile) {
        profile = loaded
        let parts = loaded.reminderTime.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            reminderTime = CarliDate.calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: .now) ?? reminderTime
        }
    }
}
