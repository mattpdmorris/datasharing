import Foundation

enum APIError: LocalizedError {
    case badURL(String)
    case http(status: Int, url: URL, body: String)
    case decoding(url: URL, underlying: Error)
    case tooManyPages(entitySet: String)

    var errorDescription: String? {
        switch self {
        case .badURL(let raw):
            return "Invalid URL: \(raw)"
        case .http(let status, let url, let body):
            let hint = status == 404
                ? "\nThe entity set or API version may have changed. Check APIConfig or the base URL in Settings."
                : ""
            return "HTTP \(status) from \(url.absoluteString)\(hint)\n\(body.prefix(300))"
        case .decoding(let url, let underlying):
            return "Unexpected response from \(url.absoluteString): \(underlying.localizedDescription)"
        case .tooManyPages(let entitySet):
            return "Stopped after \(APIConfig.maxPages) pages of \(entitySet)."
        }
    }
}

/// OData v4 response envelope.
private struct ODataPage: Decodable {
    let value: [[String: JSONValue]]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

/// Minimal client for the Global Fund Data Service OData API.
struct GlobalFundAPI: Sendable {
    var baseURL: URL = APIConfig.baseURL
    var session: URLSession = .shared

    // MARK: Domain calls

    func grants() async throws -> [Grant] {
        let rows = try await fetchAll(entitySet: APIConfig.EntitySet.grants, query: APIConfig.grantsQuery)
        return rows.compactMap(Grant.init(record:))
    }

    func disbursements(forGrantNumber number: String) async throws -> [Disbursement] {
        let escaped = number.replacingOccurrences(of: "'", with: "''")
        let filter = "indicatorName eq '\(APIConfig.disbursementIndicator)'"
            + " AND \(APIConfig.disbursementGrantCodePath) eq '\(escaped)'"
        let rows = try await fetchAll(
            entitySet: APIConfig.EntitySet.financialIndicators,
            query: [
                URLQueryItem(name: "$filter", value: filter),
                URLQueryItem(name: "$select", value: APIConfig.disbursementSelect),
                URLQueryItem(name: "$orderby", value: "valueDate asc"),
            ]
        )
        return rows.enumerated()
            .compactMap { index, record in Disbursement(record: record, fallbackIndex: index) }
            .sorted { $0.date < $1.date }
    }

    // MARK: Generic OData paging

    /// Fetches every row of an entity set. `paged: false` sends the query as-is
    /// (used for `$apply` aggregations, which return few rows) and only follows
    /// `@odata.nextLink`.
    func fetchAll(entitySet: String, query: [URLQueryItem] = [], paged: Bool = true) async throws -> [Record] {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(entitySet),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.badURL(baseURL.absoluteString + entitySet)
        }
        let firstItems = paged ? query + [URLQueryItem(name: "$top", value: String(APIConfig.pageSize))] : query
        components.queryItems = firstItems.isEmpty ? nil : firstItems
        guard let firstURL = components.url else {
            throw APIError.badURL(components.description)
        }

        var records: [Record] = []
        var next: URL? = firstURL
        var skip = 0
        var pages = 0

        while let url = next {
            pages += 1
            if pages > APIConfig.maxPages { throw APIError.tooManyPages(entitySet: entitySet) }

            let page = try await fetchPage(url)
            records.append(contentsOf: page.value.map(Record.init))

            if let link = page.nextLink {
                // nextLink may be absolute or relative to the base URL.
                next = URL(string: link, relativeTo: baseURL)?.absoluteURL
            } else if paged && page.value.count == APIConfig.pageSize {
                // Server honoured $top but didn't return a nextLink: page with $skip.
                skip += APIConfig.pageSize
                var more = components
                more.queryItems = query + [
                    URLQueryItem(name: "$top", value: String(APIConfig.pageSize)),
                    URLQueryItem(name: "$skip", value: String(skip)),
                ]
                next = more.url
            } else {
                next = nil
            }
        }
        return records
    }

    private func fetchPage(_ url: URL) async throws -> ODataPage {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(
                status: http.statusCode,
                url: url,
                body: String(decoding: data, as: UTF8.self)
            )
        }
        do {
            return try JSONDecoder().decode(ODataPage.self, from: data)
        } catch {
            throw APIError.decoding(url: url, underlying: error)
        }
    }
}
