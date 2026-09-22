import SwiftUI

@main
struct GlobalFundExplorerApp: App {
    @State private var store = GrantStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.loadIfNeeded() }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { CountryListView() }
                .tabItem { Label("Countries", systemImage: "globe") }

            NavigationStack { GrantSearchView() }
                .tabItem { Label("Grants", systemImage: "doc.text.magnifyingglass") }

            NavigationStack { SettingsView() }
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}
