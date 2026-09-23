import SwiftUI
import Charts

struct ProjectsView: View {
    @Environment(DataStore.self) private var store
    @State private var query = ""
    @State private var group: String?
    @State private var sort: Sort = .current

    enum Sort: String, CaseIterable, Identifiable {
        case current = "This year", total = "5-year", name = "A–Z"
        var id: String { rawValue }
    }

    private var groups: [String] {
        Array(Set(store.projects.map(\.group))).sorted()
    }

    private var filtered: [PIPProject] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = store.projects.filter { p in
            (group == nil || p.group == group) &&
            (q.isEmpty || p.name.lowercased().contains(q) || p.agency.lowercased().contains(q)
                || p.pipNumber.contains(q) || p.otherNames.contains { $0.lowercased().contains(q) })
        }
        switch sort {
        case .current: return list.sorted { ($0.currentYearAllocation ?? -1) > ($1.currentYearAllocation ?? -1) }
        case .total: return list.sorted { ($0.latestTotal ?? -1) > ($1.latestTotal ?? -1) }
        case .name: return list.sorted { $0.name < $1.name }
        }
    }

    var body: some View {
        NavigationStack {
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
                Text(Fmt.kinaShort(project.currentYearAllocation))
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
        project.facts.filter { !$0.isPrintedTotal }.map { Point(edition: $0.edition, year: $0.refYear, value: $0.value) }
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
                    LineMark(x: .value("Year", p.year), y: .value("K million", p.value),
                             series: .value("Edition", String(p.edition)))
                        .foregroundStyle(p.edition == currentEdition ? Brand.red : Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: p.edition == currentEdition ? 2.5 : 1))
                    PointMark(x: .value("Year", p.year), y: .value("K million", p.value))
                        .foregroundStyle(p.edition == currentEdition ? Brand.red : Color.secondary.opacity(0.35))
                        .symbolSize(p.edition == currentEdition ? 30 : 10)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { v in
                        AxisGridLine()
                        AxisValueLabel { if let y = v.as(Int.self) { Text(String(y)) } }
                    }
                }
                .frame(height: 200)
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
                Text(Fmt.kinaMillions(f.value)).monospacedDigit()
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
