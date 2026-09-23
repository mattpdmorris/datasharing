import SwiftUI

struct SettingsView: View {
    @Environment(GrantStore.self) private var store
    @AppStorage(APIConfig.baseURLDefaultsKey) private var baseURL = APIConfig.defaultBaseURL
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Global Fund Explorer").font(.headline)
                    PoweredByTagline()
                }
                Text("Global Fund Explorer shows grants, disbursements, allocations, budgets, expenditure, results, eligibility, funding requests, documents and donor pledges published by the Global Fund to Fight AIDS, Tuberculosis and Malaria.")
                Link("The Global Fund Data Service", destination: URL(string: "https://data-service.theglobalfund.org")!)
            } header: {
                Text("About")
            } footer: {
                Text("Data: The Global Fund. This app is independent and is not endorsed by the Global Fund. Check the Data Service's terms of use for licence and attribution requirements.")
            }

            Section {
                LabeledContent("Grants loaded", value: "\(store.grants.count)")
                LabeledContent("Last updated", value: store.lastUpdated.shortDate)
                Button("Refresh now") { Task { await store.refresh() } }
                    .disabled(store.state == .loading)
                Button("Clear saved data", role: .destructive) { confirmClear = true }
            } header: {
                Text("Data")
            }

            Section {
                TextField("Base URL", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.footnote.monospaced())
                Button("Reset to default") { baseURL = APIConfig.defaultBaseURL }
            } header: {
                Text("API")
            } footer: {
                Text("Change this if the Global Fund releases a new API version (e.g. /v4/odata/), then tap Refresh now.")
            }
        }
        .navigationTitle("About")
        .confirmationDialog("Clear saved data?", isPresented: $confirmClear) {
            Button("Clear and reload", role: .destructive) {
                store.clearCache()
                Task { await store.loadIfNeeded() }
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(GrantStore(preview: SampleData.grants))
}
