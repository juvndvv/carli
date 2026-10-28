import LocalAuthentication
import Observation
import SwiftUI
import UIKit
import UserNotifications

/// A tap the system handed us (push or Home Screen quick action) waiting for the signed-in shell.
struct ExternalOpen: Equatable, Identifiable {
    let id = UUID()
    var url: String?
    var notificationId: String?
}

/// APNs registration and push state for Ajustes › Avisos, plus taps on delivered notifications.
@Observable
final class PushManager {
    static let shared = PushManager()

    enum Permission { case granted, denied, notDetermined }

    var permission: Permission = .notDetermined
    var token: String?
    var serverConfigured = false
    var registrationFailed = false
    var checked = false
    /// Set by a notification tap or a quick action; the shell routes it once signed in.
    var opened: ExternalOpen?

    var api: APIClient?
    private var waiting: [CheckedContinuation<String, Error>] = []

    var registered: Bool { permission == .granted && token != nil }
    var active: Bool { registered && serverConfigured }

    func refreshPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permission = switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        default: .notDetermined
        }
        checked = true
    }

    /// Asks for permission the first time, then registers this iPhone with the server.
    func activate() async {
        await refreshPermission()
        if permission == .notDetermined {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshPermission()
        }
        guard permission == .granted, let api else { return }
        do {
            let token = try await withCheckedThrowingContinuation { continuation in
                waiting.append(continuation)
                UIApplication.shared.registerForRemoteNotifications()
            }
            struct Body: Encodable { var token: String; var environment: String }
            struct Response: Decodable { var pushConfigured: Bool? }
            let response: Response = try await api.post("v1/push-devices", body: Body(token: token, environment: Self.apsEnvironment()))
            self.token = token
            serverConfigured = response.pushConfigured == true
            registrationFailed = false
        } catch {
            token = nil
            registrationFailed = true
        }
    }

    /// Unregisters this iPhone before signing out.
    func forget() async {
        guard let token, let api else { return }
        struct Body: Encodable { var token: String }
        let _: Empty? = try? await api.request("DELETE", "v1/push-devices", body: Body(token: token))
        self.token = nil
        serverConfigured = false
    }

    /// True when the test reached a push channel, not only the in-app inbox.
    func sendTest() async throws -> Bool {
        struct Response: Decodable { var channels: [String]? }
        guard let api else { return false }
        let response: Response = try await api.post("v1/notifications/test")
        return (response.channels ?? []).contains { $0 != "database" }
    }

    func didRegister(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume(returning: token) }
    }

    func didFail(_ error: Error) {
        let continuations = waiting
        waiting = []
        continuations.forEach { $0.resume(throwing: error) }
    }

    /// Reads `aps-environment` from the embedded provisioning profile: Xcode installs use the sandbox.
    nonisolated static func apsEnvironment() -> String {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data.subdata(in: start.lowerBound..<end.upperBound),
                                                                      format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let environment = entitlements["aps-environment"] as? String
        else { return "production" }
        return environment == "development" ? "sandbox" : "production"
    }
}

/// Home Screen quick actions, as in the Flutter app.
enum QuickAction: String, CaseIterable {
    case newTransaction = "new_transaction", transactions, pending

    var title: String {
        switch self {
        case .newTransaction: "Nuevo movimiento"
        case .transactions: "Movimientos"
        case .pending: "Pendientes"
        }
    }

    var symbol: String {
        switch self {
        case .newTransaction: "plus"
        case .transactions: "list.bullet"
        case .pending: "tray"
        }
    }

    var path: String {
        switch self {
        case .newTransaction: "/finanzas/movimientos/nuevo"
        case .transactions: "/finanzas/movimientos"
        case .pending: "/pendientes"
        }
    }

    static func publish() {
        UIApplication.shared.shortcutItems = allCases.map {
            UIApplicationShortcutItem(type: $0.rawValue, localizedTitle: $0.title, localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: $0.symbol))
        }
    }

    static func handle(_ item: UIApplicationShortcutItem) {
        guard let action = QuickAction(rawValue: item.type) else { return }
        PushManager.shared.opened = ExternalOpen(url: action.path)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        QuickAction.publish()
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let item = options.shortcutItem { QuickAction.handle(item) }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.didRegister(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushManager.shared.didFail(error)
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification)
        async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let url = info["url"] as? String
        let id = info["notification_id"] as? String
        await MainActor.run { PushManager.shared.opened = ExternalOpen(url: url, notificationId: id) }
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem) async -> Bool {
        QuickAction.handle(shortcutItem)
        return true
    }
}

/// Face ID lock: asks on launch and whenever the app comes back from the background.
@Observable
final class AppLock {
    static let shared = AppLock()
    private static let key = "biometric_lock_enabled"

    var enabled = UserDefaults.standard.bool(forKey: AppLock.key)
    var locked = UserDefaults.standard.bool(forKey: AppLock.key)
    var busy = false

    var label: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType == .touchID ? "Touch ID" : "Face ID"
    }

    var available: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func setEnabled(_ on: Bool) async -> Bool {
        if on, !(await authenticate("Activa el bloqueo de carli")) { return false }
        UserDefaults.standard.set(on, forKey: Self.key)
        enabled = on
        locked = false
        return true
    }

    func lock() {
        if enabled { locked = true }
    }

    func unlock() async {
        guard locked, !busy else { return }
        busy = true
        let passed = await authenticate("Desbloquea carli")
        busy = false
        locked = !passed
    }

    private func authenticate(_ reason: String) async -> Bool {
        (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}

/// Full-screen cover while the app is locked.
struct LockView: View {
    var lock: AppLock

    var body: some View {
        VStack(spacing: CarliSpace.s16) {
            Image(systemName: lock.label == "Touch ID" ? "touchid" : "faceid")
                .font(.system(size: 36))
                .foregroundStyle(CarliColor.onPrimary)
                .frame(width: 72, height: 72)
                .background(CarliColor.primary, in: .circle)
            Text("carli está bloqueada")
                .font(.title3.weight(.bold))
                .foregroundStyle(CarliColor.text)
                .accessibilityAddTraits(.isHeader)
            Text("Usa \(lock.label) para continuar.")
                .font(.subheadline)
                .foregroundStyle(CarliColor.text2)
            Button {
                Task { await lock.unlock() }
            } label: {
                if lock.busy { ProgressView() } else { Label("Desbloquear", systemImage: "faceid") }
            }
            .buttonStyle(.glassProminent)
            .tint(CarliColor.primary)
            .foregroundStyle(CarliColor.onPrimary)
            .controlSize(.large)
        }
        .padding(CarliSpace.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CarliColor.bg)
    }
}
