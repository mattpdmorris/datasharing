import SwiftUI
import Charts

struct OverviewView: View {
    @Environment(DataStore.self) private var store
    @State private var selectedYear: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headline
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What the budget said, and what was spent")
                            .font(.headline).foregroundStyle(.primary).textCase(nil)
                        Text("Kiribati recurrent budget: appropriation plus statutory spending, against the Annual Account.")
                            .font(.footnote).textCase(nil)
                    }
                    .padding(.bottom, 4)
                }

                Section {
                    BudgetChart(years: store.budgetYears, lens: store.lens,
                                transform: { store.transform($0, year: $1) },
                                selectedYear: $selectedYear)
                        .frame(height: 260)
                        .padding(.vertical, 4)
                    LensPicker(showNote: false)
                    Explainer(text: store.lens == .nominal
                        ? "Budget is the total operating budget as passed (appropriation plus statutory). Revised adds supplementary appropriations, as reported in the Annual Account. Actual is expenditure from the Annual Account. 2019 has no usable Annual Account; 2020 appropriated February–December only."
                        : store.lensNote)
                } header: {
                    Text("Budget, revised budget and actual").textCase(nil)
                }

                if let dev = devFundSeries, !dev.isEmpty {
                    Section {
                        DevFundChart(points: dev)
                            .frame(height: 160)
                        Explainer(text: "The Local Contribution to the Development Fund (head 02) is part of each appropriation, not in addition to it. It grew from 9% of the appropriation in 2011 to 36% in 2026 — the Fund is where most of the real growth in the budget happened.")
                    } header: {
                        Text("Development Fund share of appropriation").textCase(nil)
                    }
                }

                Section("Year by year") {
                    ForEach(store.headline.filter { $0.hasBudget || $0.suppAppropriated != nil }.reversed()) { y in
                        NavigationLink(value: y.year) { YearRow(year: y) }
                    }
                }

                Section { PoweredByFooter() }
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("Kiribati Budget")
            .navigationDestination(for: Int.self) { YearDetailView(year: $0) }
        }
    }

    private var devFundSeries: [(year: Int, share: Double)]? {
        store.budgetYears.compactMap { y in y.devFundShare.map { (y.year, $0) } }
    }

    @ViewBuilder
    private var headline: some View {
        let a = store.latestActualYear
        let b = store.latestBudgetYear
        VStack(alignment: .leading, spacing: 10) {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    if let a {
                        StatTile(title: "\(String(a.year)) actual", value: store.formatted(a.actual, year: a.year),
                                 detail: a.execution.map { "\(Fmt.percent($0)) of the original budget" })
                    }
                    if let b {
                        StatTile(title: "\(String(b.year)) budget", value: store.formatted(b.totalOperating, year: b.year),
                                 detail: "Appropriation plus statutory")
                    }
                }
                GridRow {
                    if let b {
                        StatTile(title: "Development Fund \(String(b.year))", value: store.formatted(b.devFund, year: b.year),
                                 detail: b.devFundShare.map { "\(Fmt.percent($0)) of the appropriation" })
                        StatTile(title: "Statutory \(String(b.year))", value: store.formatted(b.statutory, year: b.year),
                                 detail: "Charged by law, not voted")
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
    }
}

private struct YearRow: View {
    @Environment(DataStore.self) private var store
    let year: HeadlineYear

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(year.year)).font(.headline.monospacedDigit())
                HStack(spacing: 4) {
                    if !year.hasBudget { FlagBadge(text: "Supplementary only", style: .info) }
                    if year.isPartYear { FlagBadge(text: "11-month budget", style: .caution) }
                    if year.hasBudget && year.actual == nil && year.year < 2026 && year.year >= 2016 {
                        FlagBadge(text: "No outturn", style: .info)
                    }
                    if year.supplementaryDisagrees { FlagBadge(text: "Two supplementary figures", style: .caution) }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    Text(store.formatted(year.totalOperating ?? year.suppAppropriated, year: year.year))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if store.denominatorIsProvisional(year.year) { ProvisionalMark() }
                }
                if year.actual != nil {
                    Text(store.formatted(year.actual, year: year.year))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
            }
        }
    }
}

struct BudgetChart: View {
    let years: [HeadlineYear]
    let lens: Lens
    let transform: (Double, Int) -> Double?
    @Binding var selectedYear: Int?

    private struct Point: Identifiable {
        let year: Int
        let kind: String
        let value: Double
        var segment = 0
        var id: String { "\(year)-\(kind)" }
    }

    private var points: [Point] {
        var out: [Point] = []
        var seg = 0
        var last: Int?
        for y in years {
            if let v = y.totalOperating, let t = transform(v, y.year) {
                out.append(Point(year: y.year, kind: "Budget", value: t))
            }
            if let v = y.revised, let t = transform(v, y.year) {
                out.append(Point(year: y.year, kind: "Revised", value: t))
            }
            if let v = y.actual, let t = transform(v, y.year) {
                if let l = last, y.year != l + 1 { seg += 1 }
                out.append(Point(year: y.year, kind: "Actual", value: t, segment: seg))
                last = y.year
            }
        }
        return out
    }

    var body: some View {
        let pts = points
        Chart {
            ForEach(pts.filter { $0.kind == "Budget" }) { p in
                BarMark(x: .value("Year", p.year), y: .value(lens.axisLabel, p.value), width: .fixed(10))
                    .foregroundStyle(by: .value("Series", p.kind))
                    .opacity(selectedYear == nil || selectedYear == p.year ? 0.9 : 0.35)
            }
            ForEach(pts.filter { $0.kind == "Revised" }) { p in
                PointMark(x: .value("Year", p.year), y: .value(lens.axisLabel, p.value))
                    .foregroundStyle(by: .value("Series", p.kind))
                    .symbol(.diamond)
                    .symbolSize(40)
            }
            ForEach(pts.filter { $0.kind == "Actual" }) { p in
                LineMark(x: .value("Year", p.year), y: .value(lens.axisLabel, p.value),
                         series: .value("Segment", "Actual \(p.segment)"))
                    .foregroundStyle(by: .value("Series", p.kind))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Year", p.year), y: .value(lens.axisLabel, p.value))
                    .foregroundStyle(by: .value("Series", p.kind))
                    .symbolSize(selectedYear == p.year ? 70 : 28)
            }
            if let y = selectedYear {
                RuleMark(x: .value("Year", y))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        annotation(y, pts)
                    }
            }
        }
        .chartForegroundStyleScale(["Budget": Brand.budget, "Revised": Brand.revised, "Actual": Brand.actual])
        .chartXAxis {
            AxisMarks(values: .stride(by: 3)) { v in
                AxisGridLine()
                AxisValueLabel { if let y = v.as(Int.self) { Text(String(y)) } }
            }
        }
        .chartYAxis {
            AxisMarks { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.axis(d, lens)) } }
            }
        }
        .chartXSelection(value: $selectedYear)
        .chartLegend(position: .bottom)
        .accessibilityLabel("Budget, revised budget and actual expenditure by year")
    }

    private func annotation(_ year: Int, _ pts: [Point]) -> some View {
        let v = { (k: String) in pts.first { $0.year == year && $0.kind == k }?.value }
        return VStack(alignment: .leading, spacing: 2) {
            Text(String(year)).font(.caption.weight(.semibold))
            Text("Budget \(Fmt.lens(v("Budget"), lens))").font(.caption2)
            if v("Revised") != nil { Text("Revised \(Fmt.lens(v("Revised"), lens))").font(.caption2) }
            if v("Actual") != nil { Text("Actual \(Fmt.lens(v("Actual"), lens))").font(.caption2) }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct DevFundChart: View {
    let points: [(year: Int, share: Double)]

    private struct P: Identifiable { let year: Int; let share: Double; var id: Int { year } }

    var body: some View {
        Chart(points.map { P(year: $0.year, share: $0.share) }) { p in
            AreaMark(x: .value("Year", p.year), y: .value("Share", p.share * 100))
                .foregroundStyle(Brand.blue.opacity(0.25))
            LineMark(x: .value("Year", p.year), y: .value("Share", p.share * 100))
                .foregroundStyle(Brand.blue)
        }
        .chartYAxis {
            AxisMarks { v in
                AxisGridLine()
                AxisValueLabel { if let d = v.as(Double.self) { Text(String(format: "%.0f%%", d)) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 3)) { v in
                AxisGridLine()
                AxisValueLabel { if let y = v.as(Int.self) { Text(String(y)) } }
            }
        }
        .accessibilityLabel("Development Fund as a share of the appropriation")
    }
}
