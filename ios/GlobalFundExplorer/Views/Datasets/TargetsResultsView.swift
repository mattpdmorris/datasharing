import SwiftUI
import Charts

/// A grant's performance framework: indicators with baselines, targets, results
/// and achievement, including breakdowns such as sex, age or key population.
struct TargetsResultsView: View {
    let grant: Grant

    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().implementationPeriods(grantCode: grant.number) }) { periods in
            if periods.isEmpty {
                ContentUnavailableView("No implementation periods", systemImage: "calendar", description: Text("The API returned no implementation periods for this grant."))
            } else {
                PeriodTargets(periods: periods)
            }
        }
        .navigationTitle("Targets and results")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Period picker

private struct PeriodTargets: View {
    let periods: [ImplementationPeriod]
    @State private var selected: String?

    private var current: ImplementationPeriod {
        periods.first { $0.code == selected } ?? periods[0]
    }

    var body: some View {
        let code = current.code
        VStack(spacing: 0) {
            if periods.count > 1 {
                Picker("Implementation period", selection: Binding(get: { code }, set: { selected = $0 })) {
                    ForEach(periods) { Text($0.label).tag($0.code) }
                }
                .pickerStyle(.menu)
                .padding(.vertical, 6)
            }
            AsyncContent(load: { try await GlobalFundAPI().targetsResults(implementationPeriodCode: code) }) { rows in
                if rows.isEmpty {
                    ContentUnavailableView("No targets or results", systemImage: "target", description: Text("No performance framework is published for this implementation period."))
                } else {
                    IndicatorList(rows: rows)
                }
            }
            .id(code)
        }
    }
}

// MARK: Indicator list

/// All rows of one indicator.
private struct IndicatorSummary: Identifiable, Hashable {
    let rows: [TargetResultRow]

    var id: String { rows[0].indicatorKey }
    var indicator: String { rows[0].indicator }
    var module: String { rows[0].module }
    var type: String { rows[0].type }
    var coverage: String? { rows.lazy.compactMap(\.coverage).first }
    var isReversed: Bool { rows[0].isReversed }

    /// Disaggregation categories, e.g. ["Age", "Sex"].
    var categories: [String] {
        Array(Set(rows.compactMap(\.category))).sorted()
    }

    /// The most recent year's overall row that has a target or a result.
    var latest: TargetResultRow? {
        let totals = rows.filter { !$0.isDisaggregated && !($0.target.isEmpty && $0.result.isEmpty) }
        let pool = totals.isEmpty ? rows : totals
        return pool.max { ($0.year ?? 0, $0.result.isEmpty ? 0 : 1) < ($1.year ?? 0, $1.result.isEmpty ? 0 : 1) }
    }
}

private struct IndicatorList: View {
    let rows: [TargetResultRow]

    @State private var type: String?
    @State private var query = ""

    private var types: [String] { Array(Set(rows.map(\.type))).sorted() }

    private var summaries: [IndicatorSummary] {
        Dictionary(grouping: rows, by: \.indicatorKey)
            .values
            .map(IndicatorSummary.init(rows:))
            .filter { type == nil || $0.type == type }
            .filter { query.isEmpty || $0.indicator.localizedCaseInsensitiveContains(query) || $0.module.localizedCaseInsensitiveContains(query) }
            .sorted { $0.indicator < $1.indicator }
    }

    var body: some View {
        let summaries = self.summaries
        let modules = Array(Set(summaries.map(\.module))).sorted()
        List {
            if types.count > 1 {
                Section {
                    Picker("Indicator type", selection: $type) {
                        Text("All types").tag(String?.none)
                        ForEach(types, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                } footer: {
                    Text("Impact and outcome indicators track disease trends; coverage and output indicators track services delivered.")
                }
            }

            ForEach(modules, id: \.self) { module in
                Section(module) {
                    ForEach(summaries.filter { $0.module == module }) { summary in
                        NavigationLink {
                            IndicatorDetailView(summary: summary)
                        } label: {
                            IndicatorRow(summary: summary)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Indicator or module")
        .overlay {
            if summaries.isEmpty && !query.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}

private struct IndicatorRow: View {
    let summary: IndicatorSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.indicator)
                .lineLimit(3)
            HStack(spacing: 6) {
                Text(summary.type.replacingOccurrences(of: " indicator", with: ""))
                if !summary.categories.isEmpty {
                    Label("By \(summary.categories.joined(separator: ", ").lowercased())", systemImage: "square.split.2x2")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let latest = summary.latest {
                HStack {
                    if let year = latest.year { Text(String(year)) }
                    if let target = latest.target.display { Text("Target \(target)") }
                    if let result = latest.result.display { Text("Result \(result)") }
                    Spacer()
                    if let achievement = latest.achievement {
                        AchievementBadge(value: achievement)
                    }
                }
                .font(.caption.monospacedDigit())
            }
        }
        .padding(.vertical, 2)
    }
}

struct AchievementBadge: View {
    let value: Double

    private var color: Color {
        value >= 0.9 ? .green : value >= 0.6 ? .orange : .red
    }

    var body: some View {
        Text(value.formatted(.percent.precision(.fractionLength(0))))
            .font(.caption.bold().monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
            .accessibilityLabel("Achievement \(value.formatted(.percent.precision(.fractionLength(0))))")
    }
}

// MARK: Indicator detail

private struct IndicatorDetailView: View {
    let summary: IndicatorSummary

    /// "Total" for rows without a breakdown, otherwise the category name.
    @State private var category: String?

    private static let total = "Total"

    private var categoryOptions: [String] {
        let hasTotal = summary.rows.contains { !$0.isDisaggregated }
        return (hasTotal ? [Self.total] : []) + summary.categories
    }

    private var selectedCategory: String {
        category ?? categoryOptions.first ?? Self.total
    }

    private var selectedRows: [TargetResultRow] {
        summary.rows.filter { row in
            selectedCategory == Self.total ? !row.isDisaggregated : row.category == selectedCategory
        }
    }

    private var years: [Int?] {
        let unique = Set(selectedRows.map(\.year))
        return unique.sorted { ($0 ?? 0) > ($1 ?? 0) }
    }

    private var baseline: TargetResultRow? {
        summary.rows.first { !$0.isDisaggregated && !$0.baseline.isEmpty } ?? summary.rows.first { !$0.baseline.isEmpty }
    }

    var body: some View {
        let rows = selectedRows
        List {
            Section {
                Text(summary.indicator).font(.headline)
                LabeledContent("Module", value: summary.module)
                LabeledContent("Type", value: summary.type)
                if let coverage = summary.coverage {
                    LabeledContent("Coverage", value: coverage)
                }
                if let baseline, let value = baseline.baseline.display {
                    LabeledContent("Baseline", value: value)
                }
            } footer: {
                if summary.isReversed {
                    Text("Lower is better for this indicator, so achievement is target divided by result.")
                }
            }

            if categoryOptions.count > 1 {
                Section {
                    Picker("Breakdown", selection: Binding(get: { selectedCategory }, set: { category = $0 })) {
                        ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            if let chartView = chart(for: rows) {
                Section { chartView }
            }

            ForEach(years, id: \.self) { year in
                Section(year.map { String($0) } ?? "No year") {
                    ForEach(rows.filter { $0.year == year }.sorted { ($0.group ?? "") < ($1.group ?? "") }) { row in
                        ValueRow(row: row, showGroup: selectedCategory != Self.total)
                    }
                }
            }
        }
        .navigationTitle(selectedCategory == Self.total ? "Indicator" : "By \(selectedCategory.lowercased())")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Target vs result by year for the total; result by group for a breakdown.
    private func chart(for rows: [TargetResultRow]) -> AnyView? {
        let plotted = rows.filter { $0.year != nil && ($0.result.comparable != nil || $0.target.comparable != nil) }
        guard Set(plotted.compactMap(\.year)).count > 0 else { return nil }

        if selectedCategory == Self.total {
            return AnyView(
                Chart {
                    ForEach(plotted) { row in
                        if let target = row.target.comparable {
                            BarMark(x: .value("Year", String(row.year!)), y: .value("Value", target))
                                .foregroundStyle(by: .value("Measure", "Target"))
                                .position(by: .value("Measure", "Target"))
                        }
                        if let result = row.result.comparable {
                            BarMark(x: .value("Year", String(row.year!)), y: .value("Value", result))
                                .foregroundStyle(by: .value("Measure", "Result"))
                                .position(by: .value("Measure", "Result"))
                        }
                    }
                }
                .chartForegroundStyleScale(["Target": Color.accentColor.opacity(0.35), "Result": Color.accentColor])
                .frame(height: 200)
                .padding(.vertical, 8)
            )
        }

        let withResults = plotted.filter { $0.result.comparable != nil }
        guard !withResults.isEmpty else { return nil }
        return AnyView(
            Chart(withResults) { row in
                LineMark(x: .value("Year", String(row.year!)), y: .value("Result", row.result.comparable!))
                    .foregroundStyle(by: .value("Group", row.group ?? "Total"))
                PointMark(x: .value("Year", String(row.year!)), y: .value("Result", row.result.comparable!))
                    .foregroundStyle(by: .value("Group", row.group ?? "Total"))
            }
            .frame(height: 220)
            .padding(.vertical, 8)
        )
    }
}

private struct ValueRow: View {
    let row: TargetResultRow
    let showGroup: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(showGroup ? (row.group ?? row.breakdownLabel) : "Overall")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let achievement = row.achievement {
                    AchievementBadge(value: achievement)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow {
                    Text("Target").foregroundStyle(.secondary)
                    Text(row.target.display ?? "—").monospacedDigit()
                }
                GridRow {
                    Text("Result").foregroundStyle(.secondary)
                    Text(row.result.display ?? "—").monospacedDigit()
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }
}
