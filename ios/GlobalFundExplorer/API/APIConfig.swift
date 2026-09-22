import Foundation

/// Every Global Fund–specific name the app depends on lives here.
///
/// The Global Fund Data Service (https://data-service.theglobalfund.org) versions its
/// OData API and occasionally renames entity sets or fields. If a screen shows
/// "HTTP 404" or blank values, open the API explorer on the Data Service portal,
/// compare the names below with the current ones, and edit them here. The base URL
/// can also be changed at runtime from the Settings screen.
enum APIConfig {
    static let defaultBaseURL = "https://fetch.theglobalfund.org/v3.3/odata/"

    /// UserDefaults key for a runtime override of the base URL (see SettingsView).
    static let baseURLDefaultsKey = "apiBaseURL"

    static var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: baseURLDefaultsKey)
        let raw = (stored?.isEmpty == false ? stored! : defaultBaseURL)
        let normalised = raw.hasSuffix("/") ? raw : raw + "/"
        return URL(string: normalised) ?? URL(string: defaultBaseURL)!
    }

    enum EntitySet {
        static let grantAgreements = "VGrantAgreements"
        static let disbursements = "VGrantAgreementDisbursements"
    }

    /// Server-side page size requested per call. The API also pages on its own via
    /// `@odata.nextLink`, which the client follows.
    static let pageSize = 1000

    /// Safety stop so a misconfigured endpoint can't page forever.
    static let maxPages = 100

    /// Field used to filter disbursements to a single grant.
    static let disbursementGrantFilterField = "grantAgreementNumber"

    /// Candidate JSON keys for each value, tried in order (case-insensitive).
    /// Listing several spellings lets the app survive minor API renames.
    enum Fields {
        static let grantID = ["grantAgreementId", "grantAgreementNumber", "id"]
        static let grantNumber = ["grantAgreementNumber", "grantNumber"]
        static let country = ["geographicAreaName", "countryName", "geographicArea", "locationName"]
        static let countryCode = ["geographicAreaCode_ISO3", "geographicAreaCode", "iso3CountryCode", "countryCode"]
        static let component = ["componentName", "component", "diseaseComponent"]
        static let principalRecipient = ["principalRecipientName", "implementationEntityName", "principalRecipient"]
        static let status = ["grantAgreementStatusTypeName", "grantAgreementStatus", "status"]
        static let startDate = ["programStartDate", "grantAgreementStartDate", "startDate"]
        static let endDate = ["programEndDate", "grantAgreementEndDate", "endDate"]
        static let signed = ["totalSignedAmount_ReferenceRate", "totalSignedAmount", "signedAmount"]
        static let committed = ["totalCommittedAmount_ReferenceRate", "totalCommittedAmount", "committedAmount"]
        static let disbursed = ["totalDisbursedAmount_ReferenceRate", "totalDisbursedAmount", "disbursedAmount"]
        static let grantCycle = ["grantCycleName", "grantCycle", "replenishmentPeriodName"]

        static let disbursementID = ["grantAgreementDisbursementId", "disbursementId", "id"]
        static let disbursementDate = ["disbursementDate", "paymentDate", "date"]
        static let disbursementAmount = ["disbursementAmount_ReferenceRate", "disbursementAmount", "disbursedAmount_ReferenceRate", "amount"]
        static let disbursementRecipient = ["principalRecipientName", "implementationEntityName", "recipientName"]
    }
}
