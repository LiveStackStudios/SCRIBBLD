import SwiftUI

struct InkProView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var selected: StoreManager.ProductID = .annualSubscription
    @State private var carouselPage: Int = 0

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            GraphPaperView(lineOpacity: 0.18).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    themeCarousel
                    membershipCard
                    pricingRow
                    upgradeButton
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, 6)
                .padding(.bottom, 32)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            InkProSeal()
                .frame(width: 64, height: 64)
            Text("Go Unlimited\nwith Ink Pro!")
                .font(.caveat(30, weight: .bold))
                .foregroundStyle(Color.inkBlue)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.trailing, 6)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var themeCarousel: some View {
        TabView(selection: $carouselPage) {
            midnightInkPreview.tag(0)
            oldLibraryPreview.tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .frame(height: 220)
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card))
        .sketchBorder(color: .inkBlue, lineWidth: 1.2, cornerRadius: Radius.card, seed: 64)
    }

    private var midnightInkPreview: some View {
        themeCard(
            title: "Midnight Ink — Dark Mode",
            background: Color(hex: "#0E1F3A"),
            grid: Color(hex: "#22436C").opacity(0.4),
            ink: Color(hex: "#E9D9A7"),
            accent: Color(hex: "#F25C5C"),
            paper: Color(hex: "#101D33"),
            tagline: "Hand-curated for night writing."
        )
    }

    private var oldLibraryPreview: some View {
        themeCard(
            title: "Old Library — Aged Parchment",
            background: Color(hex: "#E8D9B5"),
            grid: Color(hex: "#B89F70").opacity(0.5),
            ink: Color(hex: "#3B2A14"),
            accent: Color(hex: "#7A2E2E"),
            paper: Color(hex: "#F0E2BD"),
            tagline: "Like writing in your grandfather's notebook."
        )
    }

    private func themeCard(title: String, background: Color, grid: Color, ink: Color, accent: Color, paper: Color, tagline: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.dmSans(12, weight: .semibold))
                .foregroundStyle(Color.inkBlue)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            ZStack {
                background
                Canvas { ctx, size in
                    let spacing: CGFloat = 18
                    for x in stride(from: 0.0, to: size.width, by: spacing) {
                        var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(p, with: .color(grid), style: StrokeStyle(lineWidth: 0.5))
                    }
                    for y in stride(from: 0.0, to: size.height, by: spacing) {
                        var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(p, with: .color(grid), style: StrokeStyle(lineWidth: 0.5))
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Sketch.")
                            .font(.caveat(24, weight: .bold))
                            .foregroundStyle(ink)
                        Text("Today.")
                            .font(.caveat(24, weight: .bold))
                            .foregroundStyle(accent)
                    }
                    Text(tagline)
                        .font(.dmSans(11))
                        .foregroundStyle(ink.opacity(0.8))
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { _ in
                            Rectangle()
                                .fill(paper)
                                .frame(width: 36, height: 24)
                                .overlay(Rectangle().stroke(ink.opacity(0.5), lineWidth: 0.5))
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private var membershipCard: some View {
        ZStack {
            Color.white.opacity(0.7)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MEMBERSHIP CARD")
                        .font(.dmSans(13, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Color.inkBlue)
                    Spacer()
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(Color.inkBlue.opacity(0.6))
                }
                ForEach(["UNLIMITED SKETCHBOOKS", "EXCLUSIVE BRUSHES", "CLOUD SYNC", "PRIORITY SUPPORT"], id: \.self) { line in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.inkBlue)
                        Text(line)
                            .font(.dmSans(12, weight: .semibold))
                            .tracking(1.2)
                            .foregroundStyle(Color.inkBlue)
                    }
                }
                HStack {
                    Spacer()
                    Text("Active Now")
                        .font(.dmSans(10, weight: .semibold))
                        .foregroundStyle(Color.inkBlue)
                        .padding(8)
                        .overlay(Circle().stroke(Color.inkBlue.opacity(0.6), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2])))
                }
            }
            .padding(14)
        }
        .sketchBorder(color: .inkBlue, lineWidth: 1.6, cornerRadius: 10, jitter: 1.1, dash: [3, 2], seed: 305)
    }

    private var pricingRow: some View {
        HStack(spacing: 10) {
            ForEach(store.offerings, id: \.id) { offering in
                pricingCard(offering)
            }
        }
    }

    private func pricingCard(_ offering: StoreManager.Offering) -> some View {
        let isSelected = selected == offering.id
        return Button {
            HapticEngine.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selected = offering.id
            }
        } label: {
            VStack(spacing: 6) {
                Text(offering.headline)
                    .font(.dmSans(12, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                Text(offering.price)
                    .font(.caveat(24, weight: .bold))
                    .foregroundStyle(Color.inkBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.trailing, 3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(offering.perUnit)
                    .font(.dmSans(11))
                    .foregroundStyle(Color.softGray)
                if let badge = offering.badge {
                    Text(badge)
                        .font(.dmSans(9, weight: .bold))
                        .foregroundStyle(Color.redPen)
                }
                if let savings = offering.savings {
                    Text(savings)
                        .font(.dmSans(9, weight: .bold))
                        .foregroundStyle(Color.redPen)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .padding(10)
            .background(isSelected ? Color.inkBlue.opacity(0.06) : Color.white.opacity(0.75))
            .sketchBorder(color: isSelected ? .inkBlue : .lightLine, lineWidth: isSelected ? 1.8 : 1.2, cornerRadius: 8, jitter: 0.8, seed: UInt64(offering.id.rawValue.hashValue & 0xFFFF))
        }
        .buttonStyle(.plain)
    }

    private var upgradeButton: some View {
        Button {
            Task {
                HapticEngine.medium()
                await store.purchase(selected)
                dismiss()
            }
        } label: {
            HStack {
                Image(systemName: "star.fill")
                Text("Upgrade to Ink Pro")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.trailing, 4)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "star.fill")
            }
            .font(.caveat(22, weight: .bold))
            .foregroundStyle(Color.cream)
            .zIndex(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.inkBlue)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

struct InkProSeal: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.inkBlue, style: StrokeStyle(lineWidth: 2))
            Text("Ink\nPro")
                .font(.caveat(18, weight: .bold))
                .foregroundStyle(Color.goldAccent)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    InkProView()
        .environmentObject(StoreManager())
}
