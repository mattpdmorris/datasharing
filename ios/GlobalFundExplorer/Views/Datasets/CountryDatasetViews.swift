import SwiftUI
import Charts

// Per-country screens opened from the "More data" section of a country.

// MARK: Allocations

struct AllocationsView: View {
    let countryCode: String

    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().allocations(countryCode: countryCode) }) { rows in
            if rows.isEmpty {
                ContentUnavailableView("No allocations", systemImage: "chart.bar", description: Text("No communicated allocations are published for this country or area."))
            } else {
                AllocationsContent(rows: rows)
            }
        }
        .navigationTitle("Allocations")
    }
}

private struct AllocationsContent: View {
    let rows: [AllocationRow]

    private var cycles: [String] { Array(Set(rows.map(\.cycle))).sorted(by: >) }
    private var diseases: [Disease] { Disease.allCases.filter { d in rows.contains { $0.disease == d } } }

    var body: some View {
        List {
            Section {
                Chart(rows) { row in
                    BarMark(
                        x: .value("Cycle", row.cycle),
                        y: .value("USD", row.amount)
                    )
                    .foregroundStyle(by: .value("Component", row.disease.rawValue))
                }
                .chartForegroundStyleScale(domain: diseases.map(\.rawValue), range: diseases.map(\.color))
                .usdYAxis()
                .frame(height: 220)
                .padding(.vertical, 8)
            } footer: {
                Text("The communicated allocation is the amount the Global Fund tells a country it can apply for in each allocation cycle.")
            }

            ForEach(cycles, id: \.self) { cycle in
                let cycleRows = rows.filter { $0.cycle == cycle }.sorted { $0.amount > $1.amount }
                Section(cycle) {
                    ForEach(cycleRows) { row in
                        LabeledContent {
                            Text(row.amount.usdCompact).monospacedDigit()
                        } label: {
                            Label(row.component, systemImage: row.disease.symbol)
                                .foregroundStyle(row.disease.color)
                        }
                    }
                    LabeledContent {
                        Text(cycleRows.reduce(0) { $0 + $1.amount }.usdCompact).bold().monospacedDigit()
                    } label: {
                        Text("Total").bold()
                    }
                }
            }
        }
    }
}

// MARK: Budget and expenditure

struct BudgetView: View {
    let countryCode: String

    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().budgetByCostCategory(countryCode: countryCode) }) { rows in
            if rows.isEmpty {
                ContentUnavailableView("No budget data", systemImage: "list.bullet.rectangle", description: Text("No grant budgets are published for this country or area."))
            } else {
                AmountBreakdownList(
                    rows: rows,
                    chartTitle: "Grant budgets by cost category",
                    footnote: "Signed grant budgets for all grant cycles combined."
                )
            }
        }
        .navigationTitle("Budget")
    }
}

struct ExpenditureView: View {
    let countryCode: String

    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().expenditureByModule(countryCode: countryCode) }) { rows in
            if rows.isEmpty {
                ContentUnavailableView("No expenditure data", systemImage: "banknote", description: Text("No grant expenditure is published for this country or area."))
            } else {
                AmountBreakdownList(
                    rows: rows,
                    chartTitle: "Spending by module",
                    footnote: "Cumulative expenditure reported by principal recipients, using each grant's latest report."
                )
            }
        }
        .navigationTitle("Expenditure")
    }
}

// MARK: Eligibility

struct EligibilityView: View {
    let countryCode: String

    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().eligibility(countryCode: countryCode) }) { rows in
            if rows.isEmpty {
                ContentUnavailableView("No eligibility data", systemImage: "checkmark.seal", description: Text("No eligibility records are published for this country or area."))
            } else {
                EligibilityContent(rows: rows)
            }
        }
        .navigationTitle("Eligibility")
    }
}

private struct EligibilityContent: View {
    let rows: [EligibilityRow]

    private var years: [Int] { Array(Set(rows.map(\.year))).sorted(by: >) }

    var body: some View {
        List {
            ForEach(years, id: \.self) { year in
                let yearRows = rows.filter { $0.year == year }.sorted { $0.component < $1.component }
                Section {
                    ForEach(yearRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.component).font(.headline)
                                Spacer()
                                Text(row.status)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((row.isEligible ? Color.green : Color.orange).opacity(0.15), in: Capsule())
                                    .foregroundStyle(row.isEligible ? Color.green : Color.orange)
                            }
                            if let burden = row.diseaseBurden {
                                Text("Disease burden: \(burden)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(String(year))
                } footer: {
                    if let income = yearRows.lazy.compactMap(\.incomeLevel).first {
                        Text("Income level: \(income)")
                    }
                }
            }
        }
    }
}

// MARK: Funding requests

struct FundingRequestsView: View {
    let countryCode: String

    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().fundingRequests(countryCode: countryCode) }) { rows in
            if rows.isEmpty {
                ContentUnavailableView("No funding requests", systemImage: "tray", description: Text("No funding requests are published for this country or area."))
            } else {
                List(rows) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.components).font(.headline)
                        Group {
                            if let date = row.submissionDate {
                                Text("Submitted \(date.formatted(date: .abbreviated, time: .omitted))")
                            }
                            if let window = row.window {
                                Text("TRP window: \(window)")
                            }
                            if let approach = row.reviewApproach {
                                Text("Review approach: \(approach)")
                            }
                            if let outcome = row.reviewOutcome {
                                Text("Outcome: \(outcome)")
                            }
                            if !row.grantCodes.isEmpty {
                                Text("Grants: \(row.grantCodes.joined(separator: ", "))")
                                    .font(.caption.monospaced())
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Funding requests")
    }
}

// MARK: Documents

struct DocumentsView: View {
    let countryCode: String

    var body: some View {
        AsyncContent(load: { try await GlobalFundAPI().documents(countryCode: countryCode) }) { rows in
            if rows.isEmpty {
                ContentUnavailableView("No documents", systemImage: "doc", description: Text("No documents are published for this country or area."))
            } else {
                DocumentsContent(rows: rows)
            }
        }
        .navigationTitle("Documents")
    }
}

private struct DocumentsContent: View {
    let rows: [DocumentRow]
    @State private var query = ""

    private var filtered: [DocumentRow] {
        guard !query.isEmpty else { return rows }
        return rows.filter { $0.title.localizedCaseInsensitiveContains(query) || ($0.subtype ?? "").localizedCaseInsensitiveContains(query) }
    }

    /// Document types in the order the API returned them.
    private var types: [String] {
        var seen = Set<String>()
        return filtered.map(\.type).filter { seen.insert($0).inserted }
    }

    var body: some View {
        List {
            ForEach(types, id: \.self) { type in
                Section(type) {
                    ForEach(filtered.filter { $0.type == type }) { doc in
                        if let url = doc.url {
                            Link(destination: url) { DocumentRowLabel(doc: doc) }
                        } else {
                            DocumentRowLabel(doc: doc)
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search documents")
    }
}

private struct DocumentRowLabel: View {
    let doc: DocumentRow

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                if let subtype = doc.subtype, subtype != doc.type {
                    Text(subtype)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if doc.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
