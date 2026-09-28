import SwiftUI
import Charts

struct ProjectsView: View {
    @Environment(DataStore.self) private var store
    @State private var query = ""
    @State private var group: String?
    @State private var agencyCode: String?
    @State private var path = NavigationPath()
    @State private var sort: Sort = .current

    enum Sort: String, CaseIterable, Identifiable {
        case current = "This year", total = "5-year", name = "A–Z"
        var id: String { rawValue }
    }

    private var groups: [String] {
        Array(Set(store.projects.map(\.group))).sorted()
    }

    /// Executing agencies, keyed by code (names vary slightly across editions),
    /// with how many projects each runs.
    private var agencies: [(code: String, name: String, count: Int)] {
        var names: [String: String] = [:]
        var counts: [String: Int] = [:]
        for p in store.projects {
            names[p.agencyCode] = names[p.agencyCode] ?? p.agency
            counts[p.agencyCode, default: 0] += 1
        }
        return names.map { (code: $0.key, name: $0.value, count: counts[$0.key] ?? 0) }
            .sorted { $0.name < $1.name }
    }

    private var filtered: [PIPProject] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = store.projects.filter { p in
            (group == nil || p.group == group) &&
            (agencyCode == nil || p.agencyCode == agencyCode) &&
            (q.isEmpty || p.name.lowercased().contains(q) || p.agency.lowercased().contains(q)
                || p.pipNumber.contains(q) || p.otherNames.contains { $0.lowercased().contains(q) })
        }
        switch sort {
        case .current: return list.sorted { ($0.currentYearAllocation ?? -1) > ($1.currentYearAllocation ?? -1) }
        case .total: return list.sorted { ($0.latestTotal ?? -1) > ($1.latestTotal ?? -1) }
        case .name: return list.sorted { $0.name < $1.name }
        }
    }

    /// The measure the treemap is sized by: the 5-year total when sorting by it,
    /// otherwise the latest edition's own-year allocation.
    private func measure(_ p: PIPProject) -> Double {
        (sort == .total ? p.latestTotal : p.currentYearAllocation) ?? 0
    }

    private var measureLabel: String {
        sort == .total ? "five-year totals" : "this year's allocations"
    }

    private static let palette: [Color] = [
        Color(red: 0.72, green: 0.07, blue: 0.14), Color(red: 0.62, green: 0.47, blue: 0.04),
        Color(red: 0.13, green: 0.36, blue: 0.55), Color(red: 0.20, green: 0.45, blue: 0.30),
        Color(red: 0.45, green: 0.25, blue: 0.50), Color(red: 0.55, green: 0.30, blue: 0.15),
        Color(red: 0.25, green: 0.40, blue: 0.45), Color(red: 0.40, green: 0.40, blue: 0.42),
    ]

    /// Agencies as tiles when no agency is chosen; that agency's projects otherwise.
    private var treemapItems: [TreemapItem] {
        let list = filtered
        let total = list.reduce(0) { $0 + measure($1) }
        guard total > 0 else { return [] }
        func detail(_ v: Double) -> String { "\(Fmt.kinaShort(v)) · \(Fmt.percent(v / total))" }
        let maxTiles = 30

        if agencyCode == nil {
            var sums: [String: (name: String, value: Double)] = [:]
            for p in list {
                let cur = sums[p.agencyCode] ?? (p.agency, 0)
                sums[p.agencyCode] = (cur.name, cur.value + measure(p))
            }
            let ranked = sums.sorted { $0.value.value > $1.value.value }
            var items = ranked.prefix(maxTiles).enumerated().map { i, e in
                TreemapItem(id: "agency:" + e.key, label: e.value.name, detail: detail(e.value.value),
                            value: e.value.value, color: Self.palette[i % Self.palette.count])
            }
            let rest = ranked.dropFirst(maxTiles).reduce(0) { $0 + $1.value.value }
            if rest > 0 {
                items.append(TreemapItem(id: "other", label: "\(ranked.count - maxTiles) other agencies",
                                         detail: detail(rest), value: rest, color: .gray))
            }
            return items
        } else {
            let groupList = groups
            let ranked = list.sorted { measure($0) > measure($1) }
            var items = ranked.prefix(maxTiles).map { p in
                TreemapItem(id: "project:" + p.pipNumber, label: p.name, detail: detail(measure(p)), value: measure(p),
                            color: Self.palette[(groupList.firstIndex(of: p.group) ?? 0) % Self.palette.count])
            }
            let rest = ranked.dropFirst(maxTiles).reduce(0) { $0 + measure($1) }
            if rest > 0 {
                items.append(TreemapItem(id: "other", label: "\(ranked.count - maxTiles) other projects",
                                         detail: detail(rest), value: rest, color: .gray))
            }
            return items
        }
    }

    private func tapped(_ item: TreemapItem) {
        if item.id.hasPrefix("agency:") {
            agencyCode = String(item.id.dropFirst("agency:".count))
        } else if item.id.hasPrefix("project:"),
                  let p = store.projects.first(where: { "project:" + $0.pipNumber == item.id }) {
            path.append(p)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    Explainer(text: "Capital and capacity-building projects in the Public Investment Programme, from Budget Volume 3. Each edition prints a five-year profile per project; figures are K million as printed.")
                    Picker("Sort", selection: $sort) {
                        ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Programme", selection: $group) {
                        Text("All programmes").tag(String?.none)
                        ForEach(groups, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    Picker("Agency", selection: $agencyCode) {
                        Text("All agencies").tag(String?.none)
                        ForEach(agencies, id: \.code) { a in
                            Text("\(a.name) (\(a.count))").tag(String?.some(a.code))
                        }
                    }
                    .pickerStyle(.navigationLink)
                    LensPicker()
                }

                let tiles = treemapItems
                if !tiles.isEmpty {
                    Section {
                        Treemap(items: tiles, onTap: tapped)
                            .frame(height: 320)
                            .padding(.vertical, 4)
                        if agencyCode != nil {
                            Button("Show all agencies") { agencyCode = nil }
                                .font(.subheadline)
                        }
                    } header: {
                        Text(agencyCode == nil ? "Where the money goes, by agency" : "Projects by size")
                            .textCase(nil)
                    } footer: {
                        Text(agencyCode == nil
                             ? "Each tile is an executing agency, sized by the sum of its projects' \(measureLabel) (K million, as printed). Tap a tile to see that agency's projects."
                             : "Each tile is a project, sized by its \(measureLabel) and coloured by programme. Tap a tile to open it.")
                    }
                }

                Section("\(filtered.count) projects") {
                    ForEach(filtered.prefix(300)) { p in
                        NavigationLink(value: p) { ProjectRow(project: p) }
                    }
                    if filtered.count > 300 {
                        Text("Showing the first 300 — search to narrow.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                Section { PoweredByFooter() }
                    .listRowBackground(Color.clear)
            }
            .searchable(text: $query, prompt: "Project, agency or PIP number")
            .navigationTitle("Projects")
            .navigationDestination(for: PIPProject.self) { ProjectDetailView(project: $0) }
        }
    }
}

private struct ProjectRow: View {
    @Environment(DataStore.self) private var store
    let project: PIPProject

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name).lineLimit(2)
                Text("\(project.agency) · PIP \(project.pipNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(project.latestEdition.map { store.formatted(project.currentYearAllocation, year: $0) } ?? "—")
                    .font(.subheadline.monospacedDigit())
                if let e = project.latestEdition {
                    Text(String(e)).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ProjectDetailView: View {
    @Environment(DataStore.self) private var store
    let project: PIPProject
    @State private var edition: Int?

    private var currentEdition: Int? { edition ?? project.latestEdition }

    private struct Point: Identifiable {
        let edition: Int
        let year: Int
        let value: Double
        var id: String { "\(edition)-\(year)" }
    }

    /// Every edition's profile, so re-phasing across budgets is visible.
    private var points: [Point] {
        project.facts.filter { !$0.isPrintedTotal }.compactMap { f in
            store.transform(f.value, year: f.refYear).map { Point(edition: f.edition, year: f.refYear, value: $0) }
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("PIP number", value: project.pipNumber)
                LabeledContent("Executing agency", value: project.agency)
                LabeledContent("Programme", value: project.group)
                if !project.otherNames.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Also printed as").font(.caption).foregroundStyle(.secondary)
                        ForEach(project.otherNames, id: \.self) { Text($0).font(.caption) }
                    }
                }
            }

            Section {
                Chart(points) { p in
                    LineMark(x: .value("Year", p.year), y: .value(store.lens.axisLabel, p.value),
                             series: .value("Edition", String(p.edition)))
                        .foregroundStyle(p.edition == currentEdition ? Brand.red : Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: p.edition == currentEdition ? 2.5 : 1))
                    PointMark(x: .value("Year", p.year), y: .value(store.lens.axisLabel, p.value))
                        .foregroundStyle(p.edition == currentEdition ? Brand.red : Color.secondary.opacity(0.35))
                        .symbolSize(p.edition == currentEdition ? 30 : 10)
                }
                .chartXScale(domain: ((points.map(\.year).min() ?? 2018) - 1)...((points.map(\.year).max() ?? 2030) + 1))
                .chartXAxis {
                    AxisMarks(values: .automatic) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text(String(y)) } }
                    }
                }
                .chartYAxis {
                    AxisMarks { v in
                        AxisGridLine()
                        AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.axis(d, store.lens)) } }
                    }
                }
                .frame(height: 200)
                LensPicker(showNote: false)
                Explainer(text: "Each line is one budget edition's five-year profile for this project. The highlighted line is the selected edition; grey lines show how earlier budgets planned it.")
            } header: {
                Text("How the plan moved across budgets").textCase(nil)
            }

            if let e = currentEdition {
                Section {
                    Picker("Edition", selection: Binding(get: { e }, set: { edition = $0 })) {
                        ForEach(project.editions.reversed(), id: \.self) { Text(String($0)).tag($0) }
                    }
                    ForEach(project.profile(edition: e)) { f in
                        factRow(title: String(f.refYear), f)
                    }
                    if let t = project.facts.first(where: { $0.edition == e && $0.isPrintedTotal }) {
                        factRow(title: "Five-year total (printed)", t)
                    }
                } header: {
                    Text("\(String(e)) Budget profile").textCase(nil)
                }
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func factRow(title: String, _ f: PIPFact) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(store.lens == .nominal || f.isPrintedTotal ? Fmt.kinaMillions(f.value)
                                                                : store.formatted(f.value, year: f.refYear))
                    .monospacedDigit()
            }
            .font(.subheadline)
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                Text("\(Fmt.shortDoc(store.pipVolumeName(f.volumeIndex))) · printed p. \(f.printedPage) (PDF p. \(f.pdfPage))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
