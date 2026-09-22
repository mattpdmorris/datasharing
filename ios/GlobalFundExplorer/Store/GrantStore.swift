import Foundation
import Observation

/// App-wide data store: loads grants (from the on-device cache, then the API),
/// derives country summaries, caches disbursements per grant, and keeps pins.
@MainActor
@Observable
final class GrantStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var grants: [Grant] = []
    private(set) var countries: [CountrySummary] = []
    private(set) var state: LoadState = .idle
    private(set) var lastUpdated: Date? = nil
    private(set) var pinned: Set<String>
    /// Most recent refresh error, shown as a banner when cached data is still on screen.
    private(set) var lastError: String? = nil

    private var disbursementCache: [String: [Disbursement]] = [:]
    private let cache: DiskCache
    private let makeAPI: () -> GlobalFundAPI

    /// Grant data changes slowly; refresh at most once a day unless the user pulls to refresh.
    private let maxCacheAge: TimeInterval = 24 * 60 * 60
    private static let pinnedKey = "pinnedCountries"

    init(cache: DiskCache = DiskCache(), makeAPI: @escaping () -> GlobalFundAPI = { GlobalFundAPI() }) {
        self.cache = cache
        self.makeAPI = makeAPI
        self.pinned = Set(UserDefaults.standard.stringArray(forKey: Self.pinnedKey) ?? [])
    }

    /// For SwiftUI previews and tests.
    init(preview grants: [Grant]) {
        self.cache = DiskCache(fileName: "preview-grants.json")
        self.makeAPI = { GlobalFundAPI() }
        self.pinned = []
        apply(grants, updated: Date())
    }

    // MARK: Loading

    func loadIfNeeded() async {
        guard state == .idle else { return }
        if let cached = cache.load() {
            apply(cached.grants, updated: cached.savedAt)
            if Date().timeIntervalSince(cached.savedAt) < maxCacheAge { return }
        }
        await refresh()
    }

    func refresh() async {
        state = .loading
        do {
            let fresh = try await makeAPI().grants()
            apply(fresh, updated: Date())
            cache.save(fresh)
            disbursementCache.removeAll()
        } catch {
            // Keep showing cached data if we have it; surface the error either way.
            state = grants.isEmpty ? .failed(error.localizedDescription) : .loaded
            lastError = error.localizedDescription
        }
    }

    func clearCache() {
        cache.clear()
        disbursementCache.removeAll()
        grants = []
        countries = []
        lastUpdated = nil
        state = .idle
    }

    private func apply(_ grants: [Grant], updated: Date) {
        self.grants = grants
        self.countries = CountrySummary.group(grants)
        self.lastUpdated = updated
        self.state = .loaded
        self.lastError = nil
    }

    // MARK: Disbursements

    func disbursements(for grant: Grant) async throws -> [Disbursement] {
        if let cached = disbursementCache[grant.number] { return cached }
        let result = try await makeAPI().disbursements(forGrantNumber: grant.number)
        disbursementCache[grant.number] = result
        return result
    }

    // MARK: Pins

    func isPinned(_ country: CountrySummary) -> Bool { pinned.contains(country.name) }

    func togglePin(_ country: CountrySummary) {
        if pinned.contains(country.name) {
            pinned.remove(country.name)
        } else {
            pinned.insert(country.name)
        }
        UserDefaults.standard.set(Array(pinned).sorted(), forKey: Self.pinnedKey)
    }

    // MARK: Aggregates

    var totalSigned: Double { countries.reduce(0) { $0 + $1.signed } }
    var totalDisbursed: Double { countries.reduce(0) { $0 + $1.disbursed } }
}
