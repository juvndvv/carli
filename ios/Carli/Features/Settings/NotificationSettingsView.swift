import SwiftUI

/// Ajustes › Avisos: push on this iPhone plus the push / in-app switch for each notification type.
struct NotificationSettingsView: View {
    let api: APIClient

    @State private var push = PushManager.shared
    @State private var groups: [NotificationPreferenceGroup]?
    @State private var failed = false
    @State private var toast: String?

    var body: some View {
        List {
            Section("En este iPhone") { pushCard }
            if let groups {
                if groups.allSatisfy({ $0.types.isEmpty }) {
                    ContentUnavailableView("No hay tipos de aviso configurables", systemImage: "bell.slash",
                                           description: Text("Cuando actives módulos con avisos aparecerán aquí."))
                } else {
                    ForEach(groups.filter { !$0.types.isEmpty }) { group in
                        Section {
                            ForEach(group.types) { preference in row(group, preference) }
                        } header: {
                            Text(group.name ?? group.module)
                        }
                    }
                    Section {
                    } footer: {
                        Text("Marca dónde quieres cada aviso. Push llega a este iPhone. El resumen de pendientes sale a las 20:00 si tienes algo por revisar.")
                    }
                }
            } else if failed {
                ContentUnavailableView {
                    Label("No se han podido cargar los avisos", systemImage: "exclamationmark.circle")
                } actions: {
                    Button("Reintentar") { Task { await load() } }.buttonStyle(.glass)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Avisos")
        .refreshable {
            await push.activate()
            await load()
        }
        .task {
            await push.refreshPermission()
            await load()
        }
        .carliToast($toast)
    }

    @ViewBuilder
    private var pushCard: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notificaciones push")
                Text(pushSubtitle).font(.footnote).foregroundStyle(CarliColor.text2)
            }
        } icon: {
            Image(systemName: push.permission == .denied ? "bell.slash" : "bell")
        }
        if push.permission == .denied {
            Label("Las notificaciones están desactivadas. Actívalas en Ajustes de iOS > carli > Notificaciones.", systemImage: "bell.slash")
                .font(.footnote)
                .foregroundStyle(CarliColor.text)
                .listRowBackground(CarliColor.warning.opacity(0.14))
            Button("Abrir Ajustes de iOS") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        } else if push.permission == .notDetermined || push.registrationFailed {
            Button(push.registrationFailed ? "Reintentar" : "Activar notificaciones", systemImage: "bell") {
                Task {
                    await push.activate()
                    if push.registrationFailed { toast = "No se han podido activar las notificaciones" }
                }
            }
        } else if push.registered {
            Button("Probar aviso", systemImage: "paperplane") {
                Task {
                    do {
                        toast = try await push.sendTest() ? "Aviso de prueba enviado" : "El aviso de prueba solo ha llegado a la bandeja"
                    } catch {
                        toast = "No se ha podido enviar el aviso de prueba"
                    }
                }
            }
        }
    }

    private var pushSubtitle: String {
        if !push.checked { return "Comprobando…" }
        switch push.permission {
        case .denied: return "Desactivadas en iOS"
        case .notDetermined: return "Aún no las has permitido"
        case .granted:
            if push.registrationFailed { return "No se ha podido registrar este iPhone" }
            if push.active { return "Activadas en este iPhone" }
            if push.registered { return "El servidor aún no tiene el envío push configurado" }
            return "Registrando este iPhone…"
        }
    }

    private func row(_ group: NotificationPreferenceGroup, _ preference: NotificationPreference) -> some View {
        VStack(alignment: .leading, spacing: CarliSpace.s8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preference.title).font(.body.weight(.medium))
                if let detail = preference.detail {
                    Text(detail).font(.footnote).foregroundStyle(CarliColor.text2)
                }
            }
            HStack(spacing: CarliSpace.s8) {
                Toggle("Push", systemImage: "iphone", isOn: binding(group, preference, push: true))
                    .accessibilityLabel("Push: \(preference.title)")
                Toggle("En la app", systemImage: "bell.fill", isOn: binding(group, preference, push: false))
                    .accessibilityLabel("En la app: \(preference.title)")
            }
            .toggleStyle(CapsuleToggleStyle())
        }
        .padding(.vertical, 2)
    }

    private func binding(_ group: NotificationPreferenceGroup, _ preference: NotificationPreference, push isPush: Bool) -> Binding<Bool> {
        Binding(get: { isPush ? preference.push : preference.inApp }, set: { value in
            Task { await toggle(group, preference, push: isPush, value: value) }
        })
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<[NotificationPreferenceGroup]> = try await api.get("v1/notification-preferences")
            groups = envelope.data
            failed = false
        } catch {
            if groups == nil { failed = true }
        }
    }

    private func toggle(_ group: NotificationPreferenceGroup, _ preference: NotificationPreference, push isPush: Bool, value: Bool) async {
        let previous = groups
        var updated = preference
        if isPush { updated.push = value } else { updated.inApp = value }
        groups = groups?.map { current in
            guard current.module == group.module else { return current }
            var copy = current
            copy.types = copy.types.map { $0.type == preference.type ? updated : $0 }
            return copy
        }
        struct Body: Encodable {
            struct Entry: Encodable { var module: String; var type: String; var push: Bool; var inApp: Bool }
            var preferences: [Entry]
        }
        do {
            let saved: DataEnvelope<[NotificationPreferenceGroup]> = try await api.put(
                "v1/notification-preferences",
                body: Body(preferences: [.init(module: group.module, type: updated.type, push: updated.push, inApp: updated.inApp)]))
            groups = saved.data
        } catch {
            groups = previous
            toast = "No se han podido guardar los ajustes de avisos"
        }
    }
}

/// On: filled ink capsule with a light label and a check. Off: outlined, muted.
struct CapsuleToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: configuration.isOn ? "checkmark" : "minus")
                    .font(.caption2.weight(.bold))
                configuration.label.labelStyle(.titleOnly)
            }
            .font(.footnote.weight(.medium))
            .padding(.horizontal, CarliSpace.s12)
            .padding(.vertical, 6)
            .foregroundStyle(configuration.isOn ? CarliColor.onPrimary : CarliColor.text2)
            .background(configuration.isOn ? CarliColor.primary : Color.clear, in: .capsule)
            .overlay(Capsule().strokeBorder(configuration.isOn ? Color.clear : CarliColor.text3.opacity(0.5)))
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Activado" : "Desactivado")
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
