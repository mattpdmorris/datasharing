import SwiftUI
import Charts

/// 2026 Development Budget by donor (Table 3 of the development budget volume).
struct DonorsView: View {
    @Environment(DataStore.self) private var store
    @State private var column = "2026 Budget"

    private var table: DonorTable? { store.data?.donors2026 }

    private var yearForColumn: Int {
        Int(column.prefix(4)) ?? 2026
    }

    private var rows: [DonorTable.Row] {
        guard let t = table else { return [] }
        return t.donors
            .filter { (t.value($0, column) ?? 0) != 0 }
            .sorted { (t.value($0, column) ?? 0) > (t.value($1, column) ?? 0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let t = table {
                    Section {
                        Picker("Column", selection: $column) {
                            ForEach(t.columns.filter { $0 != "Total Project Cost" && !$0.contains("Balance") && !$0.contains("Bal ") }, id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        if let g = t.grandTotal {
                            LabeledContent("Grand total", value: store.lens == .nominal ? Fmt.dollars(t.value(g, column))
                                                                                      : store.formatted(t.value(g, column), year: yearForColumn))
                        }
                        DonorChart(rows: Array(rows.prefix(10)), table: t, column: column, year: yearForColumn)
                            .frame(height: 260)
                        LensPicker()
                        if store.lens == .real && yearForColumn > 2025 {
                            Explainer(text: "No price index exists yet for \(yearForColumn), so constant-price figures are not available for this column.")
                        }
                    } header: {
                        Text("2026 Development Budget by donor").textCase(nil)
                    } footer: {
                        Text("Table 3 of the 2026 development budget. Government of Kiribati and \"Other\" lines together make the locally funded part. Figures are as printed; all columns sum to the printed total within A$5. The table does not reconcile to the budget's estimated totals.")
                    }

                    Section("\(rows.count) donors with an amount") {
                        ForEach(rows) { r in
                            NavigationLink(value: r) {
                                HStack {
                                    Text(r.donor)
                                    Spacer()
                                    Text(store.lens == .nominal ? Fmt.short(t.value(r, column))
                                                                : store.formatted(t.value(r, column), year: yearForColumn))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
                Section { PoweredByFooter() }
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("Donors")
            .navigationDestination(for: DonorTable.Row.self) { r in
                if let t = table { DonorDetailView(row: r, table: t) }
            }
        }
    }
}

private struct DonorChart: View {
    @Environment(DataStore.self) private var store
    let rows: [DonorTable.Row]
    let table: DonorTable
    let column: String
    let year: Int

    private struct Bar: Identifiable { let name: String; let value: Double; var id: String { name } }

    var body: some View {
        let bars = rows.compactMap { r in
            store.transform(table.value(r, column), year: year).map { Bar(name: r.donor, value: $0) }
        }
        Chart(bars) { b in
            BarMark(x: .value(store.lens.axisLabel, b.value), y: .value("Donor", b.name))
                .foregroundStyle(Brand.blue)
                .annotation(position: .trailing) {
                    Text(Fmt.lens(b.value, store.lens)).font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartXAxis(.hidden)
        .accessibilityLabel("Largest donors")
    }
}

private struct DonorDetailView: View {
    let row: DonorTable.Row
    let table: DonorTable

    var body: some View {
        List {
            Section {
                ForEach(Array(table.columns.enumerated()), id: \.offset) { i, c in
                    LabeledContent(c, value: row.values.indices.contains(i) ? Fmt.dollars(row.values[i]) : "—")
                        .monospacedDigit()
                }
            } footer: {
                Text(table.source ?? "")
            }
        }
        .navigationTitle(row.donor)
    }
}
