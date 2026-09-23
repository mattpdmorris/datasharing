import Foundation

/// The budget record exactly as the Virtual Economics data site publishes it
/// (the `<script id="payload">` blob on /png/budget/). Field names mirror the
/// site so a refreshed payload drops straight in; everything the app does not
/// strictly need is optional so a schema addition never breaks decoding.
struct BudgetPayload: Decodable, Sendable {
    let generated: String
    let corpusVersion: String
    let measures: [Measure]
    let denominators: [String: Denominator]
    let gdpSource: GDPSource?
    let cpiSource: CPISource?
    let fiscal: [FiscalRecord]
    let reconciliation: [Reconciliation]
    let outturnRevisions: [OutturnRevision]
    let gdpReconciliation: [GDPReconciliation]
    let restatements: [Restatement]
    let agencies: [AgencyRef]
    let seriesCodes: [String]
    let volumes: [String]
    let facts: [[Double]]
    let quality: Quality?
    let counts: Counts

    enum CodingKeys: String, CodingKey {
        case generated, measures, denominators, fiscal, reconciliation, restatements,
             agencies, volumes, facts, quality, counts
        case corpusVersion = "corpus_version"
        case gdpSource = "gdp_source"
        case cpiSource = "cpi_source"
        case outturnRevisions = "outturn_revisions"
        case gdpReconciliation = "gdp_reconciliation"
        case seriesCodes = "series_codes"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generated = try c.decode(String.self, forKey: .generated)
        corpusVersion = try c.decode(String.self, forKey: .corpusVersion)
        measures = try c.decode([Measure].self, forKey: .measures)
        denominators = try c.decodeIfPresent([String: Denominator].self, forKey: .denominators) ?? [:]
        gdpSource = try c.decodeIfPresent(GDPSource.self, forKey: .gdpSource)
        cpiSource = try c.decodeIfPresent(CPISource.self, forKey: .cpiSource)
        fiscal = try c.decode([FiscalRecord].self, forKey: .fiscal)
        reconciliation = try c.decodeIfPresent([Reconciliation].self, forKey: .reconciliation) ?? []
        outturnRevisions = try c.decodeIfPresent([OutturnRevision].self, forKey: .outturnRevisions) ?? []
        gdpReconciliation = try c.decodeIfPresent([GDPReconciliation].self, forKey: .gdpReconciliation) ?? []
        restatements = try c.decodeIfPresent([Restatement].self, forKey: .restatements) ?? []
        agencies = try c.decode([AgencyRef].self, forKey: .agencies)
        seriesCodes = try c.decode([String].self, forKey: .seriesCodes)
        volumes = try c.decode([String].self, forKey: .volumes)
        facts = try c.decode([[Double]].self, forKey: .facts)
        quality = try c.decodeIfPresent(Quality.self, forKey: .quality)
        counts = try c.decode(Counts.self, forKey: .counts)
    }
}

struct Measure: Decodable, Hashable {
    let key: String
    let label: String
}

struct Denominator: Decodable {
    let gdpPrimary: Double?
    let gdpPrimarySrc: String?
    let cpi2025: Double?
    let cpi2025Flag: String?

    enum CodingKeys: String, CodingKey {
        case cpi2025
        case gdpPrimary = "gdp_primary"
        case gdpPrimarySrc = "gdp_primary_src"
        case cpi2025Flag = "cpi2025_flag"
    }

    var isChainLinked: Bool { cpi2025Flag == "LINKED_ACROSS_BASE_BREAK" }
}

struct GDPSource: Decodable {
    struct Part: Decodable { let span: String; let name: String; let tier: String }
    let composite: [Part]?
    let notHeld: [Int]?
    let validation: String?
    let excludedForConflict: [Int]?

    enum CodingKeys: String, CodingKey {
        case composite, validation
        case notHeld = "not_held"
        case excludedForConflict = "excluded_for_conflict"
    }
}

struct CPISource: Decodable {
    let name: String
    let measure: String
    let tier: String?
    let base: String
    let baseBreak: String?

    enum CodingKeys: String, CodingKey {
        case name, measure, tier, base
        case baseBreak = "base_break"
    }
}

/// One printed figure and exactly where it came from. The same shape is used
/// for budget-paper readings (table/column/row) and Final Budget Outcome cells
/// (col/status/cell), so every locator is optional.
struct Reading: Decodable, Hashable {
    let printed: Double?
    let derived: Double?
    let flag: String?
    let doc: String?
    let page: Int?
    let table: String?
    let column: String?
    let row: String?
    let edition: Int?
    let series: String?
    let col: String?
    let status: String?
    let cell: String?
    let diff: Double?
    let verdict: String?

    /// The printed figure where there is one; the site falls back to the
    /// derived figure only when the source printed nothing.
    var value: Double? { printed ?? derived }
    var isDerivedOnly: Bool { printed == nil && derived != nil }
}

struct FiscalRecord: Decodable, Identifiable {
    let year: Int
    let measure: String
    let label: String
    let budgeted: Reading
    /// Outturn as printed in that year's Final Budget Outcome — the site's final figure.
    let outturn: Reading?
    /// The "Actual" column for this year in a later Budget Volume 1.
    let outturnBudget: Reading?
    let checks: [Reading]
    let later: [Reading]

    var id: String { "\(year)-\(measure)" }

    enum CodingKeys: String, CodingKey {
        case year, measure, label, budgeted, outturn, checks, later
        case outturnBudget = "outturn_budget"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        year = try c.decode(Int.self, forKey: .year)
        measure = try c.decode(String.self, forKey: .measure)
        label = try c.decode(String.self, forKey: .label)
        budgeted = try c.decode(Reading.self, forKey: .budgeted)
        outturn = try c.decodeIfPresent(Reading.self, forKey: .outturn)
        outturnBudget = try c.decodeIfPresent(Reading.self, forKey: .outturnBudget)
        checks = try c.decodeIfPresent([Reading].self, forKey: .checks) ?? []
        later = try c.decodeIfPresent([Reading].self, forKey: .later) ?? []
    }
}

struct Reconciliation: Decodable, Identifiable {
    let year: Int
    let measure: String
    let label: String
    let budgetDoc: Reading
    let fbo: Reading
    var id: String { "\(year)-\(measure)" }

    enum CodingKeys: String, CodingKey {
        case year, measure, label, fbo
        case budgetDoc = "budget_doc"
    }
}

struct OutturnRevision: Decodable, Identifiable {
    let year: Int
    let measure: String
    let label: String
    let fbo: Reading
    let budgetActual: Reading
    var id: String { "\(year)-\(measure)" }

    enum CodingKeys: String, CodingKey {
        case year, measure, label, fbo
        case budgetActual = "budget_actual"
    }
}

struct GDPReconciliation: Decodable, Identifiable {
    struct GDPReading: Decodable, Hashable {
        let v: Double
        let col: String?
        let doc: String
        let page: Int?
        let table: String?
    }
    let year: Int
    let readings: [GDPReading]
    let spreadPct: Double?
    let latest: Double?
    let latestDoc: String?
    let gapPct: Double?
    var id: Int { year }

    enum CodingKeys: String, CodingKey {
        case year, readings, latest
        case spreadPct = "spread_pct"
        case latestDoc = "latest_doc"
        case gapPct = "gap_pct"
    }
}

struct Restatement: Decodable, Identifiable {
    struct RestatedReading: Decodable, Hashable {
        let v: Double
        let doc: String
        let page: Int?
        let cell: String?
    }
    let series: String
    let seriesId: String
    let period: Int
    let spread: Double
    let readings: [RestatedReading]
    var id: String { "\(seriesId)-\(period)" }

    enum CodingKeys: String, CodingKey {
        case series, period, spread, readings
        case seriesId = "series_id"
    }
}

struct AgencyRef: Decodable, Hashable {
    let name: String
    let code: String
    let sector: String
    let i: Int
}

struct Quality: Decodable {
    struct ConflictingDuplicate: Decodable, Identifiable, Hashable {
        let agency: String
        let edition: Int
        let refYear: Int
        let series: String
        let values: [Double]
        var id: String { "\(agency)-\(edition)-\(refYear)-\(series)" }
        enum CodingKeys: String, CodingKey {
            case agency, edition, series, values
            case refYear = "ref_year"
        }
    }
    struct NameVariant: Decodable, Identifiable, Hashable {
        let suspect: String
        let rows: Int
        let likely: String
        var id: String { suspect }
    }
    let conflictingDuplicates: [ConflictingDuplicate]
    let nameVariants: [NameVariant]

    enum CodingKeys: String, CodingKey {
        case conflictingDuplicates = "conflicting_duplicates"
        case nameVariants = "name_variants"
    }
}

struct Counts: Decodable {
    let observations: Int
    let treasuryObservations: Int
    let treasuryDocuments: Int
    let agencies: Int
    let agencyFacts: Int

    enum CodingKeys: String, CodingKey {
        case observations, agencies
        case treasuryObservations = "treasury_observations"
        case treasuryDocuments = "treasury_documents"
        case agencyFacts = "agency_facts"
    }
}
