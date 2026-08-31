import Foundation

struct FixtureAdapter: FuelSourceAdapter {
    let source = SourceCatalog.demo
    let capabilities = SourceCapabilities(
        supportedGrades: Set(FuelGrade.allCases),
        supportsToday: true,
        supportsTomorrow: true,
        supportsHistory: true,
        requiresCredentials: false
    )

    private let resourceName: String
    private let bundle: Bundle

    init(resourceName: String = "demo-national", bundle: Bundle = .main) {
        self.resourceName = resourceName
        self.bundle = bundle
    }

    func fetch(grade: FuelGrade, day: PriceValidity) async throws -> FuelSnapshot {
        let decoded = try Self.loadSnapshot(resourceName: resourceName, bundle: bundle)
        let stations = decoded.stations.compactMap { station -> FuelStation? in
            let filtered = station.observations.filter { $0.fuelGrade == grade && $0.validity == day }
            guard !filtered.isEmpty else { return nil }
            return try? FuelStation(
                id: station.id,
                sourceStationID: station.sourceStationID,
                name: station.name,
                brand: station.brand,
                address: station.address,
                suburb: station.suburb,
                state: station.state,
                postcode: station.postcode,
                latitude: station.latitude,
                longitude: station.longitude,
                observations: filtered
            )
        }
        return FuelSnapshot(schemaVersion: decoded.schemaVersion, source: decoded.source, stations: stations, checkedAt: decoded.checkedAt)
    }

    static func loadSnapshot(resourceName: String, bundle: Bundle = .main) throws -> FuelSnapshot {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw SourceFailure.invalidResponse("The explicit demo fixture is missing from the app bundle.")
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FuelSnapshot.self, from: data)
        guard decoded.source.coverage == .demo else {
            throw SourceFailure.invalidResponse("Fixture data must declare demo coverage.")
        }
        return decoded
    }
}
