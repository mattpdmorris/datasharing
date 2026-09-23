import Foundation

/// Denominators from the ANU Development Policy Centre / UPNG PNG National
/// Budget Database (tools/build_app_data.py --anu-budget). They drive the
/// constant-price, % of GDP and % of total spending views everywhere.
struct ANUData: Decodable, Sendable {
    struct Source: Decodable, Sendable {
        let name: String
        let publisher: String
        let edition: String
        let authors: String
        let updated: String
        let file: String
        let econFile: String?

        enum CodingKeys: String, CodingKey {
            case name, publisher, edition, authors, updated, file
            case econFile = "econ_file"
        }
    }

    struct Year: Decodable, Sendable {
        /// Nominal GDP, K million.
        let gdp: Double?
        /// "b" = budget database (Treasury/NSO new series), "e" = ANU PNG Economic Database new series.
        let gdpSrc: String?
        let gdpStatus: String?
        /// CPI, base year = 100 (chained from ANU Table 9 annual-average inflation).
        let cpi: Double?
        let cpiStatus: String?
        /// GDP deflator, base year = 100 (ANU Analysis sheet, rebased).
        let deflator: Double?
        /// Total general government expenditure and net lending, K million.
        let totalExp: Double?
        let expStatus: String?

        enum CodingKeys: String, CodingKey {
            case gdp, cpi, deflator
            case gdpSrc = "gdp_src"
            case gdpStatus = "gdp_status"
            case cpiStatus = "cpi_status"
            case totalExp = "total_exp"
            case expStatus = "exp_status"
        }
    }

    let baseYear: Int
    let source: Source
    let years: [String: Year]

    enum CodingKeys: String, CodingKey {
        case source, years
        case baseYear = "base_year"
    }

    func year(_ y: Int) -> Year? { years[String(y)] }

    static func statusLabel(_ s: String?) -> String? {
        switch s {
        case "e": "estimate"
        case "p": "projection"
        default: nil
        }
    }
}

/// Which price index converts to constant prices.
enum Deflator: String, CaseIterable, Identifiable {
    case cpi, gdp
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cpi: "Consumer prices (CPI)"
        case .gdp: "GDP deflator"
        }
    }
}
