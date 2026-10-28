import SwiftUI

/// Stand-in for screens not migrated from Flutter yet.
struct PendingMigrationView: View {
    var title: String
    var symbol = "hammer"

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text("Esta pantalla todavía no está migrada a la app nativa.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CarliColor.bg)
        .navigationTitle(title)
    }
}
