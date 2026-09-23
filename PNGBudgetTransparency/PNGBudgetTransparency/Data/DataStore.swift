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

    // MARK: Optional PIP projects

    nonisolated private static func loadBundledProjects() throws -> PIPData? {
        guard let url = Bundle.main.url(forResource: "pip_projects", withExtension: "json") else { return nil }
        return try PIPData.decode(Data(contentsOf: url))
    }

    func pipVolumeName(_ index: Int) -> String {
        pipVolumes.indices.contains(index) ? pipVolumes[index] : "Budget Volume 3"
    }
}
