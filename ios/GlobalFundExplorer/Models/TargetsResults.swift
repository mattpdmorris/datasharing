import Foundation

/// One implementation period of a grant (a grant usually has one per grant cycle).
struct ImplementationPeriod: Identifiable, Hashable, Sendable {
    let code: String
    let title: String?
    let startDate: Date?
    let endDate: Date?

    var id: String { code }

    var label: String {
        let years = [startDate, endDate]
            .compactMap { $0.map { String(Calendar.utc.component(.year, from: $0)) } }
            .joined(separator: "–")
        switch (title, years.isEmpty) {
        case (let title?, false): return "\(title) (\(years))"
        case (let title?, true): return title
        case (nil, false): return years
        case (nil, true): return code
        }
    }
}

/// A baseline, target or result. The API stores a number (numerator and
/// optional denominator), a percentage on a 0–100 scale, or free text.
struct IndicatorValue: Hashable, Sendable {
    let percentage: Double?
    let numerator: Double?
    let denominator: Double?
    let text: String?

    var isEmpty: Bool { percentage == nil && numerator == nil && text == nil }

    /// The number to compare against a target: the percentage when there is one.
    var comparable: Double? { percentage ?? numerator }

    var display: String? {
        if let percentage {
            let pct = (percentage / 100).formatted(.percent.precision(.fractionLength(0...1)))
            if let numerator, let denominator, denominator > 0 {
                return "\(pct) (\(numerator.countCompact)/\(denominator.countCompact))"
            }
            return pct
        }
        if let numerator {
            if let denominator, denominator > 0 {
                return "\(numerator.countCompact)/\(denominator.countCompact)"
            }
            return numerator.formatted(.number.precision(.fractionLength(0...1)))
        }
        return text
    }
}

/// One row of a grant's performance framework: an indicator's baseline, target
/// and result for one year and, optionally, one disaggregation group.
struct TargetResultRow: Identifiable, Hashable, Sendable {
    let id: String
    let indicator: String
    let module: String
    /// "Impact indicator", "Outcome indicator" or "Coverage / Output indicator".
    let type: String
    /// Disaggregation category, e.g. "Sex" or "Age" (the API's grouping_Level1).
    let category: String?
    /// Disaggregation group within the category, e.g. "Female" (grouping_Level2).
    let group: String?
    let coverage: String?
    let year: Int?
    /// True when lower values are better (e.g. incidence or mortality).
    let isReversed: Bool
    let baseline: IndicatorValue
    let target: IndicatorValue
    let result: IndicatorValue
    /// Achievement reported by the Global Fund, as a ratio (0.85 = 85%).
    let performance: Double?

    var isDisaggregated: Bool { category != nil || group != nil }

    var breakdownLabel: String {
        switch (category, group) {
        case let (c?, g?): return "\(c): \(g)"
        case let (c?, nil): return c
        case let (nil, g?): return g
        case (nil, nil): return "Total"
        }
    }

    /// Reported achievement, or result against target when none is reported.
    var achievement: Double? {
        if let performance { return performance }
        guard let t = target.comparable, let r = result.comparable, t > 0, r > 0 else { return nil }
        return isReversed ? t / r : r / t
    }

    /// Key that groups every row of the same indicator.
    var indicatorKey: String { module + "|" + indicator }
}

extension TargetResultRow {
    init?(record r: Record, index: Int) {
        guard let indicator = r.string(["indicatorName"]) else { return nil }
        func value(_ prefix: String) -> IndicatorValue {
            IndicatorValue(
                percentage: r.double(["\(prefix)ValuePercentage"]),
                numerator: r.double(["\(prefix)ValueNumerator"]),
                denominator: r.double(["\(prefix)ValueDenominator"]),
                text: r.string(["\(prefix)ValueText"])
            )
        }
        // Coverage/output indicators often have no target year; the Data Explorer
        // uses the start date's year instead, and so do we.
        let year = r.int(["targetValueYear"])
            ?? r.date(["startDate"]).map { Calendar.utc.component(.year, from: $0) }
        self.init(
            id: String(index),
            indicator: indicator,
            module: r.string(["activityArea.name"]) ?? "Other",
            type: r.string(["valueType"]) ?? "Indicator",
            category: r.string(["grouping_Level1"]),
            group: r.string(["grouping_Level2"]),
            coverage: r.string(["geographicCoverage"]),
            year: year,
            isReversed: r.string(["isReversed"]) == "true",
            baseline: value("baseline"),
            target: value("target"),
            result: value("result"),
            performance: r.double(["performance"])
        )
    }
}

extension Calendar {
    /// The API's dates are UTC; read their year in UTC so time zones can't shift it.
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
