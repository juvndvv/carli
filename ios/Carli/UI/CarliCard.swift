import SwiftUI

/// Content card: surface fill, 22 pt continuous corners. Content stays opaque;
/// Liquid Glass is reserved for navigation and controls, as the HIG asks.
struct CarliCard<Content: View>: View {
    var padding: CGFloat = CarliSpace.s16
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CarliColor.surface, in: .rect(cornerRadius: CarliRadius.card, style: .continuous))
    }
}

/// Card header row: optional round icon, title, optional trailing action or chevron.
struct CardHeader<Trailing: View>: View {
    var title: String
    var subtitle: String?
    var symbol: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: CarliSpace.s12) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(CarliColor.text)
                    .frame(width: 32, height: 32)
                    .background(CarliColor.surface2, in: .circle)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(CarliColor.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(CarliColor.text2)
                }
            }
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            trailing
        }
    }
}

extension CardHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, symbol: String? = nil) {
        self.init(title: title, subtitle: subtitle, symbol: symbol) { EmptyView() }
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(CarliColor.text3)
    }
}

/// Small neutral pill; a state colours only the text, never the fill.
struct CarliBadge: View {
    enum Tone { case neutral, warning, negative }

    var label: String
    var symbol: String?
    var tone: Tone = .neutral

    var body: some View {
        Label {
            Text(label)
        } icon: {
            if let symbol { Image(systemName: symbol) }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone == .negative ? CarliColor.negative : tone == .warning ? CarliColor.warning : CarliColor.text2)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(CarliColor.surface2, in: .capsule)
    }
}

/// Shimmer-free placeholder bar for loading states.
struct SkeletonBar: View {
    var width: CGFloat
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(CarliColor.surface2)
            .frame(width: width, height: height)
            .accessibilityHidden(true)
    }
}
