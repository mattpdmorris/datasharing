import Foundation

/// Everything the app shows, as written by tools/build_kiribati_data.py from
/// the Virtual Economics Kiribati hub. Figures are whole Australian dollars
/// unless a field says otherwise (denominators are A$ million / index points).
struct KiribatiData: Decodable, Sendable {
    let generated: String
    let baseYear: Int
    let currency: String
    let headline: [HeadlineYear]
    let headlineNotes: [String]
    let reconciliation: [ReconciliationYear]
    let reconciliationNotes: [String]
    let ministries: [Ministry]
    let ministryVolumes: [String: Volume]
    let ministryChecks: [TotalCheck]
    let ministryYearsNotCharted: [NotCharted]
    let donors2026: DonorTable?
    let denominators: [String: Denominator]
    let sources: [String: String]

    enum CodingKeys: String, CodingKey {
        case generated, currency, headline, reconciliation, ministries, denominators, sources
        case baseYear = "base_year"
        case headlineNotes = "headline_notes"
        case reconciliationNotes = "reconciliation_notes"
        case ministryVolumes = "ministry_volumes"
        case ministryChecks = "ministry_checks"
        case ministryYearsNotCharted = "ministry_years_not_charted"
        case donors2026 = "donors_2026"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generated = try c.decode(String.self, forKey: .generated)
        baseYear = try c.decodeIfPresent(Int.self, forKey: .baseYear) ?? 2025
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "AUD"
        headline = try c.decode([HeadlineYear].self, forKey: .headline)
        headlineNotes = try c.decodeIfPresent([String].self, forKey: .headlineNotes) ?? []
        reconciliation = try c.decodeIfPresent([ReconciliationYear].self, forKey: .reconciliation) ?? []
        reconciliationNotes = try c.decodeIfPresent([String].self, forKey: .reconciliationNotes) ?? []
        ministries = try c.decodeIfPresent([Ministry].self, forKey: .ministries) ?? []
        ministryVolumes = try c.decodeIfPresent([String: Volume].self, forKey: .ministryVolumes) ?? [:]
        ministryChecks = try c.decodeIfPresent([TotalCheck].self, forKey: .ministryChecks) ?? []
        ministryYearsNotCharted = try c.decodeIfPresent([NotCharted].self, forKey: .ministryYearsNotCharted) ?? []
        donors2026 = try c.decodeIfPresent(DonorTable.self, forKey: .donors2026)
        denominators = try c.decodeIfPresent([String: Denominator].self, forKey: .denominators) ?? [:]
        sources = try c.decodeIfPresent([String: String].self, forKey: .sources) ?? [:]
    }
}

/// One year of the recurrent budget: original, supplementary and outturn.
struct HeadlineYear: Decodable, Identifiable, Hashable, Sendable {
    let year: Int
    let appropriation: Double?
    let devFund: Double?
    let statutory: Double?
    let totalOperating: Double?
    let suppAppropriated: Double?
    let suppDevFund: Double?
    let suppStatutory: Double?
    let suppTotal: Double?
    let revised: Double?
    let actual: Double?
    let actualDevFund: Double?
    /// Supplementary as implied by the workbook's real-terms sheet, where it
    /// differs from the nominal sheet (workbook tension T45).
    let suppFromRealSheet: Double?

    var id: Int { year }

    enum CodingKeys: String, CodingKey {
        case year, appropriation, statutory, revised, actual
        case devFund = "dev_fund"
        case totalOperating = "total_operating"
        case suppAppropriated = "supp_appropriated"
        case suppDevFund = "supp_dev_fund"
        case suppStatutory = "supp_statutory"
        case suppTotal = "supp_total"
        case actualDevFund = "actual_dev_fund"
        case suppFromRealSheet = "supp_from_real_sheet"
    }

    var hasBudget: Bool { totalOperating != nil }

    /// Actual as a share of the original total operating budget.
    var execution: Double? {
        guard let a = actual, let t = totalOperating, t > 0 else { return nil }
        return a / t
    }

    var devFundShare: Double? {
        guard let d = devFund, let a = appropriation, a > 0 else { return nil }
        return d / a
    }

    /// The two supplementary readings disagree (T45).
    var supplementaryDisagrees: Bool {
        guard let r = suppFromRealSheet else { return false }
        return abs(r - (suppAppropriated ?? 0)) > 1
    }

    /// 2020 appropriated February–December only.
    var isPartYear: Bool { year == 2020 }
}

struct ReconciliationYear: Decodable, Identifiable, Hashable, Sendable {
    struct Step: Decodable, Hashable, Sendable {
        let step: String
        let amount: Double?
        let running: Double?
        let source: String?
    }
    let year: Int
    let steps: [Step]
    let revised: Double?
    let revisedSource: String?
    let residual: Double?
    let residualPct: Double?
    let verdict: String?
    var id: Int { year }

    enum CodingKeys: String, CodingKey {
        case year, steps, revised, residual, verdict
        case revisedSource = "revised_source"
        case residualPct = "residual_pct"
    }

    var closes: Bool { verdict == "closes" }
}

struct Ministry: Decodable, Identifiable, Hashable, Sendable {
    struct Fact: Decodable, Identifiable, Hashable, Sendable {
        let year: Int
        /// Total operating budget for the head = net appropriation + statutory.
        let operating: Double
        let statutory: Double?
        let net: Double?
        let code: String?
        let page: Int?
        var id: Int { year }
    }
    let name: String
    let printedNames: [String]
    let facts: [Fact]

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, facts
        case printedNames = "printed_names"
    }

    func fact(_ year: Int) -> Fact? { facts.first { $0.year == year } }
    var latest: Fact? { facts.max { $0.year < $1.year } }
    var years: [Int] { facts.map(\.year).sorted() }

    /// Not a ministry: a transfer or charge line printed in Table 2.
    var isNonMinistryLine: Bool {
        ["Contributions to the Development Fund", "Subsidies, Grants and Other Commitments",
         "Debt Servicing", "Contributions to the RERF"].contains(name)
    }
}

struct Volume: Decodable, Hashable, Sendable {
    let file: String
    let method: String
}

struct TotalCheck: Decodable, Identifiable, Hashable, Sendable {
    let year: Int
    let method: String
    let sumOfLines: Double
    let printedTotal: Double?
    let gap: Double?
    var id: Int { year }

    enum CodingKeys: String, CodingKey {
        case year, method, gap
        case sumOfLines = "sum_of_lines"
        case printedTotal = "printed_total"
    }
}

struct NotCharted: Decodable, Identifiable, Hashable, Sendable {
    let year: Int
    let sumOfLines: Double
    let printedTotal: Double?
    let reason: String
    var id: Int { year }

    enum CodingKeys: String, CodingKey {
        case year, reason
        case sumOfLines = "sum_of_lines"
        case printedTotal = "printed_total"
    }
}

struct DonorTable: Decodable, Sendable {
    struct Row: Decodable, Identifiable, Hashable, Sendable {
        let donor: String
        let values: [Double?]
        var id: String { donor }
    }
    let columns: [String]
    let rows: [Row]
    let source: String?

    func index(of column: String) -> Int? { columns.firstIndex(of: column) }

    func value(_ row: Row, _ column: String) -> Double? {
        guard let i = index(of: column), row.values.indices.contains(i) else { return nil }
        return row.values[i]
    }

    var donors: [Row] { rows.filter { !$0.donor.lowercased().contains("total") } }
    var grandTotal: Row? { rows.first { $0.donor.lowercased().contains("total") } }
}

/// Per-year denominators. GDP and total expenditure are in A$ million.
struct Denominator: Decodable, Sendable {
    let gdp: Double?
    /// "knso" (national accounts, to 2021) or "imf" (2022 onward).
    let gdpSrc: String?
    let gdpStatus: String?
    /// KNSO all-items CPI, annual average, base year = 100.
    let cpi: Double?
    let cpiMonths: Int?
    /// IMF central government total expenditure, A$ million.
    let imfTotalExp: Double?
    let imfExpStatus: String?

    enum CodingKeys: String, CodingKey {
        case gdp, cpi
        case gdpSrc = "gdp_src"
        case gdpStatus = "gdp_status"
        case cpiMonths = "cpi_months"
        case imfTotalExp = "imf_total_exp"
        case imfExpStatus = "imf_exp_status"
    }

    static func statusLabel(_ s: String?) -> String? {
        switch s {
        case "e": "estimate"
        case "p": "projection"
        default: nil
        }
    }
}
