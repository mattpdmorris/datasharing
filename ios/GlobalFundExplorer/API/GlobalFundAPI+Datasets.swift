import Foundation

/// Queries for the Data Service datasets beyond grants.
///
/// Filters, groupings and field names follow the Global Fund's own Data Explorer
/// (github.com/globalfund/data-explorer-server, `src/config/mapping`), so they
/// match what the live v4.2 API accepts. Most use OData `$apply` to have the
/// server total the numbers, which keeps responses small.
extension GlobalFundAPI {
    // MARK: Allocations

    func allocations(countryCode: String) async throws -> [AllocationRow] {
        let rows = try await aggregate(
            APIConfig.EntitySet.financialIndicators,
            apply: [
                "filter(indicatorName eq 'Communicated Allocation - Reference Rate'",
                " AND financialDataSet eq 'CommunicatedAllocation_ReferenceRate'",
                " AND geography/code eq \(quoted(countryCode)))",
                "/groupby((activityArea/name,periodCovered),aggregate(actualAmount with sum as value))",
            ].joined()
        )
        return rows.compactMap { r in
            guard let cycle = r.string(["periodCovered"]), let amount = r.double(["value"]) else { return nil }
            return AllocationRow(cycle: cycle, component: r.string(["activityArea.name"]) ?? "Other", amount: amount)
        }
    }

    // MARK: Budgets and expenditure

    /// Grant budgets for a country, all cycles combined, by top-level cost category.
    func budgetByCostCategory(countryCode: String) async throws -> [AmountRow] {
        let rows = try await aggregate(
            APIConfig.EntitySet.financialIndicators,
            apply: [
                "filter(contains(indicatorName, 'reference')",
                " AND financialDataSet eq 'GrantBudget_ReferenceRate'",
                " AND implementationPeriod/grant/geography/code eq \(quoted(countryCode)))",
                "/groupby((financialCategory/parent/parent/name),aggregate(plannedAmount with sum as value))",
            ].joined()
        )
        return amountRows(rows, label: ["financialCategory.parent.parent.name"])
    }

    /// Latest reported cumulative expenditure for a country, by module.
    func expenditureByModule(countryCode: String) async throws -> [AmountRow] {
        let rows = try await aggregate(
            APIConfig.EntitySet.financialIndicators,
            apply: [
                "filter(indicatorName in ('Expenditure: Module-Intervention - Reference Rate')",
                " AND isLatestReported eq true",
                " AND implementationPeriod/grant/geography/code eq \(quoted(countryCode)))",
                "/groupby((activityArea/parent/name),aggregate(actualAmountCumulative with sum as value))",
            ].joined()
        )
        return amountRows(rows, label: ["activityArea.parent.name"])
    }

    // MARK: Results

    /// Annual results, summed across countries when `countryCode` is nil.
    func results(countryCode: String?) async throws -> [ResultRow] {
        let geography = countryCode.map { " AND geography/code eq \(quoted($0))" } ?? ""
        let rows = try await aggregate(
            APIConfig.EntitySet.programmaticIndicators,
            apply: [
                "filter(programmaticDataset eq 'Annual_Results'\(geography))",
                "/groupby((indicatorName,activityArea/name,resultValueYear),aggregate(resultValueNumerator with sum as value))",
            ].joined()
        )
        return rows.compactMap { r in
            guard let indicator = r.string(["indicatorName"]),
                  let year = r.int(["resultValueYear"]),
                  let value = r.double(["value"]) else { return nil }
            return ResultRow(indicator: indicator, component: r.string(["activityArea.name"]) ?? "Other", year: year, value: value)
        }
    }

    // MARK: Eligibility

    func eligibility(countryCode: String) async throws -> [EligibilityRow] {
        let rows = try await aggregate(
            APIConfig.EntitySet.eligibility,
            apply: [
                "filter(geography/code eq \(quoted(countryCode)))",
                "/groupby((eligibilityYear,activityArea/name,isEligible,incomeLevel,diseaseBurden))",
            ].joined()
        )
        return rows.compactMap { r in
            guard let year = r.int(["eligibilityYear"]) else { return nil }
            let raw = r.string(["isEligible"]) ?? "Unknown"
            let status = raw == "true" ? "Eligible" : raw == "false" ? "Not eligible" : raw
            return EligibilityRow(
                year: year,
                component: r.string(["activityArea.name"]) ?? "Other",
                status: status,
                incomeLevel: r.string(["incomeLevel"]),
                diseaseBurden: r.string(["diseaseBurden"])
            )
        }
    }

    // MARK: Funding requests

    func fundingRequests(countryCode: String) async throws -> [FundingRequestRow] {
        let rows = try await fetchAll(
            entitySet: APIConfig.EntitySet.fundingRequests,
            query: [
                URLQueryItem(name: "$filter", value: "geography/code eq \(quoted(countryCode))"),
                URLQueryItem(name: "$select", value: "name,submissionDate,reviewApproach,window,reviewOutcome,reviewDate"),
                URLQueryItem(name: "$expand", value: "implementationPeriods($select=periodStartDate,periodEndDate;$expand=grant($select=code))"),
                URLQueryItem(name: "$orderby", value: "submissionDate desc"),
            ]
        )
        return rows.enumerated().map { index, r in
            let codes = r.records(["implementationPeriods"]).compactMap { $0.string(["grant.code"]) }
            return FundingRequestRow(
                id: "\(index)|\(r.string(["name"]) ?? "")",
                components: r.string(["name"]) ?? "Funding request",
                submissionDate: r.date(["submissionDate"]),
                window: r.string(["window"]),
                reviewApproach: r.string(["reviewApproach"]),
                reviewOutcome: r.string(["reviewOutcome"]),
                reviewDate: r.date(["reviewDate"]),
                grantCodes: Array(Set(codes)).sorted()
            )
        }
    }

    // MARK: Documents

    func documents(countryCode: String) async throws -> [DocumentRow] {
        let rows = try await aggregate(
            APIConfig.EntitySet.documents,
            apply: "filter(geography/code eq \(quoted(countryCode)))"
                + "/groupby((documentType/index,documentType/parent/name,documentType/name,title,url))",
            orderby: "documentType/index asc,title desc"
        )
        return rows.compactMap { r in
            guard let title = r.string(["title"]) else { return nil }
            return DocumentRow(
                type: r.string(["documentType.parent.name"]) ?? r.string(["documentType.name"]) ?? "Other",
                subtype: r.string(["documentType.name"]),
                title: title,
                url: r.string(["url"]).flatMap { URL(string: $0) }
            )
        }
    }

    // MARK: Pledges and contributions

    /// Every donor's pledges and contributions per replenishment period.
    func pledgesAndContributions() async throws -> [PledgeRow] {
        let pledge = "Pledge - Reference Rate"
        let contribution = "Contribution - Reference Rate"
        let rows = try await aggregate(
            APIConfig.EntitySet.financialIndicators,
            apply: [
                "filter(financialDataSet eq 'Pledges_Contributions'",
                " AND indicatorName in ('\(pledge)','\(contribution)'))",
                "/groupby((donor/name,donor/type/name,periodCovered,indicatorName),",
                "aggregate(plannedAmount with sum as plannedAmount,actualAmount with sum as actualAmount))",
            ].joined()
        )
        // One row per donor, period and indicator: merge the pledge and contribution rows.
        var merged: [String: PledgeRow] = [:]
        for r in rows {
            guard let donor = r.string(["donor.name"]), let period = r.string(["periodCovered"]) else { continue }
            let indicator = r.string(["indicatorName"])
            let key = donor + "|" + period
            var row = merged[key] ?? PledgeRow(
                donor: donor,
                donorType: r.string(["donor.type.name"]) ?? "Other",
                period: period,
                pledged: 0,
                contributed: 0
            )
            if indicator == pledge {
                row.pledged += r.double(["plannedAmount"]) ?? 0
            } else if indicator == contribution {
                row.contributed += r.double(["actualAmount"]) ?? 0
            }
            merged[key] = row
        }
        return Array(merged.values)
    }

    // MARK: Grant targets and results

    /// A grant's implementation periods, newest first.
    func implementationPeriods(grantCode: String) async throws -> [ImplementationPeriod] {
        let rows = try await fetchAll(
            entitySet: APIConfig.EntitySet.grants,
            query: [
                URLQueryItem(name: "$filter", value: "code eq \(quoted(grantCode))"),
                URLQueryItem(name: "$select", value: "code"),
                URLQueryItem(name: "$expand", value: "implementationPeriods"),
            ]
        )
        let periods = rows.flatMap { $0.records(["implementationPeriods"]) }.compactMap { p -> ImplementationPeriod? in
            guard let code = p.string(["code"]) else { return nil }
            return ImplementationPeriod(
                code: code,
                title: p.string(["title"]),
                startDate: p.date(["periodStartDate", "periodFrom"]),
                endDate: p.date(["periodEndDate", "periodTo"])
            )
        }
        return periods.sorted { ($0.startDate ?? .distantPast, $0.code) > ($1.startDate ?? .distantPast, $1.code) }
    }

    /// The performance framework of one implementation period: every indicator's
    /// baseline, targets and results, including disaggregated rows.
    func targetsResults(implementationPeriodCode: String) async throws -> [TargetResultRow] {
        let filter = "programmaticDataSet eq 'IMPLEMENTATION_PERIOD_TARGETS_RESULTS'"
            + " AND implementationPeriod/code eq \(quoted(implementationPeriodCode))"
        let rows = try await fetchAll(
            entitySet: APIConfig.EntitySet.programmaticIndicators,
            query: [
                URLQueryItem(name: "$filter", value: filter),
                URLQueryItem(name: "$expand", value: "activityArea($select=name)"),
                URLQueryItem(name: "$orderby", value: "indicatorName asc"),
            ]
        )
        return rows.enumerated().compactMap { index, record in TargetResultRow(record: record, index: index) }
    }

    // MARK: Helpers

    private func aggregate(_ entitySet: String, apply: String, orderby: String? = nil) async throws -> [Record] {
        var query = [URLQueryItem(name: "$apply", value: apply)]
        if let orderby { query.append(URLQueryItem(name: "$orderby", value: orderby)) }
        return try await fetchAll(entitySet: entitySet, query: query, paged: false)
    }

    private func amountRows(_ rows: [Record], label: [String]) -> [AmountRow] {
        // Rows whose category is missing are pooled as "Other".
        var totals: [String: Double] = [:]
        for r in rows {
            guard let value = r.double(["value"]), value != 0 else { continue }
            totals[r.string(label) ?? "Other", default: 0] += value
        }
        return totals.map { AmountRow(label: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    private func quoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
    }
}
