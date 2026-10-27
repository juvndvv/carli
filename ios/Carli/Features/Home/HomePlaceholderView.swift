import SwiftUI

/// Temporary landing after login until the Inicio screen is migrated.
struct HomePlaceholderView: View {
    @Environment(AuthModel.self) private var auth

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Hola, \(auth.user?.firstName ?? "")", systemImage: "face.smiling")
            } description: {
                Text("Has entrado en carli. Inicio llega en la siguiente pantalla.")
            } actions: {
                Button("Cerrar sesión", role: .destructive) {
                    Task { await auth.logout() }
                }
                .buttonStyle(.glass)
            }
            .background(CarliColor.bg)
        }
    }
}
