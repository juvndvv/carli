import Flutter
import UIKit
import UserNotifications

final class PushBridge {
  static let shared = PushBridge()

  private var channel: FlutterMethodChannel?
  private var pendingRegistrations: [FlutterResult] = []
  private var launchTap: [String: Any]?
  private var dartListening = false

  func attach(to messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "carli/push", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  func didRegister(deviceToken: Data) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    complete(with: ["token": token, "environment": Self.apsEnvironment()])
  }

  func didFailToRegister(error: Error) {
    complete(with: FlutterError(code: "registration_failed", message: error.localizedDescription, details: nil))
  }

  func opened(userInfo: [AnyHashable: Any]) {
    let tap: [String: Any] = [
      "url": userInfo["url"] as? String ?? NSNull(),
      "notification_id": userInfo["notification_id"] as? String ?? NSNull(),
    ]
    if dartListening {
      channel?.invokeMethod("opened", arguments: tap)
    } else {
      launchTap = tap
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "permission":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        let permission: String
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: permission = "granted"
        case .denied: permission = "denied"
        default: permission = "notDetermined"
        }
        DispatchQueue.main.async { result(permission) }
      }
    case "requestPermission":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    case "register":
      pendingRegistrations.append(result)
      UIApplication.shared.registerForRemoteNotifications()
    case "launchTap":
      dartListening = true
      result(launchTap)
      launchTap = nil
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func complete(with value: Any) {
    let results = pendingRegistrations
    pendingRegistrations.removeAll()
    results.forEach { $0(value) }
  }

  private static func apsEnvironment() -> String {
    guard
      let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
      let data = try? Data(contentsOf: url),
      let start = data.range(of: Data("<?xml".utf8)),
      let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
      let plist = try? PropertyListSerialization.propertyList(
        from: data.subdata(in: start.lowerBound..<end.upperBound), format: nil) as? [String: Any],
      let entitlements = plist["Entitlements"] as? [String: Any],
      let environment = entitlements["aps-environment"] as? String
    else {
      return "production"
    }
    return environment == "development" ? "sandbox" : "production"
  }
}
