import SwiftUI

/// Everything the record holds for one fiscal year: the budgeted figure, each
/// official outturn, every later restatement, and the cross-checks — each
/// with the document and page it was read from.
struct YearDetailView: View {
    @Environment(DataStore.self) private var store
    let year: Int

    var body: some View {
        List {
            ForEach(FiscalMeasure.allCases) { m in
                if let row = store.row(m, year: year) {
                    MeasureYearSection(measure: m, row: row)
                }
            }
            if let d = store.denominator(year) {
                Section("Context") {
                    if let gdp = d.gdpPrimary {
                        LabeledContent("Nominal GDP", value: Fmt.kinaMillions(gdp))
                        if let src = d.gdpPrimarySrc {
                            Text(src).font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No primary GDP figure is held for \(String(year)), so % of GDP is not shown.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if let cpi = d.cpi2025 {
                        LabeledContent("CPI (2025 = 100)", value: String(format: "%.1f", cpi))
                        if d.isChainLinked {
                            FlagBadge(text: "Chain-linked across 2012 basket change", style: .info)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(year))
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct MeasureYearSection: View {
    let measure: FiscalMeasure
    let row: FiscalRow

    var body: some View {
        Section {
            ReadingRow(title: "Budgeted", reading: row.record.budgeted)

            if let fbo = row.record.outturn {
                ReadingRow(title: "Outturn (Final Budget Outcome)", reading: fbo)
            }
            if let later = row.record.outturnBudget {
                ReadingRow(title: row.record.outturn == nil ? "Outturn (later Budget, \"Actual\")"
                                                            : "Actual, as reprinted in a later Budget",
                           reading: later,
                           note: row.outturnsDisagree
                               ? "Differs from the Final Budget Outcome by \(Fmt.signedKina((later.value ?? 0) - (row.fboOutturn ?? 0))). Both are shown; neither is chosen silently."
                               : nil)
            }
            if row.outturn == nil {
                Text("No outturn has been published for \(String(row.year)) in the documents held.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let e = row.execution, measure != .balance {
                LabeledContent("Outturn ÷ budget", value: Fmt.percent(e, digits: 1))
            }

            if !row.record.later.isEmpty {
                DisclosureGroup("How later budgets restated \(String(row.year)) (\(row.record.later.count))") {
                    ForEach(Array(row.record.later.enumerated()), id: \.offset) { _, r in
                        ReadingRow(title: seriesTitle(r), reading: r)
                    }
                }
            }
            if !row.record.checks.isEmpty {
                DisclosureGroup("Cross-checks (\(row.record.checks.count))") {
                    ForEach(Array(row.record.checks.enumerated()), id: \.offset) { _, r in
                        ReadingRow(title: checkTitle(r), reading: r,
                                   note: r.diff.map { $0 == 0 ? nil : "Difference \(Fmt.signedKina($0))" } ?? nil)
                    }
                }
            }
        } header: {
            Text(measure.longTitle)
        }
    }

    private func seriesTitle(_ r: Reading) -> String {
        let edition = r.edition.map { "\(String($0)) Budget" } ?? "Later budget"
        switch r.series {
        case "revised": return "\(edition) — revised estimate"
        case "actual": return "\(edition) — actual"
        case "budget": return "\(edition) — budget as reprinted"
        default: return edition
        }
    }

    private func checkTitle(_ r: Reading) -> String {
        switch r.col {
        case "budget": return "Budget as reprinted in the FBO"
        case "outcome": return "FBO outcome"
        default: return r.col?.capitalized ?? "Check"
        }
    }
}
