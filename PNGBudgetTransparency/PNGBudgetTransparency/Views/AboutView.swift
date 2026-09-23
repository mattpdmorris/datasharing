import SwiftUI

struct AboutView: View {
    @Environment(DataStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        BrandMark(size: 64)
                        Text(Brand.appName).font(.title3.weight(.semibold))
                        Text(Brand.poweredBy).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("How a number gets into this app") {
                    Explainer(text: "Every figure is read from a primary document — Budget Volume 1, Budget Volume 2A, and the Final Budget Outcome — and carries the document, page, table and column it came from. Nothing is typed in by hand.")
                    Explainer(text: "Where two official documents disagree, both numbers are shown and the disagreement is flagged rather than resolved silently. Constant-price, % of GDP and % of total spending views are clearly labelled transformations using the ANU PNG National Budget Database; a year without the denominator drops out rather than being estimated.")
                }

                Section {
                    Label("Beta — not an official record", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Explainer(text: "These figures have not been audited. Check anything you rely on against the source document cited alongside it. Source data remains subject to the terms of the publishing agency; the extraction, annotations and analysis are offered for reuse with attribution to Virtual Economics.")
                }

                if let p = store.payload {
                    Section("This dataset") {
                        LabeledContent("Built", value: p.generated)
                        LabeledContent("Source", value: store.dataOrigin)
                        LabeledContent("Fiscal years", value: yearSpan)
                        LabeledContent("Agencies", value: "\(p.counts.agencies)")
                        LabeledContent("Agency figures", value: p.counts.agencyFacts.formatted())
                        LabeledContent("Treasury figures read", value: p.counts.treasuryObservations.formatted())
                        LabeledContent("Treasury documents", value: "\(p.counts.treasuryDocuments)")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Corpus version").font(.caption).foregroundStyle(.secondary)
                            Text(p.corpusVersion).font(.caption2.monospaced()).textSelection(.enabled)
                        }
                    }

                    Section("Which document is the authority for what") {
                        authority("Budgeted figures", "Each year's Budget Volume 1, Budget Balance table.")
                        authority("Outturn", "That year's Final Budget Outcome. Where none is held, the \"Actual\" column of a later Budget Volume 1, marked as such.")
                        authority("Agency lines", "Budget Volume 2A, editions \(store.editions.first.map(String.init) ?? "") to \(store.editions.last.map(String.init) ?? "").")
                        if let anu = store.anu {
                            authority("Prices", "\(anu.source.name) (\(anu.source.edition)): CPI chained from Table 9 annual-average inflation, or the GDP deflator from its Analysis sheet; 2025 = 100.")
                            authority("GDP", "\(anu.source.name): nominal GDP, new NSO series (2005–06 from the ANU PNG Economic Database).")
                            authority("Total spending", "\(anu.source.name): general government expenditure and net lending — actual to 2024, 2025 estimate, projections from 2026.")
                        }
                    }

                    Section("What the data does not support") {
                        Explainer(text: "Volume 2A agency lines cover national departments and statutory bodies only — part of the printed appropriation. Provincial governments and health authorities (Volume 2D), debt service and several summary lines sit outside it, so agency totals should not be read as total government spending.")
                        Explainer(text: "Denominators for 2024 onward are ANU estimates or Treasury projections and will change as outturns are published; figures that use them are marked \"e\".")
                    }

                    if let anu = store.anu {
                        Section("ANU PNG National Budget Database") {
                            LabeledContent("Edition", value: anu.source.edition)
                            LabeledContent("Updated", value: anu.source.updated)
                            LabeledContent("Compiled by", value: anu.source.authors)
                            Text(anu.source.publisher).font(.caption).foregroundStyle(.secondary)
                            Text(anu.source.file).font(.caption2).foregroundStyle(.tertiary)
                            if let econ = anu.source.econFile {
                                Text(econ).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Section("Documents behind the agency record (\(p.volumes.count))") {
                        ForEach(p.volumes, id: \.self) { v in
                            Text(v).font(.caption)
                        }
                    }
                }

                Section {
                    Link(destination: Brand.dataURL) {
                        Label("Open the dataset on the web", systemImage: "safari")
                    }
                    Link(destination: Brand.siteURL) {
                        Label("Virtual Economics", systemImage: "globe.asia.australia")
                    }
                    Link(destination: URL(string: "https://virtualeconomics.com")!) {
                        Label("Report a correction", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("About")
        }
    }

    private var yearSpan: String {
        guard let a = store.years.first, let b = store.years.last else { return "—" }
        return "\(String(a))–\(String(b))"
    }

    private func authority(_ what: String, _ source: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(what).font(.subheadline.weight(.medium))
            Text(source).font(.caption).foregroundStyle(.secondary)
        }
    }
}
