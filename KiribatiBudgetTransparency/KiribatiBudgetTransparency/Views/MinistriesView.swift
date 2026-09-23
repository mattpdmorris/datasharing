import SwiftUI
import Charts

struct MinistriesView: View {
    @Environment(DataStore.self) private var store
    @State private var year: Int?
    @State private var query = ""
    @State private var includeTransfers = false

    private var currentYear: Int { year ?? store.ministryYears.last ?? 2025 }

    private var rows: [Ministry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return store.ministries
            .filter { $0.fact(currentYear) != nil }
            .filter { includeTransfers || !$0.isNonMinistryLine }
            .filter { q.isEmpty || $0.name.lowercased().contains(q) || $0.printedNames.contains { $0.lowercased().contains(q) } }
            .sorted { ($0.fact(currentYear)?.operating ?? 0) > ($1.fact(currentYear)?.operating ?? 0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Budget year", selection: Binding(get: { currentYear }, set: { year = $0 })) {
                        ForEach(store.ministryYears.reversed(), id: \.self) { Text(String($0)).tag($0) }
                    }
                    MinistryBarChart(ministries: Array(rows.prefix(10)), year: currentYear)
                        .frame(height: 280)
                    Toggle("Include Development Fund, subsidies and debt service", isOn: $includeTransfers)
                        .font(.subheadline)
                    LensPicker()
                    if let v = store.volume(currentYear) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text("\(Fmt.shortDoc(v.file)) · \(v.method)")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    if let c = store.check(currentYear), let gap = c.gap, abs(gap) > 10 {
                        FlagBadge(text: "Lines differ from the printed total by \(Fmt.signed(gap))", style: .caution)
                    }
                } header: {
                    Text("Operating budget by ministry, \(String(currentYear))").textCase(nil)
                } footer: {
                    Text("Operating budget = net appropriation + statutory spending for each head, from Table 2 of the recurrent budget volume. 2010, 2023 and 2026 are not charted — see Integrity.")
                }

                Section("\(rows.count) heads") {
                    ForEach(rows) { m in
                        NavigationLink(value: m) { MinistryRow(ministry: m, year: currentYear) }
                    }
                }

                Section { PoweredByFooter() }
                    .listRowBackground(Color.clear)
            }
            .searchable(text: $query, prompt: "Ministry or office")
            .navigationTitle("Ministries")
            .navigationDestination(for: Ministry.self) { MinistryDetailView(ministry: $0) }
        }
    }
}

private struct MinistryRow: View {
    @Environment(DataStore.self) private var store
    let ministry: Ministry
    let year: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ministry.name).lineLimit(2)
                if let f = ministry.fact(year), let code = f.code, !code.isEmpty {
                    Text("Head \(code)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(store.formatted(ministry.fact(year)?.operating, year: year))
                .font(.subheadline.monospacedDigit())
        }
    }
}

private struct MinistryBarChart: View {
    @Environment(DataStore.self) private var store
    let ministries: [Ministry]
    let year: Int

    private struct Bar: Identifiable {
        let name: String
        let value: Double
        var id: String { name }
    }

    private var bars: [Bar] {
        ministries.compactMap { m in
            store.transform(m.fact(year)?.operating, year: year).map { Bar(name: short(m.name), value: $0) }
        }
    }

    private func short(_ name: String) -> String {
        name.replacingOccurrences(of: "Ministry of ", with: "")
            .replacingOccurrences(of: "Office of ", with: "")
    }

    var body: some View {
        Chart(bars) { b in
            BarMark(x: .value(store.lens.axisLabel, b.value), y: .value("Head", b.name))
                .foregroundStyle(Brand.gold)
                .annotation(position: .trailing) {
                    Text(Fmt.lens(b.value, store.lens)).font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks { v in
                AxisValueLabel { if let s = v.as(String.self) { Text(s).font(.caption2).lineLimit(1) } }
            }
        }
        .accessibilityLabel("Largest ministry budgets")
    }
}

struct MinistryDetailView: View {
    @Environment(DataStore.self) private var store
    let ministry: Ministry

    private struct Point: Identifiable {
        let year: Int
        let kind: String
        let value: Double
        var id: String { "\(year)-\(kind)" }
    }

    private var points: [Point] {
        ministry.facts.flatMap { f -> [Point] in
            var p: [Point] = []
            if let net = f.net, let t = store.transform(net, year: f.year) {
                p.append(Point(year: f.year, kind: "Appropriation", value: t))
            }
            if let s = f.statutory, s > 0, let t = store.transform(s, year: f.year) {
                p.append(Point(year: f.year, kind: "Statutory", value: t))
            }
            return p
        }
    }

    var body: some View {
        List {
            Section {
                Chart(points) { p in
                    BarMark(x: .value("Year", String(p.year)), y: .value(store.lens.axisLabel, p.value))
                        .foregroundStyle(by: .value("Part", p.kind))
                }
                .chartForegroundStyleScale(["Appropriation": Brand.gold, "Statutory": Brand.blue])
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.axis(d, store.lens)) } }
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 220)
                LensPicker()
            } header: {
                Text("Operating budget, stacked: appropriation + statutory").textCase(nil)
            }

            Section("By year") {
                ForEach(ministry.facts.reversed()) { f in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(String(f.year)).font(.headline.monospacedDigit())
                            Spacer()
                            Text(store.lens == .nominal ? Fmt.dollars(f.operating) : store.formatted(f.operating, year: f.year))
                                .monospacedDigit()
                        }
                        if let net = f.net, let st = f.statutory {
                            Text("Appropriation \(Fmt.dollars(net)) · statutory \(Fmt.dollars(st))")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text(source(f))
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if ministry.printedNames.count > 1 {
                Section("Printed as") {
                    ForEach(ministry.printedNames, id: \.self) { Text($0).font(.caption) }
                }
            }
        }
        .navigationTitle(ministry.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func source(_ f: Ministry.Fact) -> String {
        let doc = store.volume(f.year).map { Fmt.shortDoc($0.file) } ?? "\(f.year) budget volume"
        let head = (f.code?.isEmpty == false) ? " · head \(f.code!)" : ""
        return doc + (f.page.map { " · p. \($0)" } ?? "") + head
    }
}
