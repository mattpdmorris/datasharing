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
                    Explainer(text: "Every figure is read from a primary document — the recurrent budget volume, the Appropriation and Supplementary Appropriation Acts, and the Annual Account — and carries the document and page it came from.")
                    Explainer(text: "Where two documents disagree, both numbers are shown. Constant-price, % of GDP and % of spending views are labelled transformations; a year without the denominator drops out rather than being estimated.")
                }

                Section {
                    Label("Beta — not an official record", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Explainer(text: "These figures have not been audited. Check anything you rely on against the source document. Source data remains subject to the terms of the Government of Kiribati; the extraction, annotations and analysis are offered for reuse with attribution to Virtual Economics.")
                }

                if let d = store.data {
                    Section("This dataset") {
                        LabeledContent("Built", value: d.generated)
                        LabeledContent("Source", value: store.dataOrigin)
                        LabeledContent("Currency", value: "Australian dollars")
                        LabeledContent("Budget years", value: span(store.budgetYears.map(\.year)))
                        LabeledContent("Ministry tables", value: span(store.ministryYears))
                        LabeledContent("Ministries and heads", value: "\(d.ministries.count)")
                    }

                    Section("Which document is the authority for what") {
                        authority("Original budget", "Recurrent budget volume, Table 2 — cross-checked against the enacted Appropriation Act in every year one survives.")
                        authority("Supplementary", "Supplementary Appropriation Acts (PacLII, parliament.gov.ki) and supplementary budget volumes. Service year, not title year, is the key.")
                        authority("Outturn", "The Annual Account for the year.")
                        ForEach(["ministries", "cpi", "gdp", "total_exp", "donors"], id: \.self) { k in
                            if let s = d.sources[k] { authority(label(k), s) }
                        }
                    }

                    Section("What the data does not support") {
                        Explainer(text: "This is the recurrent budget. Donor-financed development projects sit largely outside it — see the Donors tab and the % of spending view.")
                        Explainer(text: "2020 appropriated February–December only. 2019 has no usable Annual Account. 2023 and 2026 ministry figures are not charted because those volumes book the Development Fund, subsidies and debt service inside ministries.")
                        Explainer(text: "Kiribati's CPI is a household basket driven by import prices; it answers \"what could this buy at consumer prices\", not \"what could government buy\". GDP is KNSO to 2021 and IMF from 2022, chained without reconciliation.")
                    }
                }

                Section {
                    Link(destination: Brand.dataURL) { Label("Virtual Economics data", systemImage: "safari") }
                    Link(destination: Brand.siteURL) { Label("Virtual Economics", systemImage: "globe.asia.australia") }
                }
            }
            .navigationTitle("About")
        }
    }

    private func span(_ ys: [Int]) -> String {
        guard let a = ys.min(), let b = ys.max() else { return "—" }
        return "\(String(a))–\(String(b))"
    }

    private func label(_ k: String) -> String {
        switch k {
        case "ministries": "Ministry lines"
        case "cpi": "Prices"
        case "gdp": "GDP"
        case "total_exp": "Total spending"
        case "donors": "Donors"
        default: k.capitalized
        }
    }

    private func authority(_ what: String, _ source: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(what).font(.subheadline.weight(.medium))
            Text(source).font(.caption).foregroundStyle(.secondary)
        }
    }
}
