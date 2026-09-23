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
                    Explainer(text: "Where two official documents disagree, both numbers are shown and the disagreement is flagged rather than resolved silently. Real-terms and % of GDP views are clearly labelled transformations; years without an official denominator drop out rather than being estimated.")
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
                        if let cpi = p.cpiSource {
                            authority("Prices", "\(cpi.name) — \(cpi.measure), \(cpi.base).")
                        }
                        if let parts = p.gdpSource?.composite {
                            authority("GDP", parts.map { "\($0.name) (\($0.span))" }.joined(separator: "; "))
                        }
                    }

                    Section("What the data does not support") {
                        Explainer(text: "Volume 2A agency lines cover national departments and statutory bodies only — part of the printed appropriation. Provincial governments and health authorities (Volume 2D), debt service and several summary lines sit outside it, so agency totals should not be read as total government spending.")
                        if let notHeld = p.gdpSource?.notHeld, !notHeld.isEmpty {
                            Explainer(text: "No primary GDP is held for \(notHeld.map(String.init).joined(separator: ", ")); those years are omitted from % of GDP views.")
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
