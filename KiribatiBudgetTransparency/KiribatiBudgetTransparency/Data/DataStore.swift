import Foundation
import Observation

@MainActor
@Observable
final class DataStore {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    /// Where a published copy can be fetched from once the data site carries
    /// Kiribati. The bundled copy is used until a newer one decodes cleanly.
    static let remoteURL = URL(string: "https://data.virtualeconomics.com/kiribati/budget/kiribati_budget.json")

    private(set) var state: LoadState = .loading
    private(set) var data: KiribatiData?
    private(set) var dataOrigin = "Bundled with the app"

    /// App-wide "show figures as" setting.
    var lens: Lens = .nominal

    init() {}

    func loadIfNeeded() async {
        guard data == nil else { return }
        do {
            let d = try await Task.detached(priority: .userInitiated) { () throws -> KiribatiData in
                try DataStore.decodeBundled()
            }.value
            data = d
            state = .ready
        } catch {
            state = .failed("The bundled budget record could not be read: \(error.localizedDescription)")
        }
        await refreshFromRemote()
    }

    func refreshFromRemote() async {
        guard let url = Self.remoteURL else { return }
        let req = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 15)
        guard let result = try? await URLSession.shared.data(for: req),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let remote = try? JSONDecoder().decode(KiribatiData.self, from: result.0)
        else { return }
        if let current = data, remote.generated <= current.generated { return }
        data = remote
        dataOrigin = "Updated from data.virtualeconomics.com"
        state = .ready
    }

    nonisolated private static func decodeBundled() throws -> KiribatiData {
        guard let url = Bundle.main.url(forResource: "kiribati_budget", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(KiribatiData.self, from: Data(contentsOf: url))
    }

    // MARK: Queries

    var headline: [HeadlineYear] { data?.headline ?? [] }

    /// Years with an original budget (2011 onward), for charts.
    var budgetYears: [HeadlineYear] { headline.filter(\.hasBudget) }

    func year(_ y: Int) -> HeadlineYear? { headline.first { $0.year == y } }

    var latestActualYear: HeadlineYear? { headline.last { $0.actual != nil } }
    var latestBudgetYear: HeadlineYear? { headline.last { $0.totalOperating != nil } }

    func reconciliation(_ y: Int) -> ReconciliationYear? { data?.reconciliation.first { $0.year == y } }

    var ministries: [Ministry] { data?.ministries ?? [] }

    var ministryYears: [Int] {
        Array(Set(ministries.flatMap { $0.facts.map(\.year) })).sorted()
    }

    func volume(_ y: Int) -> Volume? { data?.ministryVolumes[String(y)] }

    func check(_ y: Int) -> TotalCheck? { data?.ministryChecks.first { $0.year == y } }

    // MARK: Lenses

    func denominator(_ y: Int) -> Denominator? { data?.denominators[String(y)] }

    func transform(_ v: Double?, year: Int) -> Double? {
        guard let v else { return nil }
        return lens.apply(v, denominator(year))
    }

    func formatted(_ v: Double?, year: Int) -> String {
        guard v != nil else { return "—" }
        if lens == .nominal { return Fmt.short(v) }
        return Fmt.lens(transform(v, year: year), lens)
    }

    func denominatorIsProvisional(_ y: Int) -> Bool {
        guard let d = denominator(y) else { return false }
        switch lens {
        case .nominal: return false
        case .real: return (d.cpiMonths ?? 12) < 12
        case .gdp: return (d.gdpStatus ?? "a") != "a"
        case .share: return (d.imfExpStatus ?? "a") != "a"
        }
    }

    var lensNote: String {
        switch lens {
        case .nominal:
            return "Australian dollars, as printed in the budget volumes and Annual Accounts."
        case .real:
            return "Constant 2025 prices: deflated by the Kiribati National Statistics Office all-items consumer price index (annual average of the monthly index; 2025 uses January–September). 2026 cannot be deflated yet. Kiribati's CPI tracks import prices and the Australian dollar, so it barely moved 2011–2021 and then rose 17% in 2022–23."
        case .gdp:
            return "Divided by nominal GDP: KNSO national accounts to 2021, then the IMF's figures from 2022 (2024 onward are IMF estimates and projections). The two sources are chained, not reconciled."
        case .share:
            return "Divided by total central government expenditure as reported by the IMF — recurrent and development spending, including donor-financed projects. The recurrent budget is therefore well under 100% of it."
        }
    }
}
