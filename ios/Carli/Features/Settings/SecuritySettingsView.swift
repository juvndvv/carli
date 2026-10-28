import CoreImage.CIFilterBuiltins
import SwiftUI

/// Ajustes › Seguridad: password, two-step verification, Face ID lock and active sessions.
struct SecuritySettingsView: View {
    let api: APIClient

    @Environment(AuthModel.self) private var auth
    @State private var lock = AppLock.shared
    @State private var tokens: [AppToken]?
    @State private var webSessions: [WebSession] = []
    @State private var sessionsFailed = false
    @State private var toast: String?
    @State private var prompt: PasswordPrompt?
    @State private var revoking: Revocation?
    @State private var confirmingDisable = false
    @State private var step: TwoFactorStep = .idle
    @State private var code = ""
    @State private var codeError: String?
    @State private var busy = false

    @State private var current = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var passwordError: String?
    @State private var savingPassword = false

    enum TwoFactorStep {
        case idle
        case setup(TwoFactorSetup, password: String)
        case codes([String])
    }

    struct Revocation: Identifiable {
        var id: String
        var name: String
        var path: String
    }

    static func passwordProblem(current: String, password: String, confirmation: String) -> String? {
        if current.isEmpty || password.count < 8 || confirmation.isEmpty {
            return "Rellena los tres campos; la nueva contraseña debe tener al menos 8 caracteres."
        }
        return password == confirmation ? nil : "Las contraseñas nuevas no coinciden."
    }

    var body: some View {
        List {
            passwordSection
            twoFactorSection
            lockSection
            sessionsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CarliColor.bg)
        .navigationTitle("Seguridad")
        .refreshable {
            await auth.refreshUser()
            await loadSessions()
        }
        .task { await loadSessions() }
        .sheet(item: $prompt) { PasswordPromptSheet(prompt: $0) }
        .confirmationDialog("Cerrar la sesión", isPresented: Binding(get: { revoking != nil }, set: { if !$0 { revoking = nil } }),
                            titleVisibility: .visible, presenting: revoking) { revocation in
            Button("Cerrar sesión", role: .destructive) { Task { await revoke(revocation) } }
        } message: { revocation in
            Text("Se cerrará la sesión de «\(revocation.name)».")
        }
        .confirmationDialog("Desactivar la verificación en dos pasos", isPresented: $confirmingDisable, titleVisibility: .visible) {
            Button("Desactivar", role: .destructive) { askToDisable() }
        } message: {
            Text("Tu cuenta quedará protegida solo con la contraseña.")
        }
        .carliToast($toast)
    }

    // MARK: Contraseña

    private var passwordSection: some View {
        Section {
            SecureField("Contraseña actual", text: $current).textContentType(.password)
            SecureField("Nueva contraseña", text: $password).textContentType(.newPassword)
            SecureField("Repite la nueva contraseña", text: $confirmation).textContentType(.newPassword)
                .onSubmit { Task { await changePassword() } }
            Button {
                Task { await changePassword() }
            } label: {
                if savingPassword { ProgressView() } else { Text("Cambiar contraseña") }
            }
            .disabled(savingPassword)
        } header: {
            Text("Contraseña")
        } footer: {
            if let passwordError {
                Text(passwordError).foregroundStyle(CarliColor.negative)
            } else {
                Text("Mínimo 8 caracteres.")
            }
        }
        .onChange(of: current) { passwordError = nil }
        .onChange(of: password) { passwordError = nil }
        .onChange(of: confirmation) { passwordError = nil }
    }

    private func changePassword() async {
        if let problem = Self.passwordProblem(current: current, password: password, confirmation: confirmation) {
            passwordError = problem
            return
        }
        savingPassword = true
        defer { savingPassword = false }
        do {
            let _: Empty = try await api.put("v1/me/password", body: ["current_password": current, "password": password,
                                                                       "password_confirmation": confirmation])
            current = ""
            password = ""
            confirmation = ""
            toast = "Contraseña actualizada"
        } catch {
            passwordError = error.apiMessage(fallback: "No se ha podido cambiar la contraseña.")
        }
    }

    // MARK: Verificación en dos pasos

    private var twoFactorSection: some View {
        Section {
            HStack(alignment: .top) {
                Text("Protege tu cuenta con un código de una app de autenticación (TOTP) al iniciar sesión.")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                Spacer()
                statusBadge
            }
            switch step {
            case .setup(let setup, let password): setupView(setup, password: password)
            case .codes(let codes): codesView(codes)
            case .idle: idleActions
            }
        } header: {
            Text("Verificación en dos pasos")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = if auth.user?.twoFactorEnabled == true {
            ("Activa", CarliColor.positive)
        } else if auth.user?.twoFactorPending == true {
            ("Pendiente", CarliColor.warning)
        } else {
            ("Inactiva", CarliColor.text2)
        }
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.14), in: .capsule)
    }

    @ViewBuilder
    private var idleActions: some View {
        if let user = auth.user {
            if user.twoFactorEnabled == true {
                Button("Códigos de recuperación", systemImage: "key") { askForCodes() }
                Button("Desactivar", role: .destructive) { confirmingDisable = true }
            } else if user.twoFactorPending == true {
                Text("Empezaste a activarla pero falta confirmar el código. Continúa para volver a ver el código QR.")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                Button("Continuar la activación", systemImage: "checkmark.shield") { startSetup() }
                Button("Cancelar la activación", role: .destructive) { abandonPending() }
            } else {
                Button("Activar", systemImage: "checkmark.shield") { startSetup() }
            }
        } else {
            Text("No se ha podido cargar el estado de tu cuenta. Comprueba la conexión.")
                .font(.footnote)
                .foregroundStyle(CarliColor.text3)
        }
    }

    @ViewBuilder
    private func setupView(_ setup: TwoFactorSetup, password: String) -> some View {
        Text("Escanea este código con tu app de autenticación y escribe el código que te muestre.")
            .font(.footnote)
        if let image = Self.qrImage(setup.qrCodeUrl) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 192, height: 192)
                .padding(CarliSpace.s8)
                .background(.white, in: .rect(cornerRadius: CarliRadius.control))
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Código QR para tu app de autenticación")
        }
        if let secret = setup.secretKey {
            HStack {
                Text("Clave manual: ").font(.footnote).foregroundStyle(CarliColor.text3)
                    + Text(secret).font(.footnote.monospaced())
                Spacer()
                Button("Copiar clave", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = secret
                    toast = "Clave copiada"
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
            }
        }
        TextField("Código de 6 dígitos", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .onChange(of: code) { _, value in
                let digits = String(value.filter(\.isNumber).prefix(6))
                if digits != value { code = digits }
                codeError = nil
            }
        if let codeError { Text(codeError).font(.footnote).foregroundStyle(CarliColor.negative) }
        Button {
            Task { await confirmSetup() }
        } label: {
            if busy { ProgressView() } else { Text("Confirmar") }
        }
        .disabled(busy)
        Button("Cancelar", role: .cancel) { Task { await cancelSetup(password: password) } }
            .disabled(busy)
    }

    @ViewBuilder
    private func codesView(_ codes: [String]) -> some View {
        Text("Guarda estos códigos de recuperación en un lugar seguro. Cada uno sirve una sola vez.")
            .font(.footnote)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: CarliSpace.s4) {
            ForEach(codes, id: \.self) { Text($0).font(.footnote.monospaced()).textSelection(.enabled) }
        }
        .padding(.vertical, CarliSpace.s4)
        Button("Copiar", systemImage: "doc.on.doc") {
            UIPasteboard.general.string = codes.joined(separator: "\n")
            toast = "Códigos copiados"
        }
        ShareLink(item: codes.joined(separator: "\n"), subject: Text("Códigos de recuperación de carli")) {
            Label("Compartir", systemImage: "square.and.arrow.up")
        }
        Button("Regenerar", systemImage: "arrow.clockwise") { askToRegenerate() }
        Button("Hecho") { step = .idle }
    }

    static func qrImage(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static let confirmTitle = "Confirma tu contraseña"
    private static let confirmMessage = "Por seguridad, vuelve a introducir tu contraseña para continuar."

    private func startSetup() {
        prompt = PasswordPrompt(title: Self.confirmTitle, message: Self.confirmMessage, confirm: "Confirmar") { password in
            let setup: TwoFactorSetup = try await api.post("v1/me/two-factor", body: ["password": password])
            code = ""
            codeError = nil
            step = .setup(setup, password: password)
            await auth.refreshUser()
        }
    }

    private func confirmSetup() async {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            codeError = "Introduce el código."
            return
        }
        busy = true
        defer { busy = false }
        do {
            let response: RecoveryCodes = try await api.post("v1/me/two-factor/confirm", body: ["code": trimmed])
            code = ""
            step = .codes(response.recoveryCodes)
            toast = "Verificación en dos pasos activada"
            await auth.refreshUser()
        } catch {
            codeError = error.apiMessage(fallback: "El código no es válido.")
        }
    }

    private func cancelSetup(password: String) async {
        busy = true
        step = .idle
        let _: Empty? = try? await api.request("DELETE", "v1/me/two-factor", body: ["password": password])
        busy = false
        await auth.refreshUser()
    }

    private func abandonPending() {
        prompt = PasswordPrompt(title: "Cancelar la activación",
                                message: "Se descartará el código QR que generaste. Confirma con tu contraseña.",
                                confirm: "Cancelar activación", destructive: true) { password in
            let _: Empty = try await api.request("DELETE", "v1/me/two-factor", body: ["password": password])
            toast = "Activación cancelada"
            await auth.refreshUser()
        }
    }

    private func askForCodes() {
        prompt = PasswordPrompt(title: Self.confirmTitle, message: Self.confirmMessage, confirm: "Confirmar") { password in
            let response: RecoveryCodes = try await api.post("v1/me/two-factor/recovery-codes", body: ["password": password])
            step = .codes(response.recoveryCodes)
        }
    }

    private func askToRegenerate() {
        prompt = PasswordPrompt(title: "Regenerar los códigos",
                                message: "Los códigos actuales dejarán de funcionar. Confirma con tu contraseña.",
                                confirm: "Regenerar") { password in
            let response: RecoveryCodes = try await api.post("v1/me/two-factor/recovery-codes/regenerate", body: ["password": password])
            step = .codes(response.recoveryCodes)
            toast = "Códigos regenerados"
        }
    }

    private func askToDisable() {
        prompt = PasswordPrompt(title: Self.confirmTitle, message: Self.confirmMessage, confirm: "Desactivar", destructive: true) { password in
            let _: Empty = try await api.request("DELETE", "v1/me/two-factor", body: ["password": password])
            step = .idle
            toast = "Verificación en dos pasos desactivada"
            await auth.refreshUser()
        }
    }

    // MARK: Bloqueo

    private var lockSection: some View {
        Section("Bloqueo de la app") {
            let usable = lock.available || lock.enabled
            if usable {
                Toggle(isOn: Binding(get: { lock.enabled }, set: { on in
                    Task {
                        if await lock.setEnabled(on) { toast = on ? "Bloqueo activado" : "Bloqueo desactivado" }
                    }
                })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bloqueo con \(lock.label)")
                        Text("Pide \(lock.label) al abrir la app y al volver a ella.").font(.footnote).foregroundStyle(CarliColor.text2)
                    }
                }
                .disabled(lock.busy)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bloqueo con \(lock.label)")
                    Text("Configura Face ID o Touch ID en los Ajustes del iPhone para poder bloquear carli.")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                }
            }
        }
    }

    // MARK: Sesiones

    private var sessionsSection: some View {
        Section {
            if let tokens {
                if tokens.isEmpty && webSessions.isEmpty {
                    Text("No hay información de sesiones.").font(.footnote).foregroundStyle(CarliColor.text3)
                }
                ForEach(tokens) { token in
                    sessionRow(name: token.name, subtitle: token.subtitle, symbol: "iphone", current: token.isCurrent == true) {
                        revoking = Revocation(id: "token-\(token.id)", name: token.name, path: "v1/me/tokens/\(token.id)")
                    }
                }
                ForEach(webSessions) { session in
                    sessionRow(name: session.name, subtitle: session.subtitle, symbol: session.isMobile == true ? "iphone" : "laptopcomputer",
                               current: session.isCurrent == true) {
                        revoking = Revocation(id: "session-\(session.id)", name: session.name, path: "v1/me/sessions/\(session.id)")
                    }
                }
            } else if sessionsFailed {
                Button("No se han podido cargar las sesiones. Reintentar") { Task { await loadSessions() } }
            } else {
                ProgressView().frame(maxWidth: .infinity)
            }
            Button("Cerrar las demás", role: .destructive) { askToLogoutOthers() }
        } header: {
            Text("Sesiones activas")
        } footer: {
            Text("Cierra la sesión en el resto de dispositivos y navegadores.")
        }
    }

    private func sessionRow(name: String, subtitle: String, symbol: String, current: Bool, revoke: @escaping () -> Void) -> some View {
        HStack(spacing: CarliSpace.s12) {
            Image(systemName: symbol).foregroundStyle(CarliColor.text2).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                Text(subtitle).font(.footnote).foregroundStyle(CarliColor.text2)
            }
            Spacer()
            if current {
                Text("Este dispositivo")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(CarliColor.surface2, in: .capsule)
            } else {
                Button("Cerrar la sesión de \(name)", systemImage: "rectangle.portrait.and.arrow.right", action: revoke)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(CarliColor.text2)
            }
        }
    }

    private func loadSessions() async {
        do {
            let tokenList: DataEnvelope<[AppToken]> = try await api.get("v1/me/tokens")
            let sessionList: DataEnvelope<[WebSession]>? = try? await api.get("v1/me/sessions")
            tokens = tokenList.data
            webSessions = sessionList?.data ?? []
            sessionsFailed = false
        } catch {
            if tokens == nil { sessionsFailed = true }
        }
    }

    private func revoke(_ revocation: Revocation) async {
        do {
            try await api.delete(revocation.path)
            toast = "Sesión cerrada"
        } catch {
            toast = error.apiMessage(fallback: "No se ha podido cerrar la sesión.")
        }
        await loadSessions()
    }

    private func askToLogoutOthers() {
        prompt = PasswordPrompt(title: "Cerrar las demás sesiones",
                                message: "Se cerrará la sesión en todos tus otros dispositivos. Confirma con tu contraseña.",
                                confirm: "Cerrar sesiones", destructive: true) { password in
            let _: Empty = try await api.post("v1/me/tokens/logout-others", body: ["password": password])
            toast = "Sesiones cerradas en los demás dispositivos"
            await loadSessions()
        }
    }
}

/// A password confirmation in front of a sensitive action; the sheet stays open on errors.
struct PasswordPrompt: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var confirm: String
    var destructive = false
    var action: (String) async throws -> Void
}

struct PasswordPromptSheet: View {
    var prompt: PasswordPrompt

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Contraseña", text: $password)
                        .textContentType(.password)
                        .focused($focused)
                        .onSubmit { Task { await submit() } }
                } header: {
                    Text(prompt.message).textCase(nil)
                } footer: {
                    if let error { Text(error).foregroundStyle(CarliColor.negative) }
                }
            }
            .navigationTitle(prompt.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }.disabled(busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button(prompt.confirm, role: prompt.destructive ? .destructive : nil) { Task { await submit() } }
                            .disabled(password.isEmpty)
                    }
                }
            }
            .onChange(of: password) { error = nil }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }

    private func submit() async {
        guard !password.isEmpty, !busy else { return }
        busy = true
        do {
            try await prompt.action(password)
            dismiss()
        } catch {
            busy = false
            self.error = error.apiMessage(fallback: "Algo ha fallado. Inténtalo de nuevo.")
        }
    }
}
