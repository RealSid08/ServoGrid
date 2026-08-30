import Foundation

struct FuelWatchAdapter: FuelSourceAdapter {
    let source = SourceCatalog.fuelWatch
    let capabilities = SourceCapabilities(
        supportedGrades: [.unleaded91, .unleaded95, .unleaded98, .diesel, .premiumDiesel, .lpg, .e85],
        supportsToday: true,
        supportsTomorrow: true,
        supportsHistory: true,
        requiresCredentials: false
    )

    private let network: any NetworkClient
    private let regionIDs: [String]
    private let now: @Sendable () -> Date

    init(
        network: any NetworkClient = URLSessionNetworkClient(),
        regionIDs: [String] = ["98", "1", "2", "3", "4", "5", "6", "7", "8", "9"],
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.network = network
        self.regionIDs = regionIDs
        self.now = now
    }

    func fetch(grade: FuelGrade, day: PriceValidity) async throws -> FuelSnapshot {
        guard let productCode = productCode(for: grade) else {
            throw SourceFailure.unsupportedFuel(grade)
        }

        let checkedAt = now()
        var stationsByID: [String: FuelStation] = [:]
        var latestDatasetAt: Date?

        for regionID in regionIDs {
            let request = try request(productCode: productCode, regionID: regionID, day: day)
            let response = try await network.send(request)
            guard (200 ... 299).contains(response.statusCode) else {
                throw SourceFailure.httpStatus(response.statusCode)
            }

            let feed = try FuelWatchFeedParser.parse(
                response.data,
                grade: grade,
                validity: day,
                observedAt: checkedAt,
                checkedAt: checkedAt
            )
            latestDatasetAt = [latestDatasetAt, feed.datasetAt].compactMap { $0 }.max()
            for station in feed.stations {
                stationsByID[station.id] = station
            }
        }

        let coverage: CoverageMode = day == .tomorrow ? .scheduled : .live
        let descriptor = SourceDescriptor(
            id: source.id,
            name: source.name,
            jurisdiction: source.jurisdiction,
            coverage: coverage,
            sourceURL: source.sourceURL,
            attribution: source.attribution,
            licenceName: source.licenceName,
            licenceURL: source.licenceURL
        )

        return FuelSnapshot(
            schemaVersion: 1,
            source: descriptor,
            stations: stationsByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
            checkedAt: checkedAt
        )
    }

    private func request(productCode: String, regionID: String, day: PriceValidity) throws -> URLRequest {
        var components = URLComponents(string: "https://www.fuelwatch.wa.gov.au/fuelwatch/fuelWatchRSS")!
        components.queryItems = [
            URLQueryItem(name: "Product", value: productCode),
            URLQueryItem(name: "StateRegion", value: regionID),
            URLQueryItem(name: "Day", value: day.rawValue)
        ]
        guard let url = components.url else {
            throw SourceFailure.invalidResponse("Could not construct the FuelWatch RSS URL.")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("ServoGrid/1.0 (+https://www.fuelwatch.wa.gov.au/tools/rss)", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func productCode(for grade: FuelGrade) -> String? {
        switch grade {
        case .unleaded91: "1"
        case .unleaded95: "2"
        case .diesel: "4"
        case .lpg: "5"
        case .unleaded98: "6"
        case .e85: "10"
        case .premiumDiesel: "11"
        case .e10, .lowAromatic: nil
        }
    }
}

private struct FuelWatchFeed {
    let datasetAt: Date?
    let stations: [FuelStation]
}

private final class FuelWatchFeedParser: NSObject, XMLParserDelegate {
    private let grade: FuelGrade
    private let validity: PriceValidity
    private let observedAt: Date
    private let checkedAt: Date
    private var currentElement = ""
    private var currentText = ""
    private var currentItem: [String: String]?
    private var parsedItems: [[String: String]] = []
    private var lastBuildDateText: String?

    private init(grade: FuelGrade, validity: PriceValidity, observedAt: Date, checkedAt: Date) {
        self.grade = grade
        self.validity = validity
        self.observedAt = observedAt
        self.checkedAt = checkedAt
    }

    static func parse(
        _ data: Data,
        grade: FuelGrade,
        validity: PriceValidity,
        observedAt: Date,
        checkedAt: Date
    ) throws -> FuelWatchFeed {
        let delegate = FuelWatchFeedParser(
            grade: grade,
            validity: validity,
            observedAt: observedAt,
            checkedAt: checkedAt
        )
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw SourceFailure.invalidResponse(parser.parserError?.localizedDescription ?? "FuelWatch XML could not be parsed.")
        }
        return try delegate.makeFeed()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        if elementName == "item" { currentItem = [:] }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "item" {
            if let currentItem { parsedItems.append(currentItem) }
            currentItem = nil
        } else if currentItem != nil {
            currentItem?[elementName] = value
        } else if elementName == "lastBuildDate" {
            lastBuildDateText = value
        }
        currentElement = ""
        currentText = ""
    }

    private func makeFeed() throws -> FuelWatchFeed {
        let datasetAt = lastBuildDateText.flatMap(Self.rfc822Formatter.date)
        let stations = try parsedItems.map { item -> FuelStation in
            guard let priceText = item["price"], let price = Double(priceText),
                  let name = item["trading-name"],
                  let address = item["address"],
                  let suburb = item["location"],
                  let latitudeText = item["latitude"], let latitude = Double(latitudeText),
                  let longitudeText = item["longitude"], let longitude = Double(longitudeText) else {
                throw SourceFailure.invalidResponse("A FuelWatch item was missing a required price or station field.")
            }

            let stationID = "wa-fuelwatch-\(Self.slug("\(name)-\(address)-\(latitudeText)-\(longitudeText)"))"
            let sourceEventAt = item["date"].flatMap(Self.priceDateFormatter.date)
            let restriction = item["restrictions"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let observation = try FuelPriceObservation(
                id: "\(stationID)-\(grade.rawValue)-\(validity.rawValue)-\(item["date"] ?? "unknown")",
                stationID: stationID,
                fuelGrade: grade,
                priceCentsPerLitre: price,
                availability: .available,
                validity: validity,
                sourceEventAt: sourceEventAt,
                sourceDatasetAt: datasetAt,
                observedAt: observedAt,
                checkedAt: checkedAt,
                restrictions: restriction?.isEmpty == true ? nil : restriction
            )
            return try FuelStation(
                id: stationID,
                sourceStationID: stationID,
                name: name,
                brand: item["brand"],
                address: address,
                suburb: suburb.capitalized,
                state: "WA",
                postcode: nil,
                latitude: latitude,
                longitude: longitude,
                observations: [observation]
            )
        }
        return FuelWatchFeed(datasetAt: datasetAt, stations: stations)
    }

    private static let rfc822Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()

    private static let priceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Australia/Perth")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func slug(_ value: String) -> String {
        value.lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-" }
            .reduce(into: "") { result, character in
                if character != "-" || result.last != "-" { result.append(character) }
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

