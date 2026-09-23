import Foundation

// Rows for the Data Service datasets beyond grants. Amounts are USD at the
// Global Fund reference rate. Each type maps one `$apply` aggregation or
// query row (see GlobalFundAPI+Datasets.swift).

/// Communicated allocation for one component in one allocation cycle.
struct AllocationRow: Identifiable, Hashable, Sendable {
    let cycle: String
    let component: String
    let amount: Double

    var id: String { cycle + "|" + component }
    var disease: Disease { Disease(componentName: component) }
}

/// A labelled amount, used for budget cost categories and expenditure modules.
struct AmountRow: Identifiable, Hashable, Sendable {
    let label: String
    let amount: Double
    var id: String { label }
}

/// Annual programmatic result (e.g. "People on antiretroviral therapy").
struct ResultRow: Identifiable, Hashable, Sendable {
    let indicator: String
    let component: String
    let year: Int
    let value: Double

    var id: String { "\(year)|\(component)|\(indicator)" }
    var disease: Disease { Disease(componentName: component) }
}

/// Eligibility of one component in one year.
struct EligibilityRow: Identifiable, Hashable, Sendable {
    let year: Int
    let component: String
    let status: String
    let incomeLevel: String?
    let diseaseBurden: String?

    var id: String { "\(year)|\(component)" }
    var isEligible: Bool { status.lowercased().hasPrefix("eligible") }
}

/// A funding request and the grants it led to.
struct FundingRequestRow: Identifiable, Hashable, Sendable {
    let id: String
    let components: String
    let submissionDate: Date?
    let window: String?
    let reviewApproach: String?
    let reviewOutcome: String?
    let reviewDate: Date?
    let grantCodes: [String]
}

/// A published document such as a funding request, grant agreement or audit report.
struct DocumentRow: Identifiable, Hashable, Sendable {
    let type: String
    let subtype: String?
    let title: String
    let url: URL?

    var id: String { (url?.absoluteString ?? "") + "|" + title }
}

/// One donor's pledge and contribution for one replenishment period.
struct PledgeRow: Identifiable, Hashable, Sendable {
    let donor: String
    let donorType: String
    let period: String
    var pledged: Double
    var contributed: Double

    var id: String { donor + "|" + period }
}

/// Pledges and contributions summed per donor or per period.
struct PledgeTotal: Identifiable, Hashable, Sendable {
    let name: String
    let detail: String?
    let pledged: Double
    let contributed: Double

    var id: String { name }
    var paidShare: Double? { pledged > 0 ? min(contributed / pledged, 1) : nil }
}

extension Array where Element == PledgeRow {
    func totals(by key: (PledgeRow) -> String, detail: (PledgeRow) -> String? = { _ in nil }) -> [PledgeTotal] {
        Dictionary(grouping: self, by: key)
            .map { name, rows in
                PledgeTotal(
                    name: name,
                    detail: rows.first.flatMap(detail),
                    pledged: rows.reduce(0) { $0 + $1.pledged },
                    contributed: rows.reduce(0) { $0 + $1.contributed }
                )
            }
    }
}
