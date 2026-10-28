import SwiftUI

extension Notification.Name {
    /// Posted after a module is switched on or off, so the tab bar follows.
    static let modulesChanged = Notification.Name("carli.modulesChanged")
}

extension View {
    func settingsDestinations(api: APIClient, modules: [AppModule]?) -> some View {
        navigationDestination(for: SettingsPage.self) { page in
            switch page {
            case .profile: ProfileSettingsView()
            case .security: SecuritySettingsView(api: api)
            case .notifications: NotificationSettingsView(api: api)
            case .modules: ModuleSettingsView(api: api)
            case .appearance: AppearanceSettingsView()
            }
        }
    }
}

/// Ajustes: account, appearance, modules and signing out.
struct SettingsView: View {
    var modules: [AppModule]?

    @Environment(AuthModel.self) private var auth
    @Environment(AppRouter.self) private var router
    @State private var confirmingLogout = false

    var body: some View {
        List {
            Section("Cuenta") {
                NavigationLink(value: SettingsPage.profile) {
                    HStack(spacing: CarliSpace.s12) {
                        Avatar(name: auth.user?.name ?? "·", size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Perfil").foregroundStyle(CarliColor.text)
                            if let email = auth.user?.email {
                                Text(email).font(.footnote).foregroundStyle(CarliColor.text2)
                            }
                        }
                    }
                }
                NavigationLink(value: SettingsPage.security) { Label("Seguridad", systemImage: "lock.shield") }
                NavigationLink(value: SettingsPage.notifications) { Label("Avisos", systemImage: "bell") }
                NavigationLink(value: SettingsPage.appearance) {
                    LabeledContent {
                        Text(auth.user?.theme.label ?? ThemePreference.system.label)
                    } label: {
                        Label("Apariencia", systemImage: themeSymbol(auth.user?.theme ?? .system))
                    }
                }
            }
            Section("Módulos") {
                NavigationLink(value: SettingsPage.modules) { Label("Módulos", systemImage: "square.grid.2x2") }
                ForEach((modules ?? []).filter { $0.isOn && AppLink.moduleSettings($0.id) != nil }) { module in
                    Button {
                        if let link = AppLink.moduleSettings(module.id) { router.open(link) }
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(module.name).foregroundStyle(CarliColor.text)
                                    Text("Ajustes del módulo").font(.footnote).foregroundStyle(CarliColor.text2)
                                }
                            } icon: {
                                Image(systemName: CarliIcon.symbol(module.icon))
                            }
                            Spacer()
                            Chevron()
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            Section {
                Button("Cerrar sesión", role: .destructive) { confirmingLogout = true }
            } footer: {
                Text("carli \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .frame(maxWidth: .infinity)
                    .padding(.top, CarliSpace.s8)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await auth.refreshUser()
            NotificationCenter.default.post(name: .modulesChanged, object: nil)
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { Task { await auth.logout() } }
        } message: {
            Text("Tendrás que volver a entrar con tu email y contraseña.")
        }
    }

    private func themeSymbol(_ theme: ThemePreference) -> String {
        switch theme {
        case .light: "sun.max"
        case .dark: "moon"
        case .system: "circle.lefthalf.filled"
        }
    }
}

// MARK: Perfil

struct ProfileSettingsView: View {
    @Environment(AuthModel.self) private var auth
    @State private var name = ""
    @State private var email = ""
    @State private var loaded = false
    @State private var saving = false
    @State private var error: String?
    @State private var toast: String?

    private var dirty: Bool { name != (auth.user?.name ?? "") || email != (auth.user?.email ?? "") }

    static func isValid(name: String, email: String) -> Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.trimmingCharacters(in: .whitespaces).wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) != nil
    }

    var body: some View {
        Form {
            if let user = auth.user {
                Section {
                    HStack(spacing: CarliSpace.s12) {
                        Avatar(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "?" : name, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name).font(.headline)
                            Text(user.email).font(.footnote).foregroundStyle(CarliColor.text3)
                        }
                    }
                }
                Section {
                    TextField("Nombre", text: $name)
                        .textContentType(.name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    if let error { Text(error).foregroundStyle(CarliColor.negative) }
                }
            } else {
                Text("No se ha podido cargar tu perfil. Comprueba la conexión.").foregroundStyle(CarliColor.text2)
            }
        }
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Perfil")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar", systemImage: "checkmark") { Task { await save() } }
                    .disabled(!dirty || saving)
            }
        }
        .onAppear {
            guard !loaded, let user = auth.user else { return }
            name = user.name
            email = user.email
            loaded = true
        }
        .onChange(of: name) { error = nil }
        .onChange(of: email) { error = nil }
        .carliToast($toast)
    }

    private func save() async {
        let name = name.trimmingCharacters(in: .whitespaces)
        let email = email.trimmingCharacters(in: .whitespaces)
        guard Self.isValid(name: name, email: email) else {
            error = "Revisa el nombre y el email."
            return
        }
        saving = true
        defer { saving = false }
        do {
            let envelope: DataEnvelope<CurrentUser> = try await auth.api.patch("v1/me", body: ["name": name, "email": email])
            auth.updateUser(envelope.data)
            self.name = envelope.data.name
            self.email = envelope.data.email
            toast = "Perfil actualizado"
        } catch {
            self.error = error.apiMessage(fallback: "No se ha podido guardar el perfil.")
        }
    }
}

// MARK: Apariencia

struct AppearanceSettingsView: View {
    @Environment(AuthModel.self) private var auth

    var body: some View {
        Form {
            Section {
                Picker("Tema", selection: Binding(get: { auth.user?.theme ?? .system }, set: select)) {
                    ForEach([ThemePreference.light, .dark, .system], id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Tema")
            } footer: {
                Text("«Sistema» sigue el modo claro u oscuro de tu dispositivo.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Apariencia")
    }

    private func select(_ theme: ThemePreference) {
        guard var user = auth.user else { return }
        user.preferences = CurrentUser.Preferences(theme: theme)
        auth.updateUser(user)
        Task { let _: Empty? = try? await auth.api.patch("v1/me/preferences", body: ["theme": theme.rawValue]) }
    }
}

// MARK: Módulos

struct ModuleSettingsView: View {
    let api: APIClient

    @Environment(AppRouter.self) private var router
    @State private var modules: [AppModule]?
    @State private var failed = false
    @State private var pending: String?
    @State private var toast: String?

    var body: some View {
        List {
            Section {
            } footer: {
                Text("Un módulo desactivado desaparece de la navegación. Tus datos se conservan.")
            }
            if let modules {
                let available = modules.filter { !$0.comingSoon }
                let upcoming = modules.filter(\.comingSoon)
                let withSettings = available.filter { $0.enabled == true && AppLink.moduleSettings($0.id) != nil }
                if !available.isEmpty {
                    Section("Disponibles") {
                        ForEach(available) { module in
                            Toggle(isOn: Binding(get: { module.enabled == true }, set: { on in Task { await toggle(module, on) } })) {
                                moduleLabel(module)
                            }
                            .disabled(pending == module.id)
                            .accessibilityLabel("Activar \(module.name)")
                        }
                    }
                }
                if !withSettings.isEmpty {
                    Section("Ajustes de módulos") {
                        ForEach(withSettings) { module in
                            Button {
                                if let link = AppLink.moduleSettings(module.id) { router.open(link) }
                            } label: {
                                HStack {
                                    Label("Ajustes de \(module.name)", systemImage: "gearshape").foregroundStyle(CarliColor.text)
                                    Spacer()
                                    Chevron()
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !upcoming.isEmpty {
                    Section("Próximamente") {
                        ForEach(upcoming) { module in
                            HStack {
                                moduleLabel(module)
                                Spacer()
                                Text("Próximamente")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(CarliColor.surface2, in: .capsule)
                                    .foregroundStyle(CarliColor.text2)
                            }
                        }
                    }
                }
            } else if failed {
                ContentUnavailableView {
                    Label("No se han podido cargar los módulos", systemImage: "exclamationmark.circle")
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
        .navigationTitle("Módulos")
        .refreshable { await load() }
        .task { await load() }
        .carliToast($toast)
    }

    private func moduleLabel(_ module: AppModule) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(module.name).foregroundStyle(CarliColor.text)
                if let description = module.description {
                    Text(description).font(.footnote).foregroundStyle(CarliColor.text2)
                }
            }
        } icon: {
            Image(systemName: CarliIcon.symbol(module.icon))
        }
    }

    private func load() async {
        do {
            let envelope: DataEnvelope<[AppModule]> = try await api.get("v1/modules")
            modules = envelope.data
            failed = false
        } catch {
            if modules == nil { failed = true }
        }
    }

    private func toggle(_ module: AppModule, _ on: Bool) async {
        let previous = modules
        modules = modules?.map { var copy = $0; if copy.id == module.id { copy.enabled = on }; return copy }
        pending = module.id
        defer { pending = nil }
        do {
            let _: Empty = try await api.patch("v1/modules/\(module.id)", body: ["enabled": on])
            NotificationCenter.default.post(name: .modulesChanged, object: nil)
        } catch {
            modules = previous
            toast = "No se ha podido cambiar el módulo"
        }
    }
}
