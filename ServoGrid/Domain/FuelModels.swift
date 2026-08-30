import Foundation

enum PriceAvailability: String, Codable, Sendable {
    case available
    case unavailable
    case unknown
}

enum PriceValidity: String, CaseIterable, Codable, Sendable, Identifiable {
    case today
    case tomorrow

    var id: String { rawValue }
}

enum FuelModelError: Error, Equatable {
    case invalidPrice
    case invalidCoordinate
}

struct ObservationTimes: Codable, Hashable, Sendable {
    let sourceEventAt: Date?
    let sourceDatasetAt: Date?
    let observedAt: Date
    let checkedAt: Date
}

struct FuelPriceObservation: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let stationID: String
    let fuelGrade: FuelGrade
    let priceCentsPerLitre: Double
    let availability: PriceAvailability
    let validity: PriceValidity
    let sourceEventAt: Date?
    let sourceDatasetAt: Date?
    let observedAt: Date
    let checkedAt: Date
    let restrictions: String?

    var times: ObservationTimes {
        ObservationTimes(
            sourceEventAt: sourceEventAt,
            sourceDatasetAt: sourceDatasetAt,
            observedAt: observedAt,
            checkedAt: checkedAt
        )
    }

    init(
        id: String,
        stationID: String,
        fuelGrade: FuelGrade,
        priceCentsPerLitre: Double,
        availability: PriceAvailability,
        validity: PriceValidity,
        sourceEventAt: Date?,
        sourceDatasetAt: Date?,
        observedAt: Date,
        checkedAt: Date,
        restrictions: String?
    ) throws {
        guard priceCentsPerLitre.isFinite, priceCentsPerLitre > 0 else {
            throw FuelModelError.invalidPrice
        }

        self.id = id
        self.stationID = stationID
        self.fuelGrade = fuelGrade
        self.priceCentsPerLitre = priceCentsPerLitre
        self.availability = availability
        self.validity = validity
        self.sourceEventAt = sourceEventAt
        self.sourceDatasetAt = sourceDatasetAt
        self.observedAt = observedAt
        self.checkedAt = checkedAt
        self.restrictions = restrictions
    }
}

struct FuelStation: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let sourceStationID: String
    let name: String
    let brand: String?
    let address: String
    let suburb: String
    let state: String
    let postcode: String?
    let latitude: Double
    let longitude: Double
    let observations: [FuelPriceObservation]

    init(
        id: String,
        sourceStationID: String,
        name: String,
        brand: String?,
        address: String,
        suburb: String,
        state: String,
        postcode: String?,
        latitude: Double,
        longitude: Double,
        observations: [FuelPriceObservation]
    ) throws {
        guard (-90 ... 90).contains(latitude), (-180 ... 180).contains(longitude) else {
            throw FuelModelError.invalidCoordinate
        }

        self.id = id
        self.sourceStationID = sourceStationID
        self.name = name
        self.brand = brand
        self.address = address
        self.suburb = suburb
        self.state = state
        self.postcode = postcode
        self.latitude = latitude
        self.longitude = longitude
        self.observations = observations
    }
}

struct FuelSnapshot: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let source: SourceDescriptor
    let stations: [FuelStation]
    let checkedAt: Date

    var isDemo: Bool { source.coverage == .demo }
    var trustLabel: String { source.coverage.trustLabel }
}
