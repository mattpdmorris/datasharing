import Foundation

/// Every Global Fund–specific name the app depends on lives here.
///
/// These match version 4.2 of the Global Fund Data Service OData API
/// (https://data-service.theglobalfund.org), as used by the Global Fund's own
/// Data Explorer (github.com/globalfund/data-explorer-server). Older versions
/// such as v3.3 are retired and return HTTP 403. If a future version renames
/// things, edit them here; the base URL can also be changed at runtime from the
/// About screen.
enum APIConfig {
    static let defaultBaseURL = "https://fetch.theglobalfund.org/v4.2/odata/"

    /// UserDefaults key for a runtime override of the base URL (see SettingsView).
    static let baseURLDefaultsKey = "apiBaseURL"

    static var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: baseURLDefaultsKey)
        let raw = (stored?.isEmpty == false ? stored! : defaultBaseURL)
        let normalised = raw.hasSuffix("/") ? raw : raw + "/"
        return URL(string: normalised) ?? URL(string: defaultBaseURL)!
    }

    enum EntitySet {
        static let grants = "Grants"
        /// One row per financial value; disbursements are the rows whose
        /// `indicatorName` is `disbursementIndicator`.
        static let financialIndicators = "allFinancialIndicators"
        static let programmaticIndicators = "allProgrammaticIndicators"
        static let eligibility = "Eligibility"
        static let fundingRequests = "FundingRequests"
        static let documents = "Documents"
    }

    /// Only the grant columns the app shows, with the related records expanded.
    static let grantsQuery: [URLQueryItem] = [
        URLQueryItem(
            name: "$select",
            value: "code,status,geography,activityArea,principalRecipient,periodStartDate,periodEndDate,"
                + "totalSignedAmount_ReferenceRate,totalCommitmentAmount_ReferenceRate,totalDisbursedAmount_ReferenceRate"
        ),
        URLQueryItem(
            name: "$expand",
            value: "status($select=statusName),geography($select=name,code),activityArea($select=name),principalRecipient($select=name)"
        ),
        // Stable order so $skip paging never repeats or misses rows.
        URLQueryItem(name: "$orderby", value: "code asc"),
    ]

    static let disbursementIndicator = "Disbursement Amount - Reference Rate"

    /// OData path from a financial-indicator row to its grant's code.
    static let disbursementGrantCodePath = "implementationPeriod/grant/code"

    static let disbursementSelect = "valueDate,actualAmount"

    /// Rows requested per call. The client pages with $skip, or follows
    /// `@odata.nextLink` when the server sends one.
    static let pageSize = 1000

    /// Safety stop so a misconfigured endpoint can't page forever.
    static let maxPages = 100

    /// Candidate JSON keys for each value, tried in order (case-insensitive).
    /// Dots walk into expanded records, e.g. `geography.name`. Older v3 names are
    /// kept as fallbacks.
    enum Fields {
        static let grantID = ["code", "grantAgreementId", "grantAgreementNumber", "id"]
        static let grantNumber = ["code", "grantAgreementNumber", "grantNumber"]
        static let country = ["geography.name", "geographicAreaName", "countryName"]
        static let countryCode = ["geography.code", "geographicAreaCode_ISO3", "countryCode"]
        static let component = ["activityArea.name", "componentName", "component"]
        static let principalRecipient = ["principalRecipient.name", "principalRecipientName"]
        static let status = ["status.statusName", "grantAgreementStatusTypeName", "status"]
        static let startDate = ["periodStartDate", "programStartDate", "startDate"]
        static let endDate = ["periodEndDate", "programEndDate", "endDate"]
        static let signed = ["totalSignedAmount_ReferenceRate", "totalSignedAmount"]
        static let committed = ["totalCommitmentAmount_ReferenceRate", "totalCommittedAmount_ReferenceRate"]
        static let disbursed = ["totalDisbursedAmount_ReferenceRate", "totalDisbursedAmount"]
        static let grantCycle = ["grantCycleName", "grantCycle"]

        static let disbursementID = ["id", "disbursementId"]
        static let disbursementDate = ["valueDate", "disbursementDate"]
        static let disbursementAmount = ["actualAmount", "disbursementAmount_ReferenceRate"]
        static let disbursementRecipient = ["principalRecipient.name", "principalRecipientName"]
    }
}
