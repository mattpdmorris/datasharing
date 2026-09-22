import XCTest
@testable import GlobalFundExplorer

final class RecordMappingTests: XCTestCase {
    private func record(_ json: String) throws -> Record {
        let raw = try JSONDecoder().decode([String: JSONValue].self, from: Data(json.utf8))
        return Record(raw)
    }

    func testGrantMapsFromODataRow() throws {
        let row = try record("""
        {
          "grantAgreementId": 1234,
          "grantAgreementNumber": "KEN-H-TNT",
          "geographicAreaName": "Kenya",
          "componentName": "HIV/AIDS",
          "principalRecipientName": "The National Treasury",
          "grantAgreementStatusTypeName": "Active",
          "programStartDate": "2024-01-01T00:00:00Z",
          "programEndDate": "2026-12-31T00:00:00.000Z",
          "totalSignedAmount_ReferenceRate": 310000000.5,
          "totalCommittedAmount_ReferenceRate": "250000000",
          "totalDisbursedAmount_ReferenceRate": null
        }
        """)
        let grant = try XCTUnwrap(Grant(record: row))
        XCTAssertEqual(grant.id, "1234")
        XCTAssertEqual(grant.number, "KEN-H-TNT")
        XCTAssertEqual(grant.country, "Kenya")
        XCTAssertEqual(grant.disease, .hiv)
        XCTAssertEqual(grant.signed, 310_000_000.5)
        XCTAssertEqual(grant.committed, 250_000_000)
        XCTAssertNil(grant.disbursed)
        XCTAssertNotNil(grant.startDate)
        XCTAssertNotNil(grant.endDate)
        XCTAssertTrue(grant.isActive)
    }

    func testLookupIsCaseInsensitiveAndFallsBack() throws {
        let row = try record(#"{"GRANTNUMBER": "X-1", "countryName": "Chad", "component": "Malaria"}"#)
        let grant = try XCTUnwrap(Grant(record: row))
        XCTAssertEqual(grant.number, "X-1")
        XCTAssertEqual(grant.country, "Chad")
        XCTAssertEqual(grant.disease, .malaria)
    }

    func testRowWithoutGrantNumberIsSkipped() throws {
        XCTAssertNil(Grant(record: try record(#"{"geographicAreaName": "Kenya"}"#)))
    }

    func testInactiveStatusIsNotActive() throws {
        let row = try record(#"{"grantAgreementNumber": "X-2", "grantAgreementStatusTypeName": "Inactive"}"#)
        XCTAssertFalse(try XCTUnwrap(Grant(record: row)).isActive)
    }

    func testDiseaseClassification() {
        XCTAssertEqual(Disease(componentName: "HIV/AIDS"), .hiv)
        XCTAssertEqual(Disease(componentName: "TB/HIV"), .hivTB)
        XCTAssertEqual(Disease(componentName: "Tuberculosis"), .tuberculosis)
        XCTAssertEqual(Disease(componentName: "Malaria"), .malaria)
        XCTAssertEqual(Disease(componentName: "RSSH"), .rssh)
        XCTAssertEqual(Disease(componentName: "Multicomponent"), .other)
    }

    func testDatesParseCommonODataFormats() {
        XCTAssertNotNil(ODataDate.parse("2024-03-15T00:00:00Z"))
        XCTAssertNotNil(ODataDate.parse("2024-03-15T00:00:00.123Z"))
        XCTAssertNotNil(ODataDate.parse("2024-03-15T10:20:30"))
        XCTAssertNotNil(ODataDate.parse("2024-03-15"))
        XCTAssertNil(ODataDate.parse("not a date"))
    }

    func testCountryGroupingTotals() {
        let countries = CountrySummary.group(SampleData.grants)
        let kenya = try? XCTUnwrap(countries.first { $0.name == "Kenya" })
        XCTAssertEqual(kenya?.grants.count, 3)
        XCTAssertEqual(kenya?.signed, 465_000_000)
        XCTAssertEqual(countries.map(\.name), ["India", "Kenya", "Mozambique"])
    }
}

final class GlobalFundAPITests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func makeAPI() -> GlobalFundAPI {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return GlobalFundAPI(
            baseURL: URL(string: "https://example.test/odata/")!,
            session: URLSession(configuration: config)
        )
    }

    func testFollowsNextLink() async throws {
        var requested: [URL] = []
        MockURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            requested.append(url)
            let body = url.query?.contains("page=2") == true
                ? #"{"value": [{"grantAgreementNumber": "B"}]}"#
                : #"{"value": [{"grantAgreementNumber": "A"}], "@odata.nextLink": "https://example.test/odata/VGrantAgreements?page=2"}"#
            return (200, body)
        }

        let grants = try await makeAPI().grants()
        XCTAssertEqual(grants.map(\.number), ["A", "B"])
        XCTAssertEqual(requested.count, 2)
        XCTAssertEqual(requested.first?.lastPathComponent, APIConfig.EntitySet.grantAgreements)
    }

    func testDisbursementsAreFilteredAndSorted() async throws {
        var filter: String?
        MockURLProtocol.handler = { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            filter = components?.queryItems?.first { $0.name == "$filter" }?.value
            return (200, """
            {"value": [
              {"disbursementDate": "2024-06-01T00:00:00Z", "disbursementAmount_ReferenceRate": 20},
              {"disbursementDate": "2024-01-01T00:00:00Z", "disbursementAmount_ReferenceRate": 10}
            ]}
            """)
        }

        let payments = try await makeAPI().disbursements(forGrantNumber: "KEN-H-O'X")
        XCTAssertEqual(filter, "grantAgreementNumber eq 'KEN-H-O''X'")
        XCTAssertEqual(payments.map(\.amount), [10, 20])
        XCTAssertEqual(payments.cumulative.map(\.total), [10, 30])
    }

    func testHTTPErrorIsSurfaced() async {
        MockURLProtocol.handler = { _ in (404, "Not Found") }
        do {
            _ = try await makeAPI().grants()
            XCTFail("Expected an error")
        } catch let error as APIError {
            guard case .http(let status, _, _) = error else { return XCTFail("Wrong error: \(error)") }
            XCTAssertEqual(status, 404)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

/// Serves canned responses so API tests run offline.
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.unknown) }
            let (status, body) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
