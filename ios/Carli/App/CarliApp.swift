import SwiftUI

@main
struct CarliApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var auth = AuthModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .tint(CarliColor.primary)
                .onAppear { PushManager.shared.api = auth.api }
        }
    }
}
