import SwiftUI

@main
struct CarliApp: App {
    @State private var auth = AuthModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .tint(CarliColor.primary)
        }
    }
}
