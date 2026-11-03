import Charts
import SwiftUI

struct BodySiteRoute: Hashable { var id: String }
struct BodySitesRoute: Hashable {}

// MARK: Cuerpo

/// Cuerpo: the body viewer with every site's latest value and its change, and the list below it.
struct BodyView: View {
    let api: APIClient
    var measure: () -> Void

    @State private var overview: BodyOverview?
    @State private var compare: BodyCompare = .first
    @State private var failed: String?

    var body: some View {
        HealthPage(loaded: overview != nil, failed: failed, retry: load) {
            if let overview { content(overview) }
        }
        .healthSettingsButton()
        .refreshable { await load() }
        .task(id: compare) { await load() }
        .onHealthChanged { await load() }
        .healthDestinations(api: api)
    }

    @ViewBuilder
    private func content(_ overview: BodyOverview) -> some View {
        let measured = overview.sites.contains { $0.latest != nil }

        if overview.sites.isEmpty {
            CarliCard {
                VStack(alignment: .leading, spacing: CarliSpace.s12) {
                    Text("No tienes sitios de medición activos.").font(.subheadline).foregroundStyle(CarliColor.text2)
                    NavigationLink("Sitios de medición", value: BodySitesRoute())
                }
            }
        } else {
            if measured {
                Picker("Comparar con", selection: $compare) {
                    ForEach(BodyCompare.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            CarliCard {
                VStack(alignment: .leading, spacing: CarliSpace.s12) {
                    BodyFigure(sites: overview.sites)
                        .frame(height: 380)
                    Text(caption(overview))
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                }
            }

            if !measured || !overview.measuredToday {
                Button(action: measure) {
                    Label("Medirse ahora", systemImage: "ruler")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(CarliColor.primary)
                .foregroundStyle(CarliColor.onPrimary)
                .controlSize(.large)
            }

            CarliCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(overview.sites.enumerated()), id: \.element.id) { index, site in
                        if index > 0 { Divider().padding(.leading, CarliSpace.s16) }
                        NavigationLink(value: BodySiteRoute(id: site.id)) { BodySiteRow(site: site) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }

        NavigationLink(value: BodySitesRoute()) {
            CarliCard {
                HStack {
                    Label("Sitios de medición", systemImage: "list.bullet")
                        .font(.subheadline)
                        .foregroundStyle(CarliColor.text)
                    Spacer()
                    Chevron()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func caption(_ overview: BodyOverview) -> String {
        guard let last = overview.lastMeasuredAt.flatMap(HealthDate.parse) else {
            return "Aún no hay medidas. Pulsa + para apuntar las primeras."
        }
        return "Última medida: \(CarliDate.long(last)). Cambios \(compare.caption), en cm."
    }

    private func load() async {
        do {
            overview = try await BodyAPI.overview(api, compare: compare)
            failed = nil
        } catch {
            if overview == nil { failed = error.apiMessage(fallback: "Comprueba la conexión.") }
        }
    }
}

private struct BodySiteRow: View {
    var site: BodySiteOverview

    var body: some View {
        HStack(spacing: CarliSpace.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(.body).foregroundStyle(CarliColor.text)
                if let latest = site.latest {
                    Text(CarliDate.long(latest.date)).font(.footnote).foregroundStyle(CarliColor.text2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(site.latest.map { BodyFormat.cm($0.valueCm) } ?? "–")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CarliColor.text)
                if let change = site.changeCm {
                    Text("\(BodyFormat.change(change)) cm").font(.footnote).monospacedDigit().foregroundStyle(CarliColor.text2)
                }
            }
            Chevron()
        }
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, CarliSpace.s12)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Visor

/// Front silhouette with a dot per site and its value in a column beside the body. The person
/// faces the viewer: their right side is on the left column, their left side on the right one.
struct BodyFigure: View {
    var sites: [BodySiteOverview]

    private static let labelHeight: CGFloat = 36
    /// Silhouette height over its width.
    private static let aspect: CGFloat = 2.6

    var body: some View {
        GeometryReader { geo in
            let figureWidth = min(geo.size.width * 0.38, geo.size.height / Self.aspect)
            let figure = CGRect(x: (geo.size.width - figureWidth) / 2, y: (geo.size.height - figureWidth * Self.aspect) / 2,
                                width: figureWidth, height: figureWidth * Self.aspect)
            let labels = layout(in: geo.size, figure: figure)

            ZStack(alignment: .topLeading) {
                BodySilhouette()
                    .fill(CarliColor.surface2)
                    .frame(width: figure.width, height: figure.height)
                    .offset(x: figure.minX, y: figure.minY)
                    .accessibilityHidden(true)

                Path { path in
                    for label in labels {
                        path.move(to: label.anchor)
                        path.addLine(to: label.dot)
                    }
                }
                .stroke(CarliColor.text3, lineWidth: 0.5)
                .accessibilityHidden(true)

                ForEach(labels) { label in
                    Circle()
                        .fill(CarliColor.text)
                        .overlay(Circle().stroke(CarliColor.surface, lineWidth: 2))
                        .frame(width: 9, height: 9)
                        .position(label.dot)
                        .accessibilityHidden(true)
                }

                ForEach(labels) { label in
                    NavigationLink(value: BodySiteRoute(id: label.site.id)) {
                        BodyFigureLabel(site: label.site, leading: label.leftColumn)
                            .frame(width: label.width, alignment: label.leftColumn ? .trailing : .leading)
                    }
                    .buttonStyle(.plain)
                    .position(x: label.leftColumn ? label.width / 2 : geo.size.width - label.width / 2, y: label.y)
                }
            }
        }
    }

    private struct Placed: Identifiable {
        var site: BodySiteOverview
        var dot: CGPoint
        var y: CGFloat
        var leftColumn: Bool
        var width: CGFloat
        var id: String { site.id }

        /// Inner edge of the label, where the leader line starts.
        var labelX: CGFloat = 0
        var anchor: CGPoint { CGPoint(x: labelX, y: y) }
    }

    private func layout(in size: CGSize, figure: CGRect) -> [Placed] {
        let columnWidth = max(figure.minX - CarliSpace.s8, 60)
        var placed = sites.map { site -> Placed in
            let unit = site.bodyZone.point(side: site.side)
            let dot = CGPoint(x: figure.minX + unit.x * figure.width, y: figure.minY + unit.y * figure.height)
            let left = Self.leftColumn(site)
            var item = Placed(site: site, dot: dot, y: dot.y, leftColumn: left, width: columnWidth)
            item.labelX = left ? columnWidth + 2 : size.width - columnWidth - 2
            return item
        }

        // Keep labels in each column apart, then pull the column back inside the frame.
        for left in [true, false] {
            let indices = placed.indices.filter { placed[$0].leftColumn == left }.sorted { placed[$0].dot.y < placed[$1].dot.y }
            var floor = Self.labelHeight / 2
            for index in indices {
                placed[index].y = max(placed[index].y, floor)
                floor = placed[index].y + Self.labelHeight
            }
            var ceiling = size.height - Self.labelHeight / 2
            for index in indices.reversed() {
                placed[index].y = min(placed[index].y, ceiling)
                ceiling = placed[index].y - Self.labelHeight
            }
        }
        return placed
    }

    /// Paired zones go to the column on their side; centre zones alternate so neither column crowds.
    private static func leftColumn(_ site: BodySiteOverview) -> Bool {
        let zone = site.bodyZone
        if zone.paired { return site.side != "left" }
        switch zone {
        case .neck, .chest, .waist: return true
        default: return false
        }
    }
}

private struct BodyFigureLabel: View {
    var site: BodySiteOverview
    var leading: Bool

    var body: some View {
        VStack(alignment: leading ? .trailing : .leading, spacing: 0) {
            Text(site.name)
                .font(.caption2)
                .foregroundStyle(CarliColor.text2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(site.latest.map { $0.valueCm.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "es_ES"))) } ?? "–")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(CarliColor.text)
                if let change = site.changeCm {
                    Text(BodyFormat.change(change))
                        .font(.caption2)
                        .foregroundStyle(CarliColor.text2)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        guard let latest = site.latest else { return "\(site.name), sin medidas" }
        var text = "\(site.name), \(BodyFormat.cm(latest.valueCm))"
        if let change = site.changeCm { text += ", cambio \(BodyFormat.change(change)) centímetros" }
        return text
    }
}

/// A neutral front silhouette in a 1 × 2.6 box, the union of its overlapping parts.
nonisolated struct BodySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * w, y: rect.minY + y * h) }
        func limb(_ points: [CGPoint], width: CGFloat) -> Path {
            var line = Path()
            line.addLines(points)
            return line.strokedPath(StrokeStyle(lineWidth: width * w, lineCap: .round, lineJoin: .round))
        }

        // Head and neck.
        var path = Path(ellipseIn: CGRect(x: rect.minX + 0.39 * w, y: rect.minY + 0.012 * h, width: 0.22 * w, height: 0.105 * h))
        path = path.union(limb([p(0.5, 0.10), p(0.5, 0.17)], width: 0.13))

        // Torso: shoulders, waist and hips.
        var torso = Path()
        torso.move(to: p(0.36, 0.152))
        torso.addLine(to: p(0.64, 0.152))
        torso.addQuadCurve(to: p(0.73, 0.20), control: p(0.73, 0.152))
        torso.addLine(to: p(0.67, 0.33))
        torso.addQuadCurve(to: p(0.66, 0.40), control: p(0.65, 0.37))
        torso.addLine(to: p(0.69, 0.49))
        torso.addQuadCurve(to: p(0.5, 0.535), control: p(0.62, 0.54))
        torso.addQuadCurve(to: p(0.31, 0.49), control: p(0.38, 0.54))
        torso.addLine(to: p(0.34, 0.40))
        torso.addQuadCurve(to: p(0.33, 0.33), control: p(0.35, 0.37))
        torso.addLine(to: p(0.27, 0.20))
        torso.addQuadCurve(to: p(0.36, 0.152), control: p(0.27, 0.152))
        torso.closeSubpath()
        path = path.union(torso)

        // Arms and hands.
        for mirror in [false, true] {
            func m(_ x: CGFloat, _ y: CGFloat) -> CGPoint { p(mirror ? 1 - x : x, y) }
            path = path.union(limb([m(0.29, 0.19), m(0.22, 0.34), m(0.17, 0.50)], width: 0.10))
            path = path.union(Path(ellipseIn: CGRect(origin: m(mirror ? 0.21 : 0.12, 0.495), size: CGSize(width: 0.09 * w, height: 0.05 * h))))
            // Legs and feet.
            path = path.union(limb([m(0.405, 0.50), m(0.405, 0.70), m(0.42, 0.93)], width: 0.14))
            path = path.union(limb([m(0.42, 0.95), m(0.37, 0.96)], width: 0.07))
        }
        return path
    }
}

// MARK: Sitio

/// One site: its evolution chart and every value, newest first.
struct BodySiteDetailView: View {
    let api: APIClient
    let id: String

    @State private var site: BodySite?
    @State private var values: [SiteValue]?
    @State private var range: HealthRange = .all
    @State private var editing = false
    @State private var failed: String?
    @State private var toast: String?

    var body: some View {
        List {
            if let values {
                Section {
                    Picker("Periodo", selection: $range) {
                        ForEach(HealthRange.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    SiteChart(values: values)
                        .frame(height: 220)
                    if let first = values.first, let last = values.last, values.count > 1 {
                        LabeledContent("Cambio", value: "\(BodyFormat.change(last.valueCm - first.valueCm)) cm")
                        LabeledContent("Mínimo", value: BodyFormat.cm(values.map(\.valueCm).min() ?? last.valueCm))
                        LabeledContent("Máximo", value: BodyFormat.cm(values.map(\.valueCm).max() ?? last.valueCm))
                    }
                }
                if !values.isEmpty {
                    Section("Medidas") {
                        ForEach(values.reversed()) { value in
                            LabeledContent("\(CarliDate.long(value.date)), \(value.date.formatted(date: .omitted, time: .shortened))",
                                           value: BodyFormat.cm(value.valueCm))
                                .monospacedDigit()
                                .swipeActions {
                                    DeleteSwipeButton("Borrar") { Task { await delete(value) } }
                                }
                        }
                    }
                }
            } else if let failed {
                Text(failed).foregroundStyle(CarliColor.negative)
            } else {
                ProgressView()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle(site?.name ?? "Medida")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if site != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Editar") { editing = true }
                }
            }
        }
        .sheet(isPresented: $editing) {
            if let site { BodySiteEditor(api: api, site: site) { toast = $0 } }
        }
        .carliToast($toast)
        .task(id: range) { await load() }
        .onHealthChanged { await load() }
    }

    private func load() async {
        do {
            async let sites = BodyAPI.sites(api, archived: true)
            async let history = BodyAPI.history(api, site: id, from: range.start)
            let all = try await sites
            site = all.first { $0.id == id }
            values = try await history
            failed = nil
        } catch {
            if values == nil { failed = error.apiMessage(fallback: "No se ha podido cargar.") }
        }
    }

    private func delete(_ value: SiteValue) async {
        do {
            try await BodyAPI.deleteValue(api, id: value.id)
            toast = "Medida borrada"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido borrar la medida.")
        }
    }
}

/// Evolution of one site, in lime like the weight chart.
private struct SiteChart: View {
    var values: [SiteValue]

    var body: some View {
        if values.count < 2 {
            Text(values.isEmpty ? "Aún no hay medidas en este periodo." : "Con una medida más verás la evolución.")
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let numbers = values.map(\.valueCm)
            let low = numbers.min() ?? 0, high = numbers.max() ?? 1
            let pad = max((high - low) * 0.15, 0.5)
            Chart(values) { value in
                AreaMark(x: .value("Fecha", value.date), yStart: .value("Base", low - pad), yEnd: .value("cm", value.valueCm))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [CarliColor.chartAccent.opacity(0.25), CarliColor.chartAccent.opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Fecha", value.date), y: .value("cm", value.valueCm))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .foregroundStyle(CarliColor.chartAccent)
                PointMark(x: .value("Fecha", value.date), y: .value("cm", value.valueCm))
                    .symbolSize(24)
                    .foregroundStyle(CarliColor.chartAccent)
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
            .accessibilityLabel("Evolución en centímetros")
        }
    }
}

// MARK: Medirse

/// "Medirse": every active site in one form, all saved with the same date. Empty fields are skipped.
struct BodyMeasureSheet: View {
    let api: APIClient
    var onSaved: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var sites: [BodySiteOverview]?
    @State private var entries: [String: String] = [:]
    @State private var date = Date.now
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fecha", selection: $date, in: ...Date.now)
                }
                if let sites {
                    Section {
                        ForEach(sites) { site in
                            HStack {
                                Text(site.name)
                                Spacer()
                                TextField(site.latest.map { decimal($0.valueCm) } ?? "0,0", text: binding(site.id))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .monospacedDigit()
                                    .frame(width: 90)
                                Text("cm").foregroundStyle(CarliColor.text2)
                            }
                        }
                    } header: {
                        Text("Medidas")
                    } footer: {
                        Text("En gris, la última medida. Deja vacío lo que no midas hoy.")
                    }
                } else if let error {
                    Text(error).foregroundStyle(CarliColor.negative)
                } else {
                    ProgressView()
                }
                if let error, sites != nil {
                    Text(error).foregroundStyle(CarliColor.negative)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CarliColor.bg)
            .navigationTitle("Medirse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark") { Task { await save() } }
                        .disabled(values.isEmpty || saving)
                }
            }
        }
        .task {
            do {
                sites = try await BodyAPI.overview(api, compare: .first).sites
            } catch {
                self.error = error.apiMessage(fallback: "No se han podido cargar los sitios.")
            }
        }
    }

    private var values: [(site: String, cm: Double)] {
        (sites ?? []).compactMap { site in
            guard let text = entries[site.id], let cm = Self.parse(text), cm > 0, cm < 400 else { return nil }
            return (site.id, cm)
        }
    }

    private func binding(_ id: String) -> Binding<String> {
        Binding(get: { entries[id] ?? "" }, set: { entries[id] = $0 })
    }

    private func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(Locale(identifier: "es_ES")))
    }

    static func parse(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            let count = values.count
            try await BodyAPI.record(api, values: values, at: date)
            onSaved(count == 1 ? "Medida guardada" : "\(count) medidas guardadas")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se han podido guardar las medidas.")
        }
    }
}

// MARK: Sitios

/// Sitios de medición: order, create, edit, archive and delete.
struct BodySitesView: View {
    let api: APIClient

    @State private var sites: [BodySite]?
    @State private var editing: BodySite?
    @State private var creating = false
    @State private var deleting: BodySite?
    @State private var failed: String?
    @State private var toast: String?

    var body: some View {
        List {
            if let sites {
                let active = sites.filter { !$0.archived }
                let archived = sites.filter(\.archived)
                Section {
                    ForEach(active) { site in
                        row(site)
                            .swipeActions {
                                DeleteSwipeButton("Borrar") { deleting = site }
                                Button("Archivar", systemImage: "archivebox") { Task { await archive(site, true) } }
                            }
                    }
                    .onMove { from, to in
                        var ids = active.map(\.id)
                        ids.move(fromOffsets: from, toOffset: to)
                        Task { await reorder(ids) }
                    }
                } header: {
                    Text("Activos")
                } footer: {
                    Text("Mantén pulsado y arrastra para ordenar. La zona decide dónde sale el punto en el cuerpo.")
                }
                if !archived.isEmpty {
                    Section("Archivados") {
                        ForEach(archived) { site in
                            row(site)
                                .swipeActions {
                                    DeleteSwipeButton("Borrar") { deleting = site }
                                    Button("Recuperar", systemImage: "arrow.uturn.backward") { Task { await archive(site, false) } }
                                }
                        }
                    }
                }
            } else if let failed {
                Text(failed).foregroundStyle(CarliColor.negative)
            } else {
                ProgressView()
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Sitios de medición")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nuevo sitio", systemImage: "plus") { creating = true }
            }
        }
        .sheet(isPresented: $creating) { BodySiteEditor(api: api, site: nil) { toast = $0 } }
        .sheet(item: $editing) { BodySiteEditor(api: api, site: $0) { toast = $0 } }
        .confirmationDialog("¿Borrar \(deleting?.name ?? "el sitio")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Borrar sitio y sus medidas", role: .destructive) {
                if let site = deleting { Task { await delete(site) } }
            }
        } message: {
            Text("Se borran también todas sus medidas. Si solo quieres dejar de medirlo, archívalo.")
        }
        .carliToast($toast)
        .task { await load() }
        .onHealthChanged { await load() }
    }

    private func row(_ site: BodySite) -> some View {
        Button { editing = site } label: {
            HStack {
                Text(site.name).foregroundStyle(CarliColor.text)
                Spacer()
                Text(BodySiteEditor.zoneLabel(site.bodyZone, side: site.side)).font(.footnote).foregroundStyle(CarliColor.text2)
            }
        }
    }

    private func load() async {
        do {
            sites = try await BodyAPI.sites(api, archived: true)
            failed = nil
        } catch {
            if sites == nil { failed = error.apiMessage(fallback: "No se han podido cargar los sitios.") }
        }
    }

    private func reorder(_ ids: [String]) async {
        if let current = sites {
            let byId = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
            sites = ids.compactMap { byId[$0] } + current.filter(\.archived)
        }
        do { try await BodyAPI.reorder(api, ids: ids) } catch { toast = error.apiMessage(fallback: "No se ha podido ordenar.") }
    }

    private func archive(_ site: BodySite, _ archived: Bool) async {
        do {
            try await BodyAPI.archive(api, id: site.id, archived)
            toast = archived ? "\(site.name) archivado" : "\(site.name) recuperado"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido guardar.")
        }
    }

    private func delete(_ site: BodySite) async {
        deleting = nil
        do {
            try await BodyAPI.deleteSite(api, id: site.id)
            toast = "Sitio borrado"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido borrar.")
        }
    }
}

/// New or edited site: name, zone and, for limbs, the side.
struct BodySiteEditor: View {
    let api: APIClient
    var site: BodySite?
    var onSaved: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var zone: BodyZone = .waist
    @State private var side = "right"
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre", text: $name, prompt: Text(suggestedName))
                }
                Section {
                    Picker("Zona", selection: $zone) {
                        ForEach(BodyZone.allCases) { Text($0.title).tag($0) }
                    }
                    if zone.paired {
                        Picker("Lado", selection: $side) {
                            Text("Derecho").tag("right")
                            Text("Izquierdo").tag("left")
                        }
                        .pickerStyle(.segmented)
                    }
                } footer: {
                    Text("La zona decide dónde aparece el punto en el cuerpo.")
                }
                if let error {
                    Text(error).foregroundStyle(CarliColor.negative)
                }
            }
            .scrollContentBackground(.hidden)
            .background(CarliColor.bg)
            .navigationTitle(site == nil ? "Nuevo sitio" : "Editar sitio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", systemImage: "checkmark") { Task { await save() } }
                        .disabled(saving)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            guard let site else { return }
            name = site.name
            zone = site.bodyZone
            side = site.side ?? "right"
        }
    }

    private var suggestedName: String { Self.zoneLabel(zone, side: zone.paired ? side : nil) }

    static func zoneLabel(_ zone: BodyZone, side: String?) -> String {
        guard zone.paired, let side else { return zone.title }
        let feminine = zone == .wrist
        let word = side == "left" ? (feminine ? "izquierda" : "izquierdo") : (feminine ? "derecha" : "derecho")
        return "\(zone.title) \(word)"
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let fields = BodyAPI.SiteFields(name: trimmed.isEmpty ? suggestedName : trimmed, zone: zone.rawValue, side: zone.paired ? side : nil)
        do {
            if let site {
                try await BodyAPI.updateSite(api, id: site.id, fields)
                onSaved("Sitio guardado")
            } else {
                try await BodyAPI.createSite(api, fields)
                onSaved("Sitio creado")
            }
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar el sitio.")
        }
    }
}
