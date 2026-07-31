import SwiftUI

struct StampView: View {
    let stamp: Stamp

    var body: some View {
        ZStack {
            // Postmark serrated border
            Canvas { ctx, size in
                let pad: CGFloat = 4
                let rect = CGRect(x: pad, y: pad, width: size.width - pad * 2, height: size.height - pad * 2)
                ctx.stroke(
                    Path(roundedRect: rect, cornerRadius: 4),
                    with: .color(stamp.tint.color),
                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 2])
                )
                // outer dashed extra ring for postage effect
                let outer = rect.insetBy(dx: -3, dy: -3)
                ctx.stroke(
                    Path(roundedRect: outer, cornerRadius: 6),
                    with: .color(stamp.tint.color.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 0.6, dash: [1.5, 2])
                )
            }
            VStack(spacing: 2) {
                Image(systemName: stamp.iconSystemName)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(stamp.tint.color)
                Text(stamp.title)
                    .font(.caveat(15, weight: .bold))
                    .foregroundStyle(stamp.tint.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(stamp.subtitle)
                    .font(.dmSans(8, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(stamp.tint.color.opacity(0.8))
            }
            .padding(6)
        }
        .aspectRatio(1.05, contentMode: .fit)
        .opacity(stamp.isEarned ? 1 : 0.32)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        ForEach(Stamp.starter) { StampView(stamp: $0) }
    }
    .padding()
    .background(Color.cream)
}
