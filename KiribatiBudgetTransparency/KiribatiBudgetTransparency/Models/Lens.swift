import Foundation

/// How an A$ figure is presented. Only `nominal` is the printed figure; the
/// others are labelled transformations, and a year without the denominator
/// drops out rather than being estimated.
enum Lens: String, CaseIterable, Identifiable {
    case nominal, real, gdp, share

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nominal: "A$"
        case .real: "2025 prices"
        case .gdp: "% GDP"
        case .share: "% spending"
        }
    }

    var axisLabel: String {
        switch self {
        case .nominal: "A$, nominal"
        case .real: "A$, constant 2025 prices"
        case .gdp: "Per cent of GDP"
        case .share: "Per cent of total government spending"
        }
    }

    var isPercent: Bool { self == .gdp || self == .share }

    /// Transform a whole-dollar figure for a year.
    func apply(_ dollars: Double, _ d: Denominator?) -> Double? {
        switch self {
        case .nominal:
            return dollars
        case .real:
            guard let cpi = d?.cpi, cpi > 0 else { return nil }
            return dollars / (cpi / 100)
        case .gdp:
            guard let gdp = d?.gdp, gdp > 0 else { return nil }
            return dollars / (gdp * 1_000_000) * 100
        case .share:
            guard let t = d?.imfTotalExp, t > 0 else { return nil }
            return dollars / (t * 1_000_000) * 100
        }
    }
}
