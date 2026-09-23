import SwiftUI

/// Where documents disagree, where records are missing, and whether the
/// totals close. Nothing is resolved silently.
struct IntegrityView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                if let d = store.data {
                    Section {
                        Explainer(text: "The budget volume, the Appropriation and Supplementary Acts, and the Annual Account are separate documents, usually from separate archives. This page shows whether they add up, and every place they do not.")
                        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                            GridRow {
                                StatTile(title: "Years reconciled", value: "\(d.reconciliation.filter(\.closes).count) of \(d.reconciliation.count)",
                                         detail: "Budget + supplementaries = revised")
                                StatTile(title: "Ministry tables checked", value: "\(d.ministryChecks.count)",
                                         detail: "Lines vs printed Grand Total")
                            }
                        }
                    }

                    Section {
                        ForEach(d.reconciliation) { r in
                            NavigationLink {
                                List { ReconciliationSection(r: r) }.navigationTitle(String(r.year))
                            } label: {
                                HStack {
                                    Text(String(r.year)).font(.headline.monospacedDigit())
                                    Spacer()
                                    Text(Fmt.percent(r.residualPct, digits: 2)).monospacedDigit()
                                    FlagBadge(text: r.closes ? "Closes" : "Open", style: r.closes ? .ok : .caution)
                                }
                            }
                        }
                    } header: {
                        Text("Does the legislative record add up?").textCase(nil)
                    } footer: {
                        Text("Residual = revised budget in the Annual Account minus (original budget + every supplementary instrument held). 2024 and 2025 stay open because the supplementary Acts for those years are not yet available.")
                    }

                    let disagreements = d.headline.filter(\.supplementaryDisagrees)
                    if !disagreements.isEmpty {
                        Section {
                            ForEach(disagreements) { y in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(y.year)).font(.subheadline.weight(.semibold))
                                    Text("Nominal sheet: \(Fmt.dollars(y.suppAppropriated)) · real-terms sheet implies \(Fmt.dollars(y.suppFromRealSheet))")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            Text("Two supplementary figures for the same year").textCase(nil)
                        } footer: {
                            Text("The source workbook's constant-price sheet carries fuller supplementary totals than its nominal sheet. The workbook records this as unresolved (tension T45); both figures are shown here.")
                        }
                    }

                    Section {
                        ForEach(d.ministryChecks.sorted { $0.year > $1.year }) { c in
                            HStack {
                                Text(String(c.year)).monospacedDigit()
                                Spacer()
                                if let gap = c.gap, abs(gap) > 10 {
                                    Text(Fmt.signed(gap)).monospacedDigit().foregroundStyle(.orange)
                                } else {
                                    Text("matches").foregroundStyle(.secondary)
                                }
                            }
                            .font(.subheadline)
                        }
                        ForEach(d.ministryYearsNotCharted) { n in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(String(n.year)).monospacedDigit()
                                    Spacer()
                                    Text("not charted").foregroundStyle(.secondary)
                                }
                                Text(String(n.reason.prefix(1)).uppercased() + String(n.reason.dropFirst()) + ".")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    } header: {
                        Text("Ministry lines against the printed Grand Total").textCase(nil)
                    } footer: {
                        Text("Differences of a few dollars are rounding in the printed tables. A ministry whose name wrapped onto two lines in the PDF is named from the same head code in the nearest year's volume.")
                    }

                    if !d.reconciliationNotes.isEmpty || !d.headlineNotes.isEmpty {
                        Section("Notes from the source workbook") {
                            ForEach(Array((notes(d)).enumerated()), id: \.offset) { _, n in
                                Text(n).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section { PoweredByFooter() }
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("Integrity")
        }
    }

    /// The workbook's findings and gaps, without its section headings.
    private func notes(_ d: KiribatiData) -> [String] {
        let headings: Set<String> = ["The three shaded column types", "Why statutory has to be separate",
                                     "What the series shows", "Gaps", "Corrections", "Result",
                                     "The independent check on 2021", "Where the Acts came from"]
        return (d.headlineNotes + d.reconciliationNotes).filter { !headings.contains($0) && $0.count > 40 }
    }
}
