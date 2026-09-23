import SwiftUI
import Charts

struct OverviewView: View {
    @Environment(DataStore.self) private var store
    @State private var measure: FiscalMeasure = .expenditure
    @State private var selectedYear: Int?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    headline
                } header: {
                    header
                }

                Section {
                    Picker("Measure", selection: $measure) {
                        ForEach(FiscalMeasure.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    BudgetVsOutturnChart(rows: store.rows(measure), lens: store.lens,
                                         transform: { store.transform($0, year: $1) },
                                         selectedYear: $selectedYear)
                        .frame(height: 260)
                        .padding(.vertical, 4)
                    LensPicker(showNote: false)
                    Explainer(text: store.lens == .nominal ? nominalNote : store.lensNote)
                } header: {
                    Text("\(measure.longTitle): budgeted against outturn")
                }

                Section("Year by year") {
                    ForEach(store.rows(measure).reversed()) { row in
                        NavigationLink(value: row.year) {
                            YearRow(row: row)
                        }
                    }
                }

                Section { PoweredByFooter() }
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("PNG Budget")
            .navigationDestination(for: Int.self) { year in
                YearDetailView(year: year)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What the budget said, and what Treasury later reported")
                .font(.headline)
                .foregroundStyle(.primary)
                .textCase(nil)
            Text("National government, K million, from each year's Budget Volume 1 and Final Budget Outcome.")
                .font(.footnote)
                .textCase(nil)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var headline: some View {
        let y = store.latestOutturnYear
        let exp = y.flatMap { store.row(.expenditure, year: $0) }
        let rev = y.flatMap { store.row(.revenue, year: $0) }
        let bal = y.flatMap { store.row(.balance, year: $0) }
        let next = store.years.last.flatMap { store.row(.expenditure, year: $0) }

        VStack(alignment: .leading, spacing: 10) {
            if let y {
                Text("\(String(y)) outturn")
                    .font(.subheadline.weight(.semibold))
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        StatTile(title: "Spent", value: store.formatted(exp?.outturn, year: y),
                                 detail: exp?.execution.map { "\(Fmt.percent($0)) of budget" })
                        StatTile(title: "Raised", value: store.formatted(rev?.outturn, year: y),
                                 detail: rev?.execution.map { "\(Fmt.percent($0)) of budget" })
                    }
                    GridRow {
                        StatTile(title: "Balance", value: store.formatted(bal?.outturn, year: y),
                                 detail: bal.flatMap { $0.budget }.map { "Budgeted \(store.formatted($0, year: y))" },
                                 tint: (bal?.outturn ?? 0) < 0 ? Brand.red : .primary)
                        if let next {
                            StatTile(title: "\(String(next.year)) budget", value: store.formatted(next.budget, year: next.year),
                                     detail: "Expenditure appropriated")
                        }
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
    }

    private var nominalNote: String {
        "As printed in the source documents. Outturn is the Final Budget Outcome figure; where Treasury has not published one, the \"Actual\" column of a later Budget Volume 1 is used and marked."
    }
}

struct YearRow: View {
    @Environment(DataStore.self) private var store
    let row: FiscalRow

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(row.year)).font(.headline.monospacedDigit())
                HStack(spacing: 4) {
                    if row.outturn == nil {
                        FlagBadge(text: "Budget only", style: .info)
                    } else if row.outturnIsFromLaterBudget {
                        FlagBadge(text: "Outturn from later budget", style: .info)
                    }
                    if row.outturnsDisagree { FlagBadge(text: "Two outturns", style: .caution) }
                    if row.hasFlag { FlagBadge(text: "Flagged", style: .alert) }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    Text(store.formatted(row.budget, year: row.year))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if store.denominatorIsProvisional(row.year) { ProvisionalMark() }
                }
                Text(store.formatted(row.outturn, year: row.year))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(row.year)): budget \(store.formatted(row.budget, year: row.year)), outturn \(store.formatted(row.outturn, year: row.year))")
    }
}

struct BudgetVsOutturnChart: View {
    let rows: [FiscalRow]
    let lens: Lens
    /// Converts a K-million figure for a year into the current lens.
    let transform: (Double, Int) -> Double?
    @Binding var selectedYear: Int?

    private struct Point: Identifiable {
        let year: Int
        let kind: String
        let value: Double
        /// Outturn line segments break wherever a year has no outturn, so a
        /// missing year is never bridged by an invented line.
        var segment: Int = 0
        var id: String { "\(year)-\(kind)" }
    }

    private var points: [Point] {
        var out: [Point] = []
        var segment = 0
        var lastOutturnYear: Int?
        for r in rows {
            if let b = r.budget, let v = transform(b, r.year) {
                out.append(Point(year: r.year, kind: "Budget", value: v))
            }
            if let o = r.outturn, let v = transform(o, r.year) {
                if let last = lastOutturnYear, r.year != last + 1 { segment += 1 }
                out.append(Point(year: r.year, kind: "Outturn", value: v, segment: segment))
                lastOutturnYear = r.year
            }
        }
        return out
    }

    var body: some View {
        let pts = points
        Chart {
            ForEach(pts.filter { $0.kind == "Budget" }) { p in
                BarMark(x: .value("Year", p.year), y: .value(lens.axisLabel, p.value), width: .fixed(8))
                    .foregroundStyle(by: .value("Series", p.kind))
                    .opacity(selectedYear == nil || selectedYear == p.year ? 0.9 : 0.35)
            }
            ForEach(pts.filter { $0.kind == "Outturn" }) { p in
                LineMark(x: .value("Year", p.year), y: .value(lens.axisLabel, p.value),
                         series: .value("Segment", "Outturn \(p.segment)"))
                    .foregroundStyle(by: .value("Series", p.kind))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Year", p.year), y: .value(lens.axisLabel, p.value))
                    .foregroundStyle(by: .value("Series", p.kind))
                    .symbolSize(selectedYear == p.year ? 70 : 28)
            }
            if pts.contains(where: { $0.value < 0 }) {
                RuleMark(y: .value("Zero", 0)).foregroundStyle(Color.secondary.opacity(0.5))
            }
            if let y = selectedYear {
                RuleMark(x: .value("Year", y))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .annotation(position: .top, overflowResolution: .init(x: .fit, y: .disabled)) {
                        annotation(for: y, in: pts)
                    }
            }
        }
        .chartForegroundStyleScale(["Budget": Brand.budget, "Outturn": Brand.outturn])
        .chartXAxis {
            AxisMarks(values: .stride(by: 4)) { v in
                AxisGridLine()
                AxisValueLabel { if let y = v.as(Int.self) { Text(String(y)) } }
            }
        }
        .chartYAxis {
            AxisMarks { v in
                AxisGridLine()
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text(Fmt.axis(d, lens))
                    }
                }
            }
        }
        .chartXSelection(value: $selectedYear)
        .chartLegend(position: .bottom)
        .accessibilityLabel("Budget against outturn by year")
    }

    private func annotation(for year: Int, in pts: [Point]) -> some View {
        let b = pts.first { $0.year == year && $0.kind == "Budget" }?.value
        let o = pts.first { $0.year == year && $0.kind == "Outturn" }?.value
        return VStack(alignment: .leading, spacing: 2) {
            Text(String(year)).font(.caption.weight(.semibold))
            Text("Budget \(Fmt.lens(b, lens))").font(.caption2)
            Text("Outturn \(Fmt.lens(o, lens))").font(.caption2)
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}
