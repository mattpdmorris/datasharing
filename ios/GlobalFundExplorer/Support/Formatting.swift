import SwiftUI

extension Double {
    /// "$1.2B" style, for tiles and list rows.
    var usdCompact: String {
        formatted(.currency(code: "USD").notation(.compactName).precision(.significantDigits(1...3)))
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
