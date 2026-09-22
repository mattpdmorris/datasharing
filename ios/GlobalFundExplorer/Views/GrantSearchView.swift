import SwiftUI

/// Search across every grant by number, country, principal recipient or component.
struct GrantSearchView: View {
    @Environment(GrantStore.self) private var store
    @State private var query = ""
    @State private var disease: Disease?
    @State private var activeOnly = true

    private var results: [Grant] {
        store.grants
            .filter { !activeOnly || $0.isActive }
            .filter { disease == nil || $0.disease == disease }
            .filter { grant in
                guard !query.isEmpty else { return true }
                return [grant.number, grant.country, grant.component, grant.principalRecipient ?? ""]
                    .contains { $0.localizedCaseInsensitiveContains(query) }
            }
            .sorted { ($0.signed ?? 0) > ($1.signed ?? 0) }
    }

    var body: some View {
        let matches = results
        let signedTotal = matches.reduce(0.0) { $0 + ($1.signed ?? 0) }
        List {
            Section {
                Picker("Component", selection: $disease) {
                    Text("All").tag(Disease?.none)
                    ForEach(Disease.allCases) { d in
                        Text(d.rawValue).tag(Disease?.some(d))
                    }
                }
                Toggle("Active grants only", isOn: $activeOnly)
            }

            Section("\(matches.count) grants · \(signedTotal.usdCompact) signed") {
                // Rendering thousands of rows is fine in a List, but cap it to keep search snappy.
                ForEach(matches.prefix(500)) { grant in
                    NavigationLink(value: grant) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(grant.country).font(.headline)
                            GrantRow(grant: grant)
                        }
                    }
                }
            }
        }
        .navigationTitle("Grants")
        .navigationDestination(for: Grant.self) { GrantDetailView(grant: $0) }
        .searchable(text: $query, prompt: "Grant number, country, recipient")
        .overlay {
            if store.state == .loading && store.grants.isEmpty {
                ProgressView()
            }
        }
    }
}

#Preview {
    NavigationStack { GrantSearchView() }
        .environment(GrantStore(preview: SampleData.grants))
}
