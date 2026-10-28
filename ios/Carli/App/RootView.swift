import SwiftUI

/// Switches between login and the signed-in app, with the launch blink on top.
struct RootView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.scenePhase) private var scenePhase
    @State private var lock = AppLock.shared
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
                ShellView()
                    .transition(.opacity)
            }

            if lock.locked, case .signedIn = auth.state {
                LockView(lock: lock)
                    .transition(.opacity)
                    .zIndex(0.5)
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
        .animation(.easeOut(duration: 0.2), value: lock.locked)
        .preferredColorScheme(auth.user?.theme.colorScheme)
        .task { await auth.restore() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                lock.lock()
            case .active:
                Task { await lock.unlock() }
                if case .signedIn = auth.state { Task { await PushManager.shared.activate() } }
            default:
                break
            }
        }
        .onChange(of: auth.state) { previous, next in
            if case .signedIn = next, !(previous.isSignedIn) { Task { await PushManager.shared.activate() } }
        }
    }
}
