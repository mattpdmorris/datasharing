import SwiftUI

struct CountryListView: View {
    @Environment(GrantStore.self) private var store
    @State private var query = ""

    private var filtered: [CountrySummary] {
        guard !query.isEmpty else { return store.countries }
        return store.countries.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        content
            .navigationTitle("Global Fund")
            .navigationDestination(for: CountrySummary.self) { CountryDetailView(country: $0) }
            .navigationDestination(for: Grant.self) { GrantDetailView(grant: $0) }
            .searchable(text: $query, prompt: "Search countries")
            .refreshable { await store.refresh() }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading where store.countries.isEmpty:
            ProgressView("Loading grants…")
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load data", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Try again") { Task { await store.refresh() } }
                    .buttonStyle(.borderedProminent)
            }
        default:
            list
        }
    }

    private var list: some View {
        List {
            if let error = store.lastError {
                Section {
                    Label("Showing saved data. Refresh failed: \(error)", systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if query.isEmpty {
                Section {
                    PortfolioHeader(
                        signed: store.totalSigned,
                        disbursed: store.totalDisbursed,
                        countries: store.countries.count,
                        grants: store.grants.count
                    )
                }
            }

            let pinned = filtered.filter { store.isPinned($0) }
            if !pinned.isEmpty {
                Section("Pinned") {
                    ForEach(pinned) { row($0) }
                }
            }

            Section(query.isEmpty ? "All countries and areas" : "Results") {
                ForEach(filtered) { row($0) }
            }

            if let updated = store.lastUpdated {
                Section {
                    Text("Updated \(updated.formatted(.relative(presentation: .named))) · Source: The Global Fund Data Service")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if !query.isEmpty && filtered.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func row(_ country: CountrySummary) -> some View {
        NavigationLink(value: country) {
            CountryRow(country: country)
        }
        .swipeActions {
            Button {
                store.togglePin(country)
            } label: {
                store.isPinned(country)
                    ? Label("Unpin", systemImage: "pin.slash")
                    : Label("Pin", systemImage: "pin")
            }
            .tint(.yellow)
        }
    }
}

private struct CountryRow: View {
    let country: CountrySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(country.name).font(.headline)
                Spacer()
                Text(country.signed.usdCompact)
                    .font(.subheadline.monospacedDigit())
            }
            HStack(spacing: 8) {
                Text("\(country.grants.count) grants · \(country.activeGrantCount) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let rate = country.disbursementRate {
                    ProgressView(value: rate)
                        .frame(width: 60)
                    Text(rate.percent)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct PortfolioHeader: View {
    let signed: Double
    let disbursed: Double
    let countries: Int
    let grants: Int

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                StatTile(title: "Signed", value: signed.usdCompact)
                StatTile(title: "Disbursed", value: disbursed.usdCompact)
            }
            GridRow {
                StatTile(title: "Countries/areas", value: "\(countries)")
                StatTile(title: "Grants", value: "\(grants)")
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold().monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack { CountryListView() }
        .environment(GrantStore(preview: SampleData.grants))
}
