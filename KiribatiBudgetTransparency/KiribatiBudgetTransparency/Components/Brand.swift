import SwiftUI

enum Brand {
    static let appName = "Kiribati Budget Transparency"
    static let poweredBy = "powered by Virtual Economics"
    static let siteURL = URL(string: "https://virtualeconomics.com")!
    static let dataURL = URL(string: "https://data.virtualeconomics.com/")!

    static let red = Color("BrandRed")
    static let gold = Color("BrandGold")
    static let blue = Color("BrandBlue")

    /// Series colours used consistently across every chart.
    static let budget = Color("BrandGold")
    static let revised = Color("BrandBlue")
    static let actual = Color("BrandRed")
}

/// Red sky, gold sun, blue-and-white sea — the flag's elements as a mark.
struct BrandMark: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Color(red: 0.81, green: 0.07, blue: 0.15)
            Circle()
                .fill(Color(red: 0.99, green: 0.82, blue: 0.09))
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: size * 0.1)
            VStack(spacing: 0) {
                Spacer()
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(i % 2 == 0 ? Color(red: 0.0, green: 0.25, blue: 0.53) : .white)
                        .frame(height: size * 0.12)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}

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
