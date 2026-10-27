import SwiftUI

/// Switches between login and the signed-in app, with the launch blink on top.
struct RootView: View {
    @Environment(AuthModel.self) private var auth
    @State private var launchFinished = ProcessInfo.processInfo.arguments.contains("-skipLaunch")

    var body: some View {
        ZStack {
            switch auth.state {
            case .unknown:
                CarliColor.bg.ignoresSafeArea()
            case .signedOut(let expired):
                LoginView(expired: expired)
                    .transition(.opacity)
            case .signedIn:
                HomePlaceholderView()
                    .transition(.opacity)
            }

            if !launchFinished {
                LaunchView(ready: auth.state != .unknown) {
                    launchFinished = true
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.24), value: auth.state)
        .animation(.easeOut(duration: 0.24), value: launchFinished)
        .preferredColorScheme(auth.user?.theme.colorScheme)
        .task { await auth.restore() }
    }
}
