import SwiftUI
import Charts

/// Pledges and contributions to the Global Fund, by replenishment period and donor.
struct DonorsView: View {
    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().pledgesAndContributions() }) { rows in
            if rows.isEmpty {
                ContentUnavailableView("No pledge data", systemImage: "building.columns", description: Text("No pledges or contributions were returned."))
            } else {
                DonorsContent(rows: rows)
            }
        }
        .navigationTitle("Donors")
    }
}

private struct DonorsContent: View {
    let rows: [PledgeRow]

    @State private var period: String?
    @State private var query = ""

    private var periods: [PledgeTotal] {
        rows.totals(by: { $0.period }).sorted { $0.name < $1.name }
    }

    private var donorTotals: [PledgeTotal] {
        rows.filter { period == nil || $0.period == period }
            .totals(by: { $0.donor }, detail: { $0.donorType })
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || ($0.detail ?? "").localizedCaseInsensitiveContains(query) }
            .sorted { $0.pledged > $1.pledged }
    }

    var body: some View {
        let donors = donorTotals
        List {
            if query.isEmpty {
                Section {
                    Chart {
                        ForEach(periods) { p in
                            BarMark(x: .value("Period", p.name), y: .value("USD", p.pledged))
                                .foregroundStyle(by: .value("Measure", "Pledged"))
                                .position(by: .value("Measure", "Pledged"))
                            BarMark(x: .value("Period", p.name), y: .value("USD", p.contributed))
                                .foregroundStyle(by: .value("Measure", "Contributed"))
                                .position(by: .value("Measure", "Contributed"))
                        }
                    }
                    .chartForegroundStyleScale(["Pledged": Color.accentColor.opacity(0.35), "Contributed": Color.accentColor])
                    .usdYAxis()
                    .frame(height: 240)
                    .padding(.vertical, 8)
                } header: {
                    Text("By replenishment period")
                } footer: {
                    Text("Pledges are what donors promise for a replenishment period; contributions are what they have paid so far.")
                }
            }

            Section {
                Picker("Period", selection: $period) {
                    Text("All periods").tag(String?.none)
                    ForEach(periods.reversed()) { p in
                        Text(p.name).tag(String?.some(p.name))
                    }
                }
                let pledged = donors.reduce(0) { $0 + $1.pledged }
                let contributed = donors.reduce(0) { $0 + $1.contributed }
                LabeledContent("Pledged", value: pledged.usdCompact)
                LabeledContent("Contributed", value: contributed.usdCompact)
            }

            Section("\(donors.count) donors") {
                ForEach(donors.prefix(300)) { donor in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(donor.name).font(.headline)
                            Spacer()
                            Text(donor.pledged.usdCompact).font(.subheadline.monospacedDigit())
                        }
                        HStack(spacing: 8) {
                            if let type = donor.detail {
                                Text(type)
                            }
                            Spacer()
                            if let share = donor.paidShare {
                                ProgressView(value: share).frame(width: 60)
                                Text("\(share.percent) paid").monospacedDigit()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .searchable(text: $query, prompt: "Donor or donor type")
    }
}
