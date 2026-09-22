import Foundation

/// All grants for one country (or multi-country area), with totals.
struct CountrySummary: Identifiable, Hashable, Sendable {
    let name: String
    let code: String?
    let grants: [Grant]

    var id: String { name }

    var signed: Double { grants.reduce(0) { $0 + ($1.signed ?? 0) } }
    var committed: Double { grants.reduce(0) { $0 + ($1.committed ?? 0) } }
    var disbursed: Double { grants.reduce(0) { $0 + ($1.disbursed ?? 0) } }
    var activeGrantCount: Int { grants.filter(\.isActive).count }

    var disbursementRate: Double? {
        signed > 0 ? min(disbursed / signed, 1) : nil
    }

    /// Signed and disbursed totals per disease, for the country chart.
    var totalsByDisease: [DiseaseTotal] {
        Dictionary(grouping: grants, by: \.disease)
            .map { disease, grants in
                DiseaseTotal(
                    disease: disease,
                    signed: grants.reduce(0) { $0 + ($1.signed ?? 0) },
                    disbursed: grants.reduce(0) { $0 + ($1.disbursed ?? 0) }
                )
            }
            .sorted { $0.signed > $1.signed }
    }

    static func group(_ grants: [Grant]) -> [CountrySummary] {
        Dictionary(grouping: grants, by: \.country)
            .map { name, grants in
                CountrySummary(
                    name: name,
                    code: grants.lazy.compactMap(\.countryCode).first,
                    grants: grants.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct DiseaseTotal: Identifiable, Hashable, Sendable {
    let disease: Disease
    let signed: Double
    let disbursed: Double
    var id: Disease { disease }
}
