import SwiftUI

/// Round icon choices in a grid; the selected one is filled with ink.
struct IconGrid: View {
    var icons: [String]
    @Binding var selection: String
    var columns = 6

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: CarliSpace.s12) {
            ForEach(CarliIcon.distinct(icons, keeping: selection), id: \.self) { name in
                let selected = selection == name
                Button {
                    selection = name
                } label: {
                    Image(systemName: CarliIcon.symbol(name))
                        .font(.system(size: 17))
                        .frame(width: 42, height: 42)
                        .foregroundStyle(selected ? CarliColor.onPrimary : CarliColor.text)
                        .background(selected ? CarliColor.primary : CarliColor.surface2, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.vertical, CarliSpace.s4)
    }
}

/// "Importe   [+] 12,50 €" form row; `negative` flips the sign without a minus key.
struct AmountRow: View {
    var title: String
    @Binding var text: String
    var negative: Binding<Bool>?
    var placeholder = "0"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let negative {
                Button(negative.wrappedValue ? Money.minus : "+") { negative.wrappedValue.toggle() }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .accessibilityLabel(negative.wrappedValue ? "Negativo" : "Positivo")
            }
            // A hidden copy of the digits sizes the field, so the sign button hugs them.
            ZStack(alignment: .trailing) {
                Text(text.isEmpty ? placeholder : text).monospacedDigit().hidden()
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
            }
            .frame(minWidth: 24)
            .fixedSize()
            Text("€").foregroundStyle(CarliColor.text3)
        }
    }
}

/// Round icon on a soft disc, used at the head of rows and cards.
struct IconBubble: View {
    var symbol: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42))
            .foregroundStyle(CarliColor.text)
            .frame(width: size, height: size)
            .background(CarliColor.surface2, in: .circle)
    }
}

/// Opens an account's detail when only its id is known (a goal, a debt).
struct AccountLink: Hashable {
    var id: String
}

struct AccountLinkView: View {
    let api: APIClient
    let link: AccountLink
    var go: (FinanceRoute) -> Void
    @State private var account: FinanceAccount?
    @State private var failed = false

    var body: some View {
        Group {
            if let account {
                AccountDetailView(model: AccountDetailModel(api: api, account: account), go: go)
            } else if failed {
                ContentUnavailableView("No encontramos esta cuenta", systemImage: "exclamationmark.circle",
                                       description: Text("Puede que se haya eliminado."))
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CarliColor.bg)
        .task {
            do {
                let envelope: DataEnvelope<FinanceAccount> = try await api.get("v1/finance/accounts/\(link.id)")
                account = envelope.data
            } catch {
                failed = true
            }
        }
    }
}

/// Empty or failed state inside a card, with an optional action.
struct CardMessage: View {
    var title: String
    var symbol: String
    var message: String?
    var action: String?
    var perform: (() -> Void)?

    var body: some View {
        CarliCard {
            ContentUnavailableView {
                Label(title, systemImage: symbol)
            } description: {
                if let message { Text(message) }
            } actions: {
                if let action, let perform {
                    Button(action, action: perform).buttonStyle(.glass)
                }
            }
        }
    }
}
