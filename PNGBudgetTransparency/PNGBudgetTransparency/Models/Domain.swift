import Foundation

/// Which of the three headline measures is being shown.
enum FiscalMeasure: String, CaseIterable, Identifiable {
    case expenditure = "expenditure_and_net_lending"
    case revenue = "revenue_and_grants"
    case balance = "budget_balance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .expenditure: "Expenditure"
        case .revenue: "Revenue"
        case .balance: "Balance"
        }
    }

    var longTitle: String {
        switch self {
        case .expenditure: "Expenditure and net lending"
        case .revenue: "Revenue and grants"
        case .balance: "Budget balance"
        }
    }
}

/// How a kina figure is presented. Only `nominal` is the printed figure; the
/// others are clearly labelled transformations using ANU denominators, and a
/// year without the denominator drops out rather than being estimated.
enum Lens: String, CaseIterable, Identifiable {
    case nominal, real, gdp, share

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nominal: "Kina"
        case .real: "2025 prices"
        case .gdp: "% GDP"
        case .share: "% spending"
        }
    }

    var longTitle: String {
        switch self {
        case .nominal: "Kina, as printed"
        case .real: "Constant 2025 prices"
        case .gdp: "Per cent of GDP"
        case .share: "Per cent of total spending"
        }
    }

    var axisLabel: String {
        switch self {
        case .nominal: "K million, nominal"
        case .real: "K million, constant 2025 prices"
        case .gdp: "Per cent of GDP"
        case .share: "Per cent of total government spending"
        }
    }

    var isPercent: Bool { self == .gdp || self == .share }

    /// Transform a K-million figure for `year` using ANU denominators.
    func apply(_ value: Double, _ d: ANUData.Year?, deflator: Deflator) -> Double? {
        switch self {
        case .nominal:
            return value
        case .real:
            let index = deflator == .cpi ? d?.cpi : d?.deflator
            guard let index, index > 0 else { return nil }
            return value / (index / 100)
        case .gdp:
            guard let gdp = d?.gdp, gdp > 0 else { return nil }
            return value / gdp * 100
        case .share:
            guard let total = d?.totalExp, total > 0 else { return nil }
            return value / total * 100
        }
    }
}

/// One year of one headline measure, with the outturn chosen the way the site
/// chooses it: the Final Budget Outcome figure where one exists. The later
/// Budget Volume 1 "Actual" is kept alongside, never merged silently.
struct FiscalRow: Identifiable, Hashable {
    let record: FiscalRecord
    var id: String { record.id }
    var year: Int { record.year }
    var budget: Double? { record.budgeted.value }
    var fboOutturn: Double? { record.outturn?.printed }
    var budgetDocActual: Double? { record.outturnBudget?.value }

    /// The figure to plot as outturn, and which document it came from.
    var outturn: Double? { fboOutturn ?? budgetDocActual }
    var outturnSource: Reading? { record.outturn ?? record.outturnBudget }
    var outturnIsFromLaterBudget: Bool { fboOutturn == nil && budgetDocActual != nil }

    /// Outturn as a share of the budget (for expenditure and revenue).
    var execution: Double? {
        guard let b = budget, let o = outturn, b != 0 else { return nil }
        return o / b
    }

    /// Two official outturns for the same year that disagree by more than rounding.
    var outturnsDisagree: Bool {
        guard let a = fboOutturn, let b = budgetDocActual else { return false }
        return abs(a - b) > 0.5
    }

    var hasFlag: Bool {
        let flags = [record.budgeted.flag, record.outturn?.flag] + record.checks.map(\.verdict)
        return flags.contains { f in
            guard let f else { return false }
            return !["OK", "UNCHECKED", "match", "rounding", "ROUNDING"].contains(f)
        }
    }

    static func == (l: FiscalRow, r: FiscalRow) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

enum AgencySeries: Int, CaseIterable, Identifiable {
    case appropriation = 0, actual = 1, projection = 2
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .appropriation: "Appropriation"
        case .actual: "Actual"
        case .projection: "Projection"
        }
    }
}

/// A decoded row of the site's compact `facts` array:
/// [agencyIdx, edition, refYear, serIdx, value, printedPage, pdfPage, volIdx].
struct AgencyFact: Identifiable, Hashable {
    let agencyIndex: Int
    let edition: Int
    let refYear: Int
    let series: AgencySeries
    let value: Double
    let printedPage: Int
    let pdfPage: Int
    let volumeIndex: Int

    var id: String { "\(agencyIndex)-\(edition)-\(refYear)-\(series.rawValue)-\(pdfPage)" }

    init?(_ raw: [Double]) {
        guard raw.count >= 8, let s = AgencySeries(rawValue: Int(raw[3])) else { return nil }
        agencyIndex = Int(raw[0]); edition = Int(raw[1]); refYear = Int(raw[2])
        series = s; value = raw[4]
        printedPage = Int(raw[5]); pdfPage = Int(raw[6]); volumeIndex = Int(raw[7])
    }
}

struct Agency: Identifiable, Hashable {
    let ref: AgencyRef
    let facts: [AgencyFact]
    var id: Int { ref.i }
    var name: String { ref.name }
    var code: String { ref.code }
    var sector: String { ref.sector }

    /// The appropriation printed in each year's own budget (edition == year).
    func appropriation(for year: Int) -> AgencyFact? {
        facts.first { $0.series == .appropriation && $0.refYear == year && $0.edition == year }
            ?? facts.filter { $0.series == .appropriation && $0.refYear == year }.min { $0.edition < $1.edition }
    }

    /// The most recent edition's "actual" for a year.
    func actual(for year: Int) -> AgencyFact? {
        facts.filter { $0.series == .actual && $0.refYear == year }.max { $0.edition < $1.edition }
    }

    var latestEdition: Int? { facts.map(\.edition).max() }

    /// Agency 299 prints gross debt service, including Treasury bill
    /// redemptions — counted as spending it would exceed the whole budget.
    var isDebtCharges: Bool { code == "299" }

    var years: [Int] { Array(Set(facts.map(\.refYear))).sorted() }

    var latestAppropriation: AgencyFact? {
        guard let e = latestEdition else { return nil }
        return appropriation(for: e)
    }

    static func == (l: Agency, r: Agency) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

struct SectorTotal: Identifiable, Hashable {
    let sector: String
    let value: Double
    var id: String { sector }
}
