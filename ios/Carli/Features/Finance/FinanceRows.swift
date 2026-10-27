import SwiftUI

struct TransactionLine: View {
    var transaction: FinanceTransaction
    var accounts: [AccountRef]

    var body: some View {
        RowLayout(symbol: transaction.symbol, soft: transaction.needsCategory,
                  title: transaction.title, subtitle: transaction.subtitle(accounts: accounts),
                  titleBadge: transaction.fromBank ? "building.columns" : nil) {
            Text(transaction.amountLabel)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.isTransfer ? CarliColor.text2
                                 : transaction.amountCents > 0 ? CarliColor.positive : CarliColor.text)
        }
    }
}

/// Icon circle, title and subtitle, trailing figure: the list row shared by movements and charges.
struct RowLayout<Trailing: View>: View {
    var symbol: String
    var soft: Bool
    var title: String
    var subtitle: String
    var titleBadge: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: CarliSpace.s12) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(soft ? CarliColor.text2 : CarliColor.text)
                .frame(width: 40, height: 40)
                .background(CarliColor.surface2, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: CarliSpace.s4) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(CarliColor.text)
                        .lineLimit(1)
                    if let titleBadge {
                        Image(systemName: titleBadge)
                            .font(.caption2)
                            .foregroundStyle(CarliColor.text3)
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: CarliSpace.s8)
            trailing
        }
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, CarliSpace.s12)
        .accessibilityElement(children: .combine)
    }
}

