import SwiftUI
import Charts

/// Annual programmatic results: people treated, tested, reached and so on.
/// Global when `countryCode` is nil (used by the Results tab), otherwise one country.
struct ResultsView: View {
    var countryCode: String?

    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().results(countryCode: countryCode) }) { rows in
            if rows.isEmpty {
                ContentUnavailableView("No results", systemImage: "chart.line.uptrend.xyaxis", description: Text("No annual results are published for this selection."))
            } else {
                ResultsContent(rows: rows, isGlobal: countryCode == nil)
            }
        }
        .navigationTitle("Results")
    }
}

private struct ResultsContent: View {
    let rows: [ResultRow]
    let isGlobal: Bool

    @State private var year: Int?
    @State private var disease: Disease?

    private var years: [Int] { Array(Set(rows.map(\.year))).sorted(by: >) }
    private var selectedYear: Int { year ?? years.first ?? 0 }

    private var yearRows: [ResultRow] {
        rows.filter { $0.year == selectedYear && (disease == nil || $0.disease == disease) }
            .sorted { $0.value > $1.value }
    }

    var body: some View {
        List {
            Section {
                Picker("Year", selection: Binding(get: { selectedYear }, set: { year = $0 })) {
                    ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                }
                Picker("Component", selection: $disease) {
                    Text("All").tag(Disease?.none)
                    ForEach(Disease.allCases) { d in
                        Text(d.rawValue).tag(Disease?.some(d))
                    }
                }
            } footer: {
                Text(isGlobal
                    ? "Results achieved in countries where the Global Fund invests, summed across countries."
                    : "Results reported for this country or area.")
            }

            Section("\(String(selectedYear)) · \(yearRows.count) indicators") {
                ForEach(yearRows) { row in
                    NavigationLink {
                        IndicatorTrendView(indicator: row.indicator, rows: rows.filter { $0.indicator == row.indicator && $0.component == row.component })
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.indicator)
                                Text(row.component)
                                    .font(.caption)
                                    .foregroundStyle(row.disease.color)
                            }
                            Spacer()
                            Text(row.value.countCompact)
                                .font(.headline.monospacedDigit())
                        }
                    }
                }
            }
        }
    }
}

/// One indicator over time.
private struct IndicatorTrendView: View {
    let indicator: String
    let rows: [ResultRow]

    private var sorted: [ResultRow] { rows.sorted { $0.year < $1.year } }

    var body: some View {
        List {
            Section {
                Chart(sorted) { row in
                    BarMark(
                        x: .value("Year", String(row.year)),
                        y: .value("Value", row.value)
                    )
                    .foregroundStyle(row.disease.color)
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) { Text(v.countCompact) }
                        }
                    }
                }
                .frame(height: 220)
                .padding(.vertical, 8)
            } header: {
                Text(indicator)
            }

            Section {
                ForEach(sorted.reversed()) { row in
                    LabeledContent(String(row.year)) {
                        Text(row.value.formatted(.number.precision(.fractionLength(0))))
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("Trend")
        .navigationBarTitleDisplayMode(.inline)
    }
}
