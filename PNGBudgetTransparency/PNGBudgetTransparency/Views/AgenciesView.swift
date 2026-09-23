import SwiftUI
import Charts

struct AgenciesView: View {
    @Environment(DataStore.self) private var store
    @State private var edition: Int?
    @State private var sector: String?
    @State private var query = ""
    @State private var sort: Sort = .size
    @State private var includeDebt = false

    enum Sort: String, CaseIterable, Identifiable {
        case size = "Largest", name = "A–Z"
        var id: String { rawValue }
    }

    private var currentEdition: Int { edition ?? store.editions.last ?? 2026 }

    private var filtered: [Agency] {
        let e = currentEdition
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = store.agencies(in: sector, edition: e).filter {
            q.isEmpty || $0.name.lowercased().contains(q) || $0.code.contains(q)
        }
        switch sort {
        case .name: return list.sorted { $0.name < $1.name }
        case .size: return list.sorted { (($0.appropriation(for: e)?.value) ?? -1) > (($1.appropriation(for: e)?.value) ?? -1) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Budget edition", selection: Binding(get: { currentEdition }, set: { edition = $0 })) {
                        ForEach(store.editions.reversed(), id: \.self) { Text(String($0)).tag($0) }
                    }
                    SectorChart(totals: store.sectorTotals(edition: currentEdition, includeDebtCharges: includeDebt),
                                selected: $sector)
                        .frame(height: 200)
                    Toggle("Include Public Debt Charges", isOn: $includeDebt)
                        .font(.subheadline)
                    Explainer(text: "Appropriations printed for each agency in the \(String(currentEdition)) Budget, Volume 2A, grouped by Treasury's own sector classification. Tap a sector to filter. Public Debt Charges (agency 299) are left out by default: they print gross debt service, including Treasury bill redemptions, which is not spending. Volume 2A covers national departments and statutory bodies — not the whole appropriation.")
                } header: {
                    Text("\(store.agencies.count) agencies, \(store.editions.count) budget editions")
                        .textCase(nil)
                }

                Section {
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    ForEach(filtered) { a in
                        NavigationLink(value: a) {
                            AgencyRow(agency: a, edition: currentEdition)
                        }
                    }
                    if filtered.isEmpty {
                        Text("No agencies match.").foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text(sector ?? "All sectors")
                        Spacer()
                        if sector != nil {
                            Button("Clear") { sector = nil }.font(.caption)
                        }
                    }
                }

                Section { PoweredByFooter() }
                    .listRowBackground(Color.clear)
            }
            .searchable(text: $query, prompt: "Agency name or code")
            .navigationTitle("Agencies")
            .navigationDestination(for: Agency.self) { AgencyDetailView(agency: $0) }
        }
    }
}

struct AgencyRow: View {
    let agency: Agency
    let edition: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(agency.name).lineLimit(2)
                Text("\(agency.code) · \(agency.sector)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if agency.isDebtCharges {
                    FlagBadge(text: "Gross debt service — not spending", style: .caution)
                }
            }
            Spacer()
            Text(Fmt.kinaShort(agency.appropriation(for: edition)?.value))
                .font(.subheadline.monospacedDigit())
        }
    }
}

struct SectorChart: View {
    let totals: [SectorTotal]
    @Binding var selected: String?

    var body: some View {
        Chart(totals) { t in
            BarMark(x: .value("K million", t.value), y: .value("Sector", t.sector))
                .foregroundStyle(selected == nil || selected == t.sector ? Brand.gold : Color.secondary.opacity(0.3))
                .annotation(position: .trailing) {
                    Text(Fmt.kinaShort(t.value)).font(.caption2).foregroundStyle(.secondary)
                }
        }
        .chartXAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let frame = proxy.plotFrame else { return }
                        let y = location.y - geo[frame].origin.y
                        if let s: String = proxy.value(atY: y) {
                            selected = (selected == s) ? nil : s
                        }
                    }
            }
        }
        .accessibilityLabel("Appropriation by sector")
    }
}

struct AgencyDetailView: View {
    @Environment(DataStore.self) private var store
    let agency: Agency

    private struct Point: Identifiable {
        let year: Int
        let kind: String
        let value: Double
        var id: String { "\(year)-\(kind)" }
    }

    private var points: [Point] {
        agency.years.flatMap { y -> [Point] in
            var p: [Point] = []
            if let a = agency.appropriation(for: y) { p.append(Point(year: y, kind: "Appropriation", value: a.value)) }
            if let a = agency.actual(for: y) { p.append(Point(year: y, kind: "Actual", value: a.value)) }
            if agency.appropriation(for: y) == nil, agency.actual(for: y) == nil,
               let pr = agency.facts.filter({ $0.series == .projection && $0.refYear == y }).max(by: { $0.edition < $1.edition }) {
                p.append(Point(year: y, kind: "Projection", value: pr.value))
            }
            return p
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Agency code", value: agency.code)
                LabeledContent("Sector", value: agency.sector)
                if agency.isDebtCharges {
                    Explainer(text: "This agency prints gross debt service, including Treasury bill redemptions that are rolled over within the year. Counted as spending it would make the agency budget larger than the whole appropriation, so it is excluded from sector totals by default.")
                }
                Chart(points) { p in
                    BarMark(x: .value("Year", String(p.year)), y: .value("K million", p.value))
                        .position(by: .value("Series", p.kind))
                        .foregroundStyle(by: .value("Series", p.kind))
                }
                .chartForegroundStyleScale(["Appropriation": Brand.budget, "Actual": Brand.outturn,
                                            "Projection": Color.secondary.opacity(0.5)])
                .chartLegend(position: .bottom)
                .frame(height: 220)
                .padding(.vertical, 4)
            } header: {
                Text("Appropriation against outturn").textCase(nil)
            }

            Section {
                ForEach(agency.years.reversed(), id: \.self) { y in
                    YearFactsRow(agency: agency, year: y)
                }
            } header: {
                Text("How each year moved across editions").textCase(nil)
            } footer: {
                Text("Each line is one printing: the budget edition it appeared in, whether it was an appropriation, a reported actual or a forward projection, and the page it is on.")
            }
        }
        .navigationTitle(agency.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct YearFactsRow: View {
    @Environment(DataStore.self) private var store
    let agency: Agency
    let year: Int

    var body: some View {
        let facts = agency.facts.filter { $0.refYear == year }.sorted { ($0.edition, $0.series.rawValue) < ($1.edition, $1.series.rawValue) }
        DisclosureGroup {
            ForEach(facts) { f in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(String(f.edition)) edition · \(f.series.title)")
                        Spacer()
                        Text(Fmt.kinaMillions(f.value)).monospacedDigit()
                    }
                    .font(.subheadline)
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text("\(Fmt.shortDoc(store.volumeName(f.volumeIndex))) · printed p. \(f.printedPage) (PDF p. \(f.pdfPage))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        } label: {
            HStack {
                Text(String(year)).font(.headline.monospacedDigit())
                Spacer()
                VStack(alignment: .trailing) {
                    if let a = agency.appropriation(for: year) {
                        Text("Approp. \(Fmt.kinaShort(a.value))").font(.caption.monospacedDigit())
                    }
                    if let a = agency.actual(for: year) {
                        Text("Actual \(Fmt.kinaShort(a.value))").font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
            }
        }
    }
}
