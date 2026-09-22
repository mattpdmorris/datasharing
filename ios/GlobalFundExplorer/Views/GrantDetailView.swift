import SwiftUI
import Charts

struct GrantDetailView: View {
    @Environment(GrantStore.self) private var store
    let grant: Grant

    @State private var disbursements: [Disbursement] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            Section {
                LabeledContent("Country / area", value: grant.country)
                LabeledContent("Component", value: grant.component)
                if let pr = grant.principalRecipient {
                    LabeledContent("Principal recipient", value: pr)
                }
                if let status = grant.status {
                    LabeledContent("Status", value: status)
                }
                if let cycle = grant.grantCycle {
                    LabeledContent("Grant cycle", value: cycle)
                }
                LabeledContent("Programme period", value: "\(grant.startDate.shortDate) – \(grant.endDate.shortDate)")
            }

            Section {
                LabeledContent("Signed", value: grant.signed.usdFull)
                LabeledContent("Committed", value: grant.committed.usdFull)
                LabeledContent("Disbursed", value: grant.disbursed.usdFull)
                if let rate = grant.disbursementRate {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: rate)
                        Text("\(rate.percent) of the signed amount disbursed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Funding (USD, reference rate)")
            } footer: {
                Text("Signed is the grant agreement amount; committed is what the Global Fund has formally set aside; disbursed is what has actually been paid.")
            }

            Section("Disbursements") {
                disbursementContent
            }
        }
        .navigationTitle(grant.number)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: grant.id) { await load() }
    }

    @ViewBuilder
    private var disbursementContent: some View {
        if loading {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else if let error {
            VStack(alignment: .leading, spacing: 8) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Retry") { Task { await load() } }
            }
        } else if disbursements.isEmpty {
            Text("No disbursements reported yet.")
                .foregroundStyle(.secondary)
        } else {
            DisbursementChart(disbursements: disbursements)
                .frame(height: 200)
                .padding(.vertical, 8)
            ForEach(disbursements.reversed()) { d in
                LabeledContent {
                    Text(d.amount.usdFull).monospacedDigit()
                } label: {
                    Text(d.date.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            disbursements = try await store.disbursements(for: grant)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct DisbursementChart: View {
    let disbursements: [Disbursement]

    var body: some View {
        let points = disbursements.cumulative.map { CumulativePoint(date: $0.date, total: $0.total) }
        Chart {
            ForEach(disbursements) { d in
                BarMark(
                    x: .value("Date", d.date, unit: .month),
                    y: .value("Payment", d.amount)
                )
                .foregroundStyle(Color.accentColor.opacity(0.4))
            }
            ForEach(points) { p in
                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Cumulative", p.total)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(Color.accentColor)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) { Text(amount.usdCompact) }
                }
            }
        }
        .accessibilityLabel("Disbursements over time, bars show each payment and the line shows the running total")
    }
}

private struct CumulativePoint: Identifiable {
    let date: Date
    let total: Double
    var id: Date { date }
}

#Preview {
    NavigationStack {
        GrantDetailView(grant: SampleData.grants[0])
    }
    .environment(GrantStore(preview: SampleData.grants))
}
