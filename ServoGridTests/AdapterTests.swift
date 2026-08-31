import Foundation
import XCTest
@testable import ServoGrid

final class AdapterTests: XCTestCase {
    func testFuelWatchParsesDocumentedRSSFieldsAndPreservesBuildAndPriceDates() async throws {
        let now = ISO8601DateFormatter().date(from: "2026-08-30T10:30:00Z")!
        let network = StubNetworkClient(
            response: NetworkResponse(data: Data(Self.fuelWatchXML.utf8), statusCode: 200, headers: [:])
        )
        let adapter = FuelWatchAdapter(network: network, regionIDs: ["98"], now: { now })

        let snapshot = try await adapter.fetch(grade: .unleaded91, day: .today)

        XCTAssertEqual(snapshot.source.id, "wa-fuelwatch")
        XCTAssertEqual(snapshot.source.coverage, .live)
        XCTAssertEqual(snapshot.stations.count, 2)
        XCTAssertEqual(snapshot.stations[0].name, "Costco Perth Airport")
        XCTAssertEqual(snapshot.stations[0].observations[0].priceCentsPerLitre, 186.7)
        XCTAssertEqual(snapshot.stations[0].observations[0].restrictions, "Membership Required;")
        XCTAssertEqual(snapshot.stations[0].observations[0].sourceDatasetAt, date("2026-08-30T10:12:58Z"))
        XCTAssertEqual(snapshot.stations[0].observations[0].sourceEventAt, date("2026-08-29T16:00:00Z"))
        XCTAssertEqual(snapshot.stations[0].observations[0].checkedAt, now)

        let requests = await network.requests
        let request = try XCTUnwrap(requests.first)
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(query["Product"], "1")
        XCTAssertEqual(query["StateRegion"], "98")
        XCTAssertEqual(query["Day"], "today")
    }

    func testFuelWatchTomorrowIsScheduledAndUnsupportedGradesFailClosed() async throws {
        let network = StubNetworkClient(
            response: NetworkResponse(data: Data(Self.fuelWatchXML.utf8), statusCode: 200, headers: [:])
        )
        let adapter = FuelWatchAdapter(network: network, regionIDs: ["98"], now: { Date(timeIntervalSince1970: 0) })

        let tomorrow = try await adapter.fetch(grade: .unleaded91, day: .tomorrow)
        XCTAssertEqual(tomorrow.source.coverage, .scheduled)

        do {
            _ = try await adapter.fetch(grade: .e10, day: .today)
            XCTFail("E10 is not a documented FuelWatch RSS product code")
        } catch let error as SourceFailure {
            XCTAssertEqual(error, .unsupportedFuel(.e10))
        }
    }

    func testFuelCheckRequiresExternalCredentialsBeforeNetworkAccess() async throws {
        let network = StubNetworkClient(
            response: NetworkResponse(data: Data(), statusCode: 500, headers: [:])
        )
        let adapter = FuelCheckAdapter(
            jurisdiction: .newSouthWales,
            network: network,
            credentials: StaticCredentialProvider(values: [:]),
            now: Date.init
        )

        do {
            _ = try await adapter.fetch(grade: .unleaded91, day: .today)
            XCTFail("A missing key and secret must not fall through to a public/demo request")
        } catch let error as SourceFailure {
            XCTAssertEqual(error, .credentialsRequired(.newSouthWales))
        }
        let requests = await network.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testExplicitFixtureAdapterRemainsDemo() async throws {
        let adapter = FixtureAdapter(resourceName: "demo-national", bundle: .main)
        let snapshot = try await adapter.fetch(grade: .unleaded91, day: .today)

        XCTAssertTrue(snapshot.isDemo)
        XCTAssertEqual(snapshot.trustLabel, "Demo data")
        XCTAssertFalse(snapshot.stations.isEmpty)
        XCTAssertTrue(snapshot.stations.allSatisfy { station in
            station.observations.allSatisfy { $0.fuelGrade == .unleaded91 && $0.validity == .today }
        })
    }

    func testFixtureHistoryCanSeedEvidenceBackedDemoBriefs() throws {
        let snapshot = try FixtureAdapter.loadSnapshot(
            resourceName: "demo-national-previous",
            bundle: .main
        )

        XCTAssertTrue(snapshot.isDemo)
        XCTAssertEqual(snapshot.stations.count, 3)
        XCTAssertEqual(Set(snapshot.stations.map(\.state)), ["VIC"])
        XCTAssertTrue(snapshot.stations.allSatisfy { station in
            station.observations.allSatisfy { $0.fuelGrade == .unleaded91 && $0.validity == .today }
        })
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private static let fuelWatchXML = """
    <?xml version="1.0" encoding="utf-8"?>
    <rss version="2.0"><channel>
      <title>FuelWatch Prices For Metro</title>
      <description>30/08/2026 - Metro</description>
      <lastBuildDate>Sun, 30 Aug 2026 18:12:58 +0800</lastBuildDate>
      <item>
        <price>186.7</price><brand>Costco</brand><date>2026-08-30</date>
        <trading-name>Costco Perth Airport</trading-name><location>PERTH AIRPORT</location>
        <address>142 Dunreath Dr</address><phone>(08) 9311 4700</phone>
        <latitude>-31.94037700</latitude><longitude>115.95186900</longitude>
        <site-features>EFTPOS</site-features><restrictions>Membership Required; </restrictions>
      </item>
      <item>
        <price>189.2</price><brand>Vibe</brand><date>2026-08-30</date>
        <trading-name>Vibe Oakford Truckstop</trading-name><location>OAKFORD</location>
        <address>1780 Thomas Rd</address><phone>(08) 9525 4269</phone>
        <latitude>-32.20930500</latitude><longitude>115.95227900</longitude>
        <site-features>Open 24 hours</site-features><restrictions></restrictions>
      </item>
    </channel></rss>
    """
}

actor StubNetworkClient: NetworkClient {
    private(set) var requests: [URLRequest] = []
    let response: NetworkResponse

    init(response: NetworkResponse) {
        self.response = response
    }

    func send(_ request: URLRequest) async throws -> NetworkResponse {
        requests.append(request)
        return response
    }
}

struct StaticCredentialProvider: CredentialProviding {
    let values: [String: String]

    func value(for key: String) async -> String? { values[key] }
}
