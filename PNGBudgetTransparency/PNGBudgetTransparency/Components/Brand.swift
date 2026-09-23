import SwiftUI

enum Brand {
    static let appName = "PNG Budget Transparency"
    static let poweredBy = "powered by Virtual Economics"
    static let siteURL = URL(string: "https://virtualeconomics.com")!
    static let dataURL = URL(string: "https://data.virtualeconomics.com/png/budget/")!

    static let red = Color("BrandRed")
    static let gold = Color("BrandGold")

    /// Series colours used consistently across every chart.
    static let budget = Color("BrandGold")
    static let outturn = Color("BrandRed")
    static let projection = Color.secondary
}

/// The flag-diagonal mark used on the launch screen and About page.
struct BrandMark: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.08))
            Diagonal()
                .fill(Color(red: 0.81, green: 0.07, blue: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            HStack(alignment: .bottom, spacing: size * 0.05) {
                ForEach([0.30, 0.46, 0.62, 0.80], id: \.self) { h in
                    RoundedRectangle(cornerRadius: size * 0.03)
                        .fill(Color(red: 0.99, green: 0.82, blue: 0.09))
                        .frame(width: size * 0.1, height: size * h * 0.8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(size * 0.12)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private struct Diagonal: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.closeSubpath()
            return p
        }
    }
}

/// Small "powered by" footer placed at the bottom of each main screen.
struct PoweredByFooter: View {
    var body: some View {
        Link(destination: Brand.siteURL) {
            HStack(spacing: 6) {
                BrandMark(size: 16)
                Text(Brand.poweredBy)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
}
