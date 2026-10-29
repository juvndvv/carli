import SwiftUI

/// The red "delete" action for `.swipeActions`. The app root tints everything ink (black in light,
/// white in dark), which swipe buttons pick up, so the colour has to be set here explicitly.
struct DeleteSwipeButton: View {
    private let title: String
    private let systemImage: String
    private let action: () -> Void

    init(_ title: String = "Borrar", systemImage: String = "trash", action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(role: .destructive, action: action) {
            Label(title, systemImage: systemImage)
        }
        .tint(CarliColor.dangerFill)
    }
}
