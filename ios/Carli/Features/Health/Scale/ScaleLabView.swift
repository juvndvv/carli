import SwiftUI

/// Hidden test screen (debug builds only) to try the scale protocol on a real iPhone:
/// connects, sends the profile, shows the live weight and every frame, and copies the log.
struct ScaleLabView: View {
    @AppStorage("scaleLab.height") private var height = 175
    @AppStorage("scaleLab.age") private var age = 30
    @AppStorage("scaleLab.female") private var female = false
    @State private var scale = ScaleClient(profile: QNProfile(heightCm: 175, age: 30, sex: .male))
    @State private var toast: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Estado", value: scale.phase.label)
                if let name = scale.deviceName {
                    LabeledContent("Báscula", value: [name, scale.manufacturer, scale.firmware].compactMap { $0 }.joined(separator: " · "))
                }
                HStack {
                    if scale.phase == .idle || isUnavailable {
                        Button("Buscar báscula") { applyProfile(); scale.start() }
                    } else {
                        Button("Detener", role: .destructive) { scale.stop() }
                    }
                    Spacer()
                    Button("Histórico") { scale.requestHistory() }
                        .disabled(scale.phase != .connected)
                }
                .buttonStyle(.borderless)
            } footer: {
                Text("Súbete descalzo y quieto hasta que termine de medir. La app Fit Profile debe estar cerrada.")
            }

            Section("Perfil enviado a la báscula") {
                Stepper("Altura: \(height) cm", value: $height, in: 60...220)
                Stepper("Edad: \(age) años", value: $age, in: 6...80)
                Picker("Sexo", selection: $female) {
                    Text("Hombre").tag(false)
                    Text("Mujer").tag(true)
                }
            }

            if let live = scale.live {
                Section("En vivo") {
                    Text(String(format: "%.2f kg", live.kg))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    LabeledContent("Estado", value: live.isStable ? "estable (\(live.state))" : "midiendo (\(live.state))")
                    LabeledContent("r1 / r2", value: "\(live.r1) / \(live.r2)")
                }
            }

            if !scale.readings.isEmpty {
                Section("Pesadas") {
                    ForEach(scale.readings) { reading in
                        VStack(alignment: .leading, spacing: CarliSpace.s4) {
                            Text(String(format: "%.2f kg · %.1f Ω", reading.kg, reading.impedanceOhm))
                                .font(.headline).monospacedDigit()
                            Text("\(reading.date.formatted(date: .abbreviated, time: .shortened)) · \(reading.source.rawValue) · r2 \(reading.r2)")
                                .font(.footnote).foregroundStyle(CarliColor.text2)
                        }
                    }
                }
            }

            Section {
                ForEach(scale.log.reversed()) { line in
                    Text("\(line.kind.rawValue) \(line.text)")
                        .font(.caption.monospaced())
                        .foregroundStyle(line.kind == .note ? CarliColor.text2 : CarliColor.text)
                        .textSelection(.enabled)
                }
            } header: {
                HStack {
                    Text("Registro")
                    Spacer()
                    Button("Borrar") { scale.clearLog() }
                    Button("Copiar") {
                        UIPasteboard.general.string = scale.transcript
                        toast = "Registro copiado"
                    }
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Báscula (pruebas)")
        .navigationBarTitleDisplayMode(.inline)
        .carliToast($toast)
        .onDisappear { scale.stop() }
    }

    private var isUnavailable: Bool {
        if case .unavailable = scale.phase { true } else { false }
    }

    private func applyProfile() {
        scale.profile = QNProfile(heightCm: height, age: age, sex: female ? .female : .male)
    }
}
