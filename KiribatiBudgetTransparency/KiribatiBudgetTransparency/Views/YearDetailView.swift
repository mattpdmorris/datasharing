import SwiftUI

struct YearDetailView: View {
    @Environment(DataStore.self) private var store
    let year: Int

    var body: some View {
        List {
            if let y = store.year(year) {
                if y.hasBudget {
                    Section {
                        row("Appropriation", y.appropriation, "Voted in the Appropriation Act")
                        row("of which Development Fund", y.devFund, "Head 02, Local Contribution to the Development Fund")
                        row("Statutory", y.statutory, "Charged on the Consolidated Fund by law: debt service and protected salaries")
                        row("Total operating budget", y.totalOperating, "Appropriation + statutory — the figure the Annual Account calls the original budget", bold: true)
                        if y.isPartYear {
                            FlagBadge(text: "February–December only: not comparable with other years", style: .caution)
                        }
                    } header: {
                        Text("Original budget — recurrent budget volume, Table 2").textCase(nil)
                    }
                }

                if y.suppAppropriated != nil || y.suppFromRealSheet != nil {
                    Section {
                        row("Supplementary appropriated", y.suppAppropriated, "Supplementary Appropriation Acts and volumes held")
                        if y.suppDevFund != nil { row("of which Development Fund", y.suppDevFund, nil) }
                        if y.suppStatutory != nil { row("Statutory", y.suppStatutory, nil) }
                        if y.suppTotal != nil { row("Total movement", y.suppTotal, nil, bold: true) }
                        if y.supplementaryDisagrees, let r = y.suppFromRealSheet {
                            VStack(alignment: .leading, spacing: 4) {
                                LabeledContent("Implied by the real-terms sheet", value: Fmt.dollars(r))
                                    .font(.subheadline)
                                Text("The source workbook's constant-price sheet implies a different supplementary total for this year, and records that sheet as the more complete series (tension T45). Both are shown; neither is chosen.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Supplementary").textCase(nil)
                    }
                }

                if y.revised != nil || y.actual != nil {
                    Section {
                        row("Revised budget", y.revised, "As reported in the Annual Account")
                        row("Actual expenditure", y.actual, "Annual Account", bold: true)
                        if y.actualDevFund != nil { row("of which Development Fund", y.actualDevFund, nil) }
                        if let e = y.execution {
                            LabeledContent("Actual ÷ original budget", value: Fmt.percent(e, digits: 1))
                        }
                    } header: {
                        Text("Outturn — Annual Account \(String(year))").textCase(nil)
                    }
                } else if y.hasBudget && year >= 2016 && year < 2026 {
                    Section {
                        Text(year == 2019
                             ? "The 2019 Annual Account is held but has no usable text layer, so no outturn is recorded."
                             : "No outturn is recorded for this year.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let r = store.reconciliation(year) {
                    ReconciliationSection(r: r)
                }

                Section {
                    LensPicker()
                    if store.lens != .nominal {
                        LabeledContent("Budget", value: store.formatted(y.totalOperating, year: year))
                        LabeledContent("Actual", value: store.formatted(y.actual, year: year))
                    }
                } header: {
                    Text("Show as").textCase(nil)
                }
            }

            if let d = store.denominator(year) {
                Section("Denominators for \(String(year))") {
                    if let g = d.gdp {
                        LabeledContent("Nominal GDP", value: String(format: "A$%.0fm", g) + status(d.gdpStatus))
                        Text(d.gdpSrc == "knso" ? "KNSO national accounts, Table 1" : "IMF Country Report 26/099")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let c = d.cpi {
                        LabeledContent("CPI (2025 = 100)", value: String(format: "%.1f", c)
                                       + ((d.cpiMonths ?? 12) < 12 ? " (\(d.cpiMonths ?? 0) months)" : ""))
                    }
                    if let t = d.imfTotalExp {
                        LabeledContent("Total government spending (IMF)", value: String(format: "A$%.0fm", t) + status(d.imfExpStatus))
                    }
                }
            }
        }
        .navigationTitle(String(year))
    }

    private func status(_ s: String?) -> String {
        Denominator.statusLabel(s).map { " (\($0))" } ?? ""
    }

    @ViewBuilder
    private func row(_ title: String, _ v: Double?, _ note: String?, bold: Bool = false) -> some View {
        if let v {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(Fmt.dollars(v))
                        .font(bold ? .body.monospacedDigit().weight(.semibold) : .body.monospacedDigit())
                }
                if let note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ReconciliationSection: View {
    let r: ReconciliationYear

    var body: some View {
        Section {
            ForEach(Array(r.steps.enumerated()), id: \.offset) { _, s in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(s.step).font(.subheadline)
                        Spacer()
                        Text(s.amount.map { Fmt.dollars($0) } ?? "—").font(.subheadline.monospacedDigit())
                    }
                    if let src = s.source {
                        Text(src).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let rev = r.revised {
                LabeledContent("Revised budget reported (\(r.revisedSource ?? "Annual Account"))", value: Fmt.dollars(rev))
                    .font(.subheadline)
            }
            if let res = r.residual {
                HStack {
                    Text("Residual")
                    Spacer()
                    Text("\(Fmt.dollars(res)) · \(Fmt.percent(r.residualPct, digits: 2))").monospacedDigit()
                }
                .font(.subheadline.weight(.semibold))
                FlagBadge(text: r.closes ? "Closes" : (r.verdict ?? "Open").capitalized, style: r.closes ? .ok : .caution)
            }
        } header: {
            Text("Does budget + supplementaries = revised budget?").textCase(nil)
        } footer: {
            Text("Each step is a separate document, usually from a separate archive.")
        }
    }
}
