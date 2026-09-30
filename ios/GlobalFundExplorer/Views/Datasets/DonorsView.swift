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
    /// Donor whose history table is shown at the top of the list.
    @State private var selectedDonor: String?

    private var periods: [PledgeTotal] {
        rows.totals(by: { $0.period }).sorted { $0.name < $1.name }
    }

    private var donorTotals: [PledgeTotal] {
        rows.filter { period == nil || $0.period == period }
            .totals(by: { $0.donor }, detail: { $0.donorType })
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || ($0.detail ?? "").localizedCaseInsensitiveContains(query) }
            .sorted { $0.pledged > $1.pledged }
    }

    private static let topID = "top"

    var body: some View {
        let donors = donorTotals
        ScrollViewReader { proxy in
            List {
                if let selectedDonor {
                    DonorHistorySection(
                        donor: selectedDonor,
                        rows: rows.filter { $0.donor == selectedDonor },
                        onClose: { withAnimation { self.selectedDonor = nil } }
                    )
                    .id(Self.topID)
                }

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

                Section {
                    ForEach(donors.prefix(300)) { donor in
                        Button {
                            withAnimation {
                                selectedDonor = selectedDonor == donor.name ? nil : donor.name
                            }
                        } label: {
                            DonorRow(donor: donor, isSelected: donor.name == selectedDonor)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(donors.count) donors")
                } footer: {
                    Text("Tap a donor to see its pledges and payments for every replenishment period.")
                }
            }
            .onChange(of: selectedDonor) { _, newValue in
                // Bring the history table into view once it has been inserted.
                if newValue != nil {
                    withAnimation { proxy.scrollTo(Self.topID, anchor: .top) }
                }
            }
        }
        .searchable(text: $query, prompt: "Donor or donor type")
    }
}

private struct DonorRow: View {
    let donor: PledgeTotal
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Selected")
                }
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
        .contentShape(Rectangle())
    }
}

/// One donor's pledges and payments for every replenishment period: a grouped
/// bar chart (tap a period for its figures), totals, and an optional table.
private struct DonorHistorySection: View {
    let donor: String
    let rows: [PledgeRow]
    let onClose: () -> Void

    @State private var selectedPeriod: String?
    @State private var showTable = false

    /// Oldest first, so the chart reads left to right in time.
    private var chronological: [PledgeRow] { rows.sorted { $0.period < $1.period } }
    private var pledged: Double { rows.reduce(0) { $0 + $1.pledged } }
    private var paid: Double { rows.reduce(0) { $0 + $1.contributed } }

    var body: some View {
        Section {
            chart
                .frame(height: 220)
                .padding(.vertical, 8)

            Grid(alignment: .leading, horizontalSpacing: 16) {
                GridRow {
                    StatTile(title: "Pledged", value: pledged.usdCompact)
                    StatTile(title: "Paid", value: paid.usdCompact)
                    StatTile(title: "% paid", value: share(paid, of: pledged))
                }
            }

            DisclosureGroup("Show as table", isExpanded: $showTable) {
                table
            }
        } header: {
            HStack {
                Text(donor)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.large)
                }
                .accessibilityLabel("Close \(donor) history")
            }
        } footer: {
            if let type = rows.first?.donorType {
                Text("\(type) · US dollars at the Global Fund reference rate. Tap a period to see its figures. Paid is contributions received to date against that period's pledge.")
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(chronological) { row in
                BarMark(x: .value("Period", row.period), y: .value("USD", row.pledged))
                    .foregroundStyle(by: .value("Measure", "Pledged"))
                    .position(by: .value("Measure", "Pledged"))
                    .cornerRadius(3)
                BarMark(x: .value("Period", row.period), y: .value("USD", row.contributed))
                    .foregroundStyle(by: .value("Measure", "Paid"))
                    .position(by: .value("Measure", "Paid"))
                    .cornerRadius(3)
            }
            if let period = selectedPeriod, let row = chronological.first(where: { $0.period == period }) {
                RuleMark(x: .value("Period", period))
                    .foregroundStyle(Color.secondary.opacity(0.25))
                    .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        callout(for: row)
                    }
            }
        }
        .chartForegroundStyleScale(["Pledged": Color.accentColor.opacity(0.35), "Paid": Color.accentColor])
        .chartXSelection(value: $selectedPeriod)
        .usdYAxis()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(donor) pledged and paid by replenishment period")
    }

    private func callout(for row: PledgeRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.period).font(.caption.weight(.semibold))
            Text("Pledged \(row.pledged.usdCompact)")
            Text("Paid \(row.contributed.usdCompact) · \(share(row.contributed, of: row.pledged))")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.primary)
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }

    private var table: some View {
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("Period").gridColumnAlignment(.leading)
                Text("Pledged")
                Text("Paid")
                Text("% paid")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)

            Divider()

            ForEach(chronological.reversed()) { row in
                GridRow {
                    Text(row.period)
                    Text(row.pledged.usdCompact)
                    Text(row.contributed.usdCompact)
                    Text(share(row.contributed, of: row.pledged))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline.monospacedDigit())
        .padding(.vertical, 4)
    }

    private func share(_ part: Double, of whole: Double) -> String {
        whole > 0 ? (part / whole).percent : "—"
    }
}
