import SwiftUI

extension Double {
    /// "$1.2B" style, for tiles and list rows.
    /// Built by hand because the currency format style's `.notation` needs iOS 18.
    var usdCompact: String {
        (self < 0 ? "-$" : "$") + abs(self).compactDigits
    }

    /// "1.2M" style, for counts such as people treated.
    var countCompact: String {
        (self < 0 ? "-" : "") + abs(self).compactDigits
    }

    private var compactDigits: String {
        let (divisor, suffix): (Double, String) =
            self >= 1e9 ? (1e9, "B")
            : self >= 1e6 ? (1e6, "M")
            : self >= 1e3 ? (1e3, "K")
            : (1, "")
        return (self / divisor).formatted(.number.precision(.significantDigits(1...3))) + suffix
    }

    /// "$1,234,567", for detail rows.
    var usdFull: String {
        formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }

    var percent: String {
        formatted(.percent.precision(.fractionLength(0)))
    }
}

extension Optional where Wrapped == Double {
    var usdCompact: String { map(\.usdCompact) ?? "—" }
    var usdFull: String { map(\.usdFull) ?? "—" }
}

extension Optional where Wrapped == Date {
    var shortDate: String { map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—" }
}

extension Disease {
    var color: Color {
        switch self {
        case .hiv: .red
        case .tuberculosis: .blue
        case .malaria: .green
        case .hivTB: .purple
        case .rssh: .orange
        case .other: .gray
        }
    }

    var symbol: String {
        switch self {
        case .hiv: "cross.case"
        case .tuberculosis: "lungs"
        case .malaria: "ant"
        case .hivTB: "cross.vial"
        case .rssh: "building.2"
        case .other: "square.grid.2x2"
        }
    }
}
