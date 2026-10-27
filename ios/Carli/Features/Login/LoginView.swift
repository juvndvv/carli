import SwiftUI

/// Email + password, then the 2FA code (or a recovery code) when the account asks for it.
struct LoginView: View {
    var expired = false

    private enum Step { case credentials, twoFactor }
    private enum Field: Hashable { case email, password, code }

    @Environment(AuthModel.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var step = Step.credentials
    @State private var useRecovery = false
    @State private var busy = false
    @State private var error: String?
    @State private var pending: Credentials?
    @FocusState private var focus: Field?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CarliSpace.s32) {
                brand
                switch step {
                case .credentials: credentialsForm
                case .twoFactor: twoFactorForm
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(CarliColor.negative)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                actions
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, CarliSpace.s24)
            .padding(.top, 96)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .background(CarliColor.bg.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: step)
        .animation(.smooth(duration: 0.2), value: error)
        .onAppear {
            if expired { error = "Tu sesión ha caducado. Vuelve a entrar." }
        }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: CarliSpace.s12) {
            CarliLogo(size: 64)
                .padding(.leading, -8)
            VStack(alignment: .leading, spacing: 2) {
                Text("carli")
                    .carliWordmark(34)
                    .foregroundStyle(CarliColor.text)
                Text("Tu asistente personal")
                    .font(.subheadline)
                    .foregroundStyle(CarliColor.text2)
            }
        }
    }

    private var credentialsForm: some View {
        FieldGroup {
            TextField("Email", text: $email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focus, equals: .email)
                .onSubmit { focus = .password }
            Divider()
            SecureField("Contraseña", text: $password)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focus, equals: .password)
                .onSubmit(submit)
        }
        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
    }

    private var twoFactorForm: some View {
        VStack(alignment: .leading, spacing: CarliSpace.s16) {
            VStack(alignment: .leading, spacing: CarliSpace.s4) {
                Text("Verificación en dos pasos")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CarliColor.text)
                Text(useRecovery
                     ? "Introduce uno de tus códigos de recuperación."
                     : "Introduce el código de 6 dígitos de tu app de autenticación.")
                    .font(.subheadline)
                    .foregroundStyle(CarliColor.text2)
            }
            FieldGroup {
                TextField(useRecovery ? "Código de recuperación" : "Código", text: $code)
                    .textContentType(useRecovery ? nil : .oneTimeCode)
                    .keyboardType(useRecovery ? .asciiCapable : .numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(useRecovery ? .body : .title3.monospacedDigit())
                    .submitLabel(.go)
                    .focused($focus, equals: .code)
                    .onSubmit(submit)
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
        .onAppear { focus = .code }
    }

    private var actions: some View {
        VStack(spacing: CarliSpace.s12) {
            Button(action: submit) {
                ZStack {
                    Text(step == .credentials ? "Entrar" : "Verificar")
                        .opacity(busy ? 0 : 1)
                    if busy { ProgressView().tint(CarliColor.onPrimary) }
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(CarliColor.primary)
            .controlSize(.extraLarge)
            .disabled(busy)

            if step == .twoFactor {
                HStack {
                    Button("Volver", action: backToCredentials)
                    Spacer()
                    Button(useRecovery ? "Usar código de la app" : "Usar código de recuperación", action: toggleRecovery)
                }
                .font(.subheadline.weight(.medium))
                .buttonStyle(.glass)
                .transition(.opacity)
            }
        }
    }

    private func submit() {
        switch step {
        case .credentials:
            let email = email.trimmingCharacters(in: .whitespaces)
            guard !email.isEmpty, !password.isEmpty else {
                error = "Introduce tu email y tu contraseña."
                return
            }
            run(Credentials(email: email, password: password), fallback: "Email o contraseña incorrectos.")
        case .twoFactor:
            let code = code.trimmingCharacters(in: .whitespaces)
            guard !code.isEmpty, var credentials = pending else {
                error = "Introduce el código."
                return
            }
            if useRecovery { credentials.recoveryCode = code } else { credentials.code = code }
            run(credentials, fallback: "El código no es válido.")
        }
    }

    private func run(_ credentials: Credentials, fallback: String) {
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do {
                if try await auth.login(credentials) == .twoFactorRequired {
                    pending = credentials
                    step = .twoFactor
                }
            } catch {
                self.error = error.apiMessage(fallback: fallback)
            }
        }
    }

    private func backToCredentials() {
        step = .credentials
        pending = nil
        code = ""
        error = nil
    }

    private func toggleRecovery() {
        useRecovery.toggle()
        code = ""
        error = nil
    }
}

/// Inset-grouped container for text fields, matching the system list style.
private struct FieldGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.vertical, 14)
        }
        .padding(.horizontal, CarliSpace.s16)
        .background(CarliColor.surface, in: .rect(cornerRadius: CarliRadius.card, style: .continuous))
    }
}

#Preview {
    LoginView()
        .environment(AuthModel())
}
