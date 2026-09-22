import Foundation

/// A Global Fund grant agreement. Amounts are in USD at the Global Fund's
/// reference rate, which is how the Data Service reports cross-currency totals.
struct Grant: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let number: String
    let country: String
    let countryCode: String?
    let component: String
    let principalRecipient: String?
    let status: String?
    let grantCycle: String?
    let startDate: Date?
    let endDate: Date?
    /// Amount in the signed grant agreement.
    let signed: Double?
    /// Amount the Global Fund has formally committed so far.
    let committed: Double?
    /// Amount actually paid out so far.
    let disbursed: Double?

    var disease: Disease { Disease(componentName: component) }

    var isActive: Bool {
        if let status = status?.lowercased() {
            if ["inactive", "closed", "terminated", "suspended"].contains(where: { status.contains($0) }) { return false }
            if status.contains("active") || status.contains("in progress") { return true }
        }
        if let endDate { return endDate >= Date() }
        return false
    }

    /// Share of the signed amount disbursed so far, 0...1 (capped for display).
    var disbursementRate: Double? {
        guard let signed, signed > 0, let disbursed else { return nil }
        return min(disbursed / signed, 1)
    }
}

extension Grant {
    init?(record: Record) {
        typealias F = APIConfig.Fields
        guard let number = record.string(F.grantNumber) ?? record.string(F.grantID) else { return nil }
        self.init(
            id: record.string(F.grantID) ?? number,
            number: number,
            country: record.string(F.country) ?? "Unknown",
            countryCode: record.string(F.countryCode),
            component: record.string(F.component) ?? "Unspecified",
            principalRecipient: record.string(F.principalRecipient),
            status: record.string(F.status),
            grantCycle: record.string(F.grantCycle),
            startDate: record.date(F.startDate),
            endDate: record.date(F.endDate),
            signed: record.double(F.signed),
            committed: record.double(F.committed),
            disbursed: record.double(F.disbursed)
        )
    }
}

/// Grant components grouped into the categories people usually compare.
enum Disease: String, CaseIterable, Identifiable, Sendable {
    case hiv = "HIV"
    case tuberculosis = "Tuberculosis"
    case malaria = "Malaria"
    case hivTB = "HIV/TB"
    case rssh = "RSSH"
    case other = "Other"

    var id: String { rawValue }

    init(componentName raw: String) {
        let name = raw.lowercased()
        let hasHIV = name.contains("hiv")
        let hasTB = name.contains("tuberculosis") || name.range(of: #"\btb\b"#, options: .regularExpression) != nil
        if hasHIV && hasTB {
            self = .hivTB
        } else if hasHIV {
            self = .hiv
        } else if hasTB {
            self = .tuberculosis
        } else if name.contains("malaria") {
            self = .malaria
        } else if name.contains("rssh") || name.contains("health system") {
            self = .rssh
        } else {
            self = .other
        }
    }
}
