import Foundation
import Observation

/// Loads the bundled budget record (and, if configured, a newer copy from the
/// Virtual Economics data site) and exposes it in the shapes the views need.
@MainActor
@Observable
final class DataStore {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    /// Where a published payload can be fetched from once the data site is
    /// live. The app always starts from the bundled copy and only swaps in a
    /// remote one that decodes cleanly and is newer.
    static let remotePayloadURL = URL(string: "https://data.virtualeconomics.com/png/budget/payload.json")

    private(set) var state: LoadState = .loading
    private(set) var payload: BudgetPayload?
    private(set) var dataOrigin: String = "Bundled with the app"

    private(set) var rowsByMeasure: [FiscalMeasure: [FiscalRow]] = [:]
    private(set) var agencies: [Agency] = []
    private(set) var sectors: [String] = []
    private(set) var editions: [Int] = []
    private(set) var projects: [PIPProject] = []
    private(set) var pipVolumes: [String] = []
    private(set) var anu: ANUData?

    /// How every figure in the app is shown. Shared by all tabs so a reader
    /// who switches to "% of GDP" sees it everywhere.
    var lens: Lens = .nominal
    var deflator: Deflator = .cpi

    init() {}

    /// For previews: build a store from an already decoded payload.
    init(payload: BudgetPayload) {
        apply(payload, origin: "Preview")
    }

    // MARK: Loading

    func loadIfNeeded() async {
        guard payload == nil else { return }
        do {
            let p = try await Task.detached(priority: .userInitiated) { () throws -> BudgetPayload in
                try DataStore.decodeBundled()
            }.value
            apply(p, origin: "Bundled with the app")
            anu = try? await Task.detached(priority: .userInitiated, operation: { try DataStore.loadBundledANU() }).value
            if let pip = try? await Task.detached(priority: .utility, operation: { try DataStore.loadBundledProjects() }).value {
                projects = pip.projects
                pipVolumes = pip.volumes
            }
            state = .ready
        } catch {
            state = .failed("The bundled budget record could not be read: \(error.localizedDescription)")
        }
        await refreshFromRemote()
    }

    /// Try the published payload; keep the current one on any failure.
    func refreshFromRemote() async {
        guard let url = Self.remotePayloadURL else { return }
        var req = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 15)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let result = try? await URLSession.shared.data(for: req),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let remote = try? JSONDecoder().decode(BudgetPayload.self, from: result.0)
        else { return }
        if let current = payload, remote.generated <= current.generated { return }
        apply(remote, origin: "Updated from data.virtualeconomics.com")
        state = .ready
    }

    nonisolated private static func decodeBundled() throws -> BudgetPayload {
        guard let url = Bundle.main.url(forResource: "budget_payload", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(BudgetPayload.self, from: Data(contentsOf: url))
    }

    private func apply(_ p: BudgetPayload, origin: String) {
        payload = p
        dataOrigin = origin

        var rows: [FiscalMeasure: [FiscalRow]] = [:]
        for r in p.fiscal {
            guard let m = FiscalMeasure(rawValue: r.measure) else { continue }
            rows[m, default: []].append(FiscalRow(record: r))
        }
        rowsByMeasure = rows.mapValues { $0.sorted { $0.year < $1.year } }

        var byAgency: [Int: [AgencyFact]] = [:]
        for raw in p.facts {
            guard let f = AgencyFact(raw) else { continue }
            byAgency[f.agencyIndex, default: []].append(f)
        }
        agencies = p.agencies.map { Agency(ref: $0, facts: byAgency[$0.i] ?? []) }
        sectors = Array(Set(p.agencies.map(\.sector))).sorted()
        editions = Array(Set(byAgency.values.flatMap { $0.map(\.edition) })).sorted()
        if state == .loading { state = .ready }
    }

    // MARK: Queries

    func rows(_ m: FiscalMeasure) -> [FiscalRow] { rowsByMeasure[m] ?? [] }

    func row(_ m: FiscalMeasure, year: Int) -> FiscalRow? {
        rows(m).first { $0.year == year }
    }

    var years: [Int] {
        Array(Set(rowsByMeasure.values.flatMap { $0.map(\.year) })).sorted()
    }

    /// Latest year that has an outturn for expenditure.
    var latestOutturnYear: Int? {
        rows(.expenditure).last { $0.outturn != nil }?.year
    }

    func denominator(_ year: Int) -> Denominator? { payload?.denominators[String(year)] }

    func volumeName(_ index: Int) -> String {
        guard let v = payload?.volumes, v.indices.contains(index) else { return "Budget volume" }
        return v[index]
    }

    /// Sum of each agency's appropriation in an edition's own budget year, by sector.
    /// Public Debt Charges are left out unless asked for: they print gross debt
    /// service, including Treasury bill redemptions, which is not spending.
    func sectorTotals(edition: Int, includeDebtCharges: Bool = false) -> [SectorTotal] {
        var totals: [String: Double] = [:]
        for a in agencies where includeDebtCharges || !a.isDebtCharges {
            if let f = a.facts.first(where: { $0.series == .appropriation && $0.edition == edition && $0.refYear == edition }) {
                totals[a.sector, default: 0] += f.value
            }
        }
        return totals.map { SectorTotal(sector: $0.key, value: $0.value) }.sorted { $0.value > $1.value }
    }

    func agencies(in sector: String?, edition: Int) -> [Agency] {
        agencies
            .filter { sector == nil || $0.sector == sector }
            .filter { a in a.facts.contains { $0.edition == edition } }
    }

    // MARK: Lenses (ANU denominators)

    func anuYear(_ year: Int) -> ANUData.Year? { anu?.year(year) }

    /// A K-million figure for `year` in the current lens; nil when the ANU
    /// denominator for that year is missing.
    func transform(_ value: Double?, year: Int) -> Double? {
        guard let value else { return nil }
        return lens.apply(value, anuYear(year), deflator: deflator)
    }

    func formatted(_ value: Double?, year: Int) -> String {
        guard value != nil else { return "—" }
        return Fmt.lens(transform(value, year: year), lens)
    }

    /// True when the denominator used for `year` is an ANU estimate or projection.
    func denominatorIsProvisional(_ year: Int) -> Bool {
        guard let d = anuYear(year) else { return false }
        switch lens {
        case .nominal: return false
        case .real: return deflator == .cpi ? d.cpiStatus != "a" : (d.gdpStatus ?? "a") != "a"
        case .gdp: return (d.gdpStatus ?? "a") != "a"
        case .share: return (d.expStatus ?? "a") != "a"
        }
    }

    var lensNote: String {
        let src = anu.map { "ANU Development Policy Centre / UPNG PNG National Budget Database (\($0.source.edition))" }
            ?? "ANU PNG National Budget Database"
        switch lens {
        case .nominal:
            return "As printed in the source documents."
        case .real:
            return deflator == .cpi
                ? "Constant 2025 prices: deflated by consumer prices, chained from annual-average CPI inflation in the \(src), 2025 = 100. 2024 is an estimate and 2025 onward are Treasury projections. A transformation, not a printed figure."
                : "Constant 2025 prices: deflated by the GDP deflator from the \(src), 2025 = 100. PNG's GDP deflator moves with LNG and mineral prices, so it can differ sharply from consumer prices. A transformation, not a printed figure."
        case .gdp:
            return "Divided by nominal GDP from the \(src) (new NSO series; 2005–06 from the ANU PNG Economic Database so old and new GDP series are never mixed). 2024 is an estimate and 2025 onward are projections."
        case .share:
            return "Divided by total general government expenditure and net lending for the same year, from the \(src): actual outturn to 2024, 2025 estimate, 2026 onward projections. For the Expenditure measure, 100% is what was actually spent."
        }
    }

    // MARK: Optional PIP projects

    nonisolated private static func loadBundledANU() throws -> ANUData? {
        guard let url = Bundle.main.url(forResource: "anu_denominators", withExtension: "json") else { return nil }
        return try JSONDecoder().decode(ANUData.self, from: Data(contentsOf: url))
    }

    nonisolated private static func loadBundledProjects() throws -> PIPData? {
        guard let url = Bundle.main.url(forResource: "pip_projects", withExtension: "json") else { return nil }
        return try PIPData.decode(Data(contentsOf: url))
    }

    func pipVolumeName(_ index: Int) -> String {
        pipVolumes.indices.contains(index) ? pipVolumes[index] : "Budget Volume 3"
    }
}
