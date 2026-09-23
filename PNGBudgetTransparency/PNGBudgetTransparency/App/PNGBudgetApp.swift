import SwiftUI

@main
struct PNGBudgetApp: App {
    @State private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .task { await store.loadIfNeeded() }
        }
    }
}

struct RootView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        switch store.state {
        case .loading:
            LaunchView()
        case .failed(let message):
            ContentUnavailableView("Budget record unavailable",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text(message))
        case .ready:
            MainTabs()
        }
    }
}

struct MainTabs: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Overview", systemImage: "chart.bar.xaxis") }
            AgenciesView()
                .tabItem { Label("Agencies", systemImage: "building.columns") }
            if !store.projects.isEmpty {
                ProjectsView()
                    .tabItem { Label("Projects", systemImage: "hammer") }
            }
            IntegrityView()
                .tabItem { Label("Integrity", systemImage: "checkmark.seal") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}

struct LaunchView: View {
    var body: some View {
        VStack(spacing: 20) {
            BrandMark(size: 72)
            VStack(spacing: 6) {
                Text(Brand.appName)
                    .font(.title2.weight(.semibold))
                Text(Brand.poweredBy)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView()
        }
        .padding()
    }
}
