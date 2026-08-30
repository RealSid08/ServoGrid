import Foundation

struct FuelCheckAdapter: FuelSourceAdapter {
    static let clientIDKey = "fuelcheck.clientID"
    static let clientSecretKey = "fuelcheck.clientSecret"

    let source: SourceDescriptor
    let capabilities = SourceCapabilities(
        supportedGrades: Set(FuelGrade.allCases),
        supportsToday: true,
        supportsTomorrow: false,
        supportsHistory: false,
        requiresCredentials: true
    )

    private let jurisdiction: Jurisdiction
    private let network: any NetworkClient
    private let credentials: any CredentialProviding
    private let now: @Sendable () -> Date

    init(
        jurisdiction: Jurisdiction,
        network: any NetworkClient = URLSessionNetworkClient(),
        credentials: any CredentialProviding = KeychainCredentialStore(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        precondition(jurisdiction == .newSouthWales || jurisdiction == .tasmania)
        self.jurisdiction = jurisdiction
        self.source = SourceCatalog.fuelCheck(jurisdiction)
        self.network = network
        self.credentials = credentials
        self.now = now
    }

    func fetch(grade: FuelGrade, day: PriceValidity) async throws -> FuelSnapshot {
        guard day == .today else { throw SourceFailure.unsupportedDay(day) }
        guard let clientID = await credentials.value(for: Self.clientIDKey), !clientID.isEmpty,
              let secret = await credentials.value(for: Self.clientSecretKey), !secret.isEmpty else {
            throw SourceFailure.credentialsRequired(jurisdiction)
        }

        let token = try await accessToken(clientID: clientID, secret: secret)
        var request = URLRequest(url: URL(string: "https://api.onegov.nsw.gov.au/FuelPriceCheck/v2/fuel/prices")!)
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientID, forHTTPHeaderField: "apikey")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "transactionid")
        request.setValue(ISO8601DateFormatter().string(from: now()), forHTTPHeaderField: "requesttimestamp")
        let response = try await network.send(request)
        guard (200 ... 299).contains(response.statusCode) else { throw SourceFailure.httpStatus(response.statusCode) }
        return try decodePrices(response.data, grade: grade)
    }

    private func accessToken(clientID: String, secret: String) async throws -> String {
        var components = URLComponents(string: "https://api.onegov.nsw.gov.au/oauth/client_credential/accesstoken")!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "client_credentials")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Basic \(Data("\(clientID):\(secret)".utf8).base64EncodedString())", forHTTPHeaderField: "Authorization")
        let response = try await network.send(request)
        guard (200 ... 299).contains(response.statusCode) else { throw SourceFailure.httpStatus(response.statusCode) }
        let token = try JSONDecoder().decode(FuelCheckToken.self, from: response.data)
        return token.accessToken
    }

    private func decodePrices(_ data: Data, grade: FuelGrade) throws -> FuelSnapshot {
        let payload: FuelCheckPayload
        do {
            payload = try JSONDecoder().decode(FuelCheckPayload.self, from: data)
        } catch {
            throw SourceFailure.invalidResponse("FuelCheck response did not match the documented v2 station/price shape.")
        }
        let checkedAt = now()
        let pricesByStation = Dictionary(grouping: payload.prices.filter { FuelGrade(sourceName: $0.fuelType) == grade }, by: \.stationCode)
        let stations = try payload.stations.compactMap { item -> FuelStation? in
            guard let price = pricesByStation[item.code]?.first else { return nil }
            let observation = try FuelPriceObservation(
                id: "fuelcheck-\(item.code)-\(grade.rawValue)-\(price.lastUpdated)",
                stationID: "fuelcheck-\(item.code)",
                fuelGrade: grade,
                priceCentsPerLitre: price.price,
                availability: .available,
                validity: .today,
                sourceEventAt: Self.fuelCheckDate(price.lastUpdated),
                sourceDatasetAt: nil,
                observedAt: checkedAt,
                checkedAt: checkedAt,
                restrictions: nil
            )
            return try FuelStation(
                id: "fuelcheck-\(item.code)",
                sourceStationID: item.code,
                name: item.name,
                brand: item.brand,
                address: item.address,
                suburb: item.location,
                state: jurisdiction.rawValue,
                postcode: item.postcode,
                latitude: item.latitude,
                longitude: item.longitude,
                observations: [observation]
            )
        }
        return FuelSnapshot(schemaVersion: 1, source: source, stations: stations, checkedAt: checkedAt)
    }

    private static func fuelCheckDate(_ value: String) -> Date? {
        if let iso = ISO8601DateFormatter().date(from: value) { return iso }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU_POSIX")
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter.date(from: value)
    }
}

private struct FuelCheckToken: Decodable {
    let accessToken: String
    enum CodingKeys: String, CodingKey { case accessToken = "access_token" }
}

private struct FuelCheckPayload: Decodable {
    let stations: [Station]
    let prices: [Price]

    struct Station: Decodable {
        let code: String
        let name: String
        let brand: String?
        let address: String
        let location: String
        let postcode: String?
        let latitude: Double
        let longitude: Double

        enum CodingKeys: String, CodingKey {
            case code
            case name
            case brand
            case address
            case location
            case postcode
            case latitude
            case longitude
        }
    }

    struct Price: Decodable {
        let stationCode: String
        let fuelType: String
        let price: Double
        let lastUpdated: String

        enum CodingKeys: String, CodingKey {
            case stationCode = "stationcode"
            case fuelType = "fueltype"
            case price
            case lastUpdated = "lastupdated"
        }
    }
}

