import SwiftUI
import Charts

struct CountryDetailView: View {
    @Environment(GrantStore.self) private var store
    let country: CountrySummary
    @State private var activeOnly = false

    private var grantsByDisease: [(Disease, [Grant])] {
        let grants = activeOnly ? country.grants.filter(\.isActive) : country.grants
        return Dictionary(grouping: grants, by: \.disease)
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        List {
            Section {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        StatTile(title: "Signed", value: country.signed.usdCompact)
                        StatTile(title: "Disbursed", value: country.disbursed.usdCompact)
                    }
                    GridRow {
                        StatTile(title: "Grants", value: "\(country.grants.count)")
                        StatTile(title: "Active", value: "\(country.activeGrantCount)")
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Signed vs disbursed by component") {
                DiseaseChart(totals: country.totalsByDisease)
                    .frame(height: 220)
                    .padding(.vertical, 8)
            }

            Section {
                Toggle("Active grants only", isOn: $activeOnly)
            }

            ForEach(grantsByDisease, id: \.0) { disease, grants in
                Section {
                    ForEach(grants) { grant in
                        NavigationLink(value: grant) { GrantRow(grant: grant) }
                    }
                } header: {
                    Label(disease.rawValue, systemImage: disease.symbol)
                        .foregroundStyle(disease.color)
                }
            }
        }
        .navigationTitle(country.name)
        .toolbar {
            Button {
                store.togglePin(country)
            } label: {
                Image(systemName: store.isPinned(country) ? "pin.fill" : "pin")
            }
            .accessibilityLabel(store.isPinned(country) ? "Unpin country" : "Pin country")
        }
    }
}

struct DiseaseChart: View {
    let totals: [DiseaseTotal]

    var body: some View {
        Chart {
            ForEach(totals) { total in
                BarMark(
                    x: .value("Component", total.disease.rawValue),
                    y: .value("USD", total.signed)
                )
                .foregroundStyle(by: .value("Measure", "Signed"))
                .position(by: .value("Measure", "Signed"))

                BarMark(
                    x: .value("Component", total.disease.rawValue),
                    y: .value("USD", total.disbursed)
                )
                .foregroundStyle(by: .value("Measure", "Disbursed"))
                .position(by: .value("Measure", "Disbursed"))
            }
        }
        .chartForegroundStyleScale(["Signed": Color.accentColor.opacity(0.35), "Disbursed": Color.accentColor])
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) { Text(amount.usdCompact) }
                }
            }
        }
    }
}

struct GrantRow: View {
    let grant: Grant

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(grant.number)
                    .font(.subheadline.monospaced())
                Spacer()
                if grant.isActive {
                    Text("Active")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.15), in: Capsule())
                        .foregroundStyle(.green)
                }
            }
            if let pr = grant.principalRecipient {
                Text(pr)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HStack {
                Text("\(grant.startDate.shortDate) – \(grant.endDate.shortDate)")
                Spacer()
                Text("\(grant.disbursed.usdCompact) of \(grant.signed.usdCompact)")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        CountryDetailView(country: CountrySummary.group(SampleData.grants)[0])
            .navigationDestination(for: Grant.self) { GrantDetailView(grant: $0) }
    }
    .environment(GrantStore(preview: SampleData.grants))
}
