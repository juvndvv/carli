import SwiftUI

extension View {
    /// Shows `message` in a glass capsule above the tab bar for a few seconds.
    func carliToast(_ message: Binding<String?>) -> some View {
        overlay(alignment: .bottom) {
            if let text = message.wrappedValue {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(CarliColor.text)
                    .padding(.horizontal, CarliSpace.s20)
                    .padding(.vertical, CarliSpace.s12)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: text) {
                        try? await Task.sleep(for: .seconds(3))
                        message.wrappedValue = nil
                    }
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.smooth, value: message.wrappedValue)
    }
}

/// Glass capsule with a message and "Deshacer", shown after a delete.
struct UndoBar: View {
    var text: String
    var undo: () -> Void

    var body: some View {
        HStack(spacing: CarliSpace.s16) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CarliColor.text)
            Button("Deshacer", action: undo)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CarliColor.brandInk)
        }
        .padding(.horizontal, CarliSpace.s20)
        .padding(.vertical, CarliSpace.s12)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, 96)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// A pending "Deshacer" offer: shown for a few seconds after a reversible action.
struct UndoOffer: Identifiable, Equatable {
    let id = UUID()
    var text: String
    var perform: () async -> Void

    static func == (lhs: UndoOffer, rhs: UndoOffer) -> Bool { lhs.id == rhs.id }
}

extension View {
    func undoBar(_ offer: Binding<UndoOffer?>, seconds: Double = 5) -> some View {
        overlay(alignment: .bottom) {
            if let current = offer.wrappedValue {
                UndoBar(text: current.text) {
                    offer.wrappedValue = nil
                    Task { await current.perform() }
                }
                .task(id: current.id) {
                    try? await Task.sleep(for: .seconds(seconds))
                    if offer.wrappedValue?.id == current.id { offer.wrappedValue = nil }
                }
            }
        }
        .animation(.smooth, value: offer.wrappedValue)
    }
}
