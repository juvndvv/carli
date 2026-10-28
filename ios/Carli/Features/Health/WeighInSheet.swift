import SwiftUI

/// "Pesarse": connects to the scale with the Salud profile, shows the weight as it settles and
/// saves every result (and the scale's stored history) to the server. Manual entry is the fallback.
struct WeighInSheet: View {
    let api: APIClient
    var onSaved: (String) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var scale = ScaleClient(profile: QNProfile(heightCm: 170, age: 30, sex: .male))
    @State private var profile: HealthProfile?
    @State private var saved: QNResult?
    @State private var uploadFailed = false
    @State private var manual = false
    @State private var manualKg = ""
    @State private var manualDate = Date.now
    @State private var saving = false
    @State private var error: String?
    @State private var uploads: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if manual { manualForm } else { scaleView }
            }
            .background(CarliColor.bg)
            .navigationTitle(manual ? "Añadir peso" : "Pesarse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(saved == nil ? "Cancelar" : "Hecho", systemImage: saved == nil ? "xmark" : "checkmark") { dismiss() }
                }
                if manual {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Guardar", systemImage: "checkmark") { Task { await saveManual() } }
                            .disabled(parsedKg == nil || saving)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .task {
            profile = try? await HealthAPI.profile(api)
            if let profile { scale.profile = profile.scaleProfile }
            scale.onResult = { result in upload(result) }
            scale.start()
        }
        .onDisappear {
            scale.stop()
        }
    }

    // MARK: Scale

    private var scaleView: some View {
        ScrollView {
            VStack(spacing: CarliSpace.s24) {
                VStack(spacing: CarliSpace.s8) {
                    Text(weightText)
                        .font(.system(size: 64, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(CarliColor.text)
                        .contentTransition(.numericText())
                        .animation(.smooth, value: weightText)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(CarliColor.text2)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, CarliSpace.s32)
                .accessibilityElement(children: .combine)

                if let saved, let metrics = latestMetrics(for: saved) {
                    CarliCard {
                        CompositionGrid(fat: metrics.fatPercent, muscle: metrics.musclePercent,
                                        water: metrics.waterPercent, bmi: metrics.bmi)
                    }
                }

                if profile?.isComplete == false {
                    CarliCard {
                        Label("Completa tu perfil en Ajustes de Salud (altura, edad y sexo) para que la grasa y el músculo sean correctos.",
                              systemImage: "person.crop.circle.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(CarliColor.text2)
                    }
                }

                if uploadFailed {
                    CarliCard {
                        HStack {
                            Text("No se ha podido guardar en carli.")
                                .font(.footnote)
                                .foregroundStyle(CarliColor.negative)
                            Spacer()
                            Button("Reintentar") { upload(nil) }
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }

                Button {
                    manual = true
                } label: {
                    Label("Escribir el peso a mano", systemImage: "keyboard")
                }
                .buttonStyle(.glass)
                .padding(.top, CarliSpace.s8)
            }
            .padding(.horizontal, CarliSpace.s16)
            .padding(.bottom, CarliSpace.s32)
        }
    }

    private var weightText: String {
        if let saved { return WeightFormat.kg(saved.kg) }
        if let live = scale.live { return WeightFormat.kg(live.kg) }
        return "– kg"
    }

    private var statusText: String {
        if saved != nil {
            return uploadFailed ? "Pesada leída" : "Guardado. La composición llega al terminar la báscula."
        }
        switch scale.phase {
        case .scanning: return "Súbete descalzo a la báscula para encenderla."
        case .connecting: return "Conectando con la báscula…"
        case .connected: return "Quieto un momento, está midiendo…"
        case .idle: return "Preparando Bluetooth…"
        case .unavailable(let reason): return reason
        }
    }

    /// The composition for a weigh-in comes with its stored copy, matched by weight and impedances.
    private func latestMetrics(for result: QNResult) -> QNMetrics? {
        result.metrics ?? scale.results.first { $0.isStored && $0.kg == result.kg && $0.impedances == result.impedances }?.metrics
    }

    private func upload(_ result: QNResult?) {
        // The weigh-in just taken arrives live; stored results are older ones the scale kept.
        if let result, !result.isStored, saved == nil { saved = result }
        let all = scale.results
        let device = scale.deviceName
        let firmware = scale.firmware
        uploads?.cancel()
        uploads = Task {
            // Results come in bursts (history, then its composition): send once they settle.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            do {
                try await HealthAPI.sync(api, all, device: device, firmware: firmware)
                uploadFailed = false
            } catch {
                uploadFailed = true
            }
        }
    }

    // MARK: Manual

    private var manualForm: some View {
        Form {
            Section {
                TextField("Peso en kg", text: $manualKg)
                    .keyboardType(.decimalPad)
                    .font(.title2.weight(.semibold))
                DatePicker("Fecha", selection: $manualDate, in: ...Date.now)
            } footer: {
                Text("Sin báscula solo se guarda el peso; la composición la calcula la báscula.")
            }
            if let error {
                Section { Text(error).foregroundStyle(CarliColor.negative) }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var parsedKg: Double? {
        let value = Double(manualKg.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        return value.flatMap { (2...399).contains($0) ? $0 : nil }
    }

    private func saveManual() async {
        guard let kg = parsedKg else { return }
        saving = true
        defer { saving = false }
        do {
            try await HealthAPI.addManual(api, kg: kg, at: manualDate)
            onSaved("Peso guardado")
            dismiss()
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar el peso.")
        }
    }
}

/// Fat, muscle, water and BMI in a 2×2 grid.
struct CompositionGrid: View {
    var fat: Double?
    var muscle: Double?
    var water: Double?
    var bmi: Double?

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: CarliSpace.s16, verticalSpacing: CarliSpace.s12) {
            GridRow {
                cell(.fat, fat)
                cell(.muscle, muscle)
            }
            GridRow {
                cell(.water, water)
                cell(.bmi, bmi)
            }
        }
    }

    private func cell(_ metric: BodyMetric, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.footnote)
                .foregroundStyle(CarliColor.text2)
            Text(value.map(metric.format) ?? "–")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(CarliColor.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
