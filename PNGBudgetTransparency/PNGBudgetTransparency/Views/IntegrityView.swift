import SwiftUI

/// Where official documents disagree with each other. Nothing here is
/// resolved silently: both figures are shown with their sources.
struct IntegrityView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                if let p = store.payload {
                    Section {
                        Explainer(text: "Public finance figures change after they are first printed. This page lists every place where two official PNG documents give different numbers for the same thing — so you can see the disagreement rather than have it smoothed away.")
                        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                            GridRow {
                                StatTile(title: "Restated years", value: "\(p.restatements.count)")
                                StatTile(title: "Outturn revisions", value: "\(p.outturnRevisions.count)")
                            }
                            GridRow {
                                StatTile(title: "Budget ≠ FBO reprint", value: "\(p.reconciliation.count)")
                                StatTile(title: "Duplicate agency lines", value: "\(p.quality?.conflictingDuplicates.count ?? 0)")
                            }
                        }
                    }

                    Section {
                        ForEach(p.restatements.sorted { $0.spread > $1.spread }) { r in
                            RestatementRow(r: r)
                        }
                    } header: {
                        Text("Where Treasury reported the same year twice").textCase(nil)
                    } footer: {
                        Text("The same series and year, printed with different values in different Final Budget Outcomes.")
                    }

                    Section {
                        ForEach(p.outturnRevisions) { r in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(String(r.year)) · \(r.label)").font(.subheadline.weight(.semibold))
                                ReadingRow(title: "Final Budget Outcome", reading: r.fbo)
                                ReadingRow(title: "Later Budget \"Actual\"", reading: r.budgetActual)
                            }
                        }
                    } header: {
                        Text("Outturns revised after the Final Budget Outcome").textCase(nil)
                    }

                    Section {
                        ForEach(p.reconciliation) { r in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(String(r.year)) · \(r.label)").font(.subheadline.weight(.semibold))
                                ReadingRow(title: "Budget Volume 1", reading: r.budgetDoc)
                                ReadingRow(title: "FBO reprint of the budget", reading: r.fbo)
                            }
                        }
                    } header: {
                        Text("Budget as passed vs. as reprinted in the FBO").textCase(nil)
                    }

                    if let q = p.quality, !q.conflictingDuplicates.isEmpty {
                        Section {
                            ForEach(q.conflictingDuplicates) { d in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(d.agency).font(.subheadline)
                                    Text("\(String(d.edition)) edition · \(String(d.refYear)) \(d.series): " +
                                         d.values.map { Fmt.kinaMillions($0) }.joined(separator: " vs "))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } header: {
                            Text("Same agency, same year, two different figures").textCase(nil)
                        } footer: {
                            Text("Lines printed more than once in one Volume 2A with different values. Both are kept.")
                        }
                    }

                    if let q = p.quality, !q.nameVariants.isEmpty {
                        Section("Agency name misprints") {
                            ForEach(q.nameVariants) { v in
                                LabeledContent(v.suspect, value: "→ \(v.likely)")
                                    .font(.caption)
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
}

private struct RestatementRow: View {
    let r: Restatement

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(String(r.period)) · \(r.series)").font(.subheadline.weight(.semibold))
                Spacer()
                Text("spread \(Fmt.kinaShort(r.spread))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            ForEach(r.readings, id: \.self) { x in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Fmt.shortDoc(x.doc)).font(.caption)
                        if let page = x.page {
                            Text("p. \(page)").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(Fmt.kinaMillions(x.v)).font(.caption.monospacedDigit())
                }
            }
        }
        .padding(.vertical, 2)
    }
}
