import Foundation

struct AlertPreference: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let areaName: String
    let stationID: String?
    let fuelGrade: FuelGrade
    let dropThreshold: Double
    let spikeThreshold: Double
    let tomorrowPublished: Bool
    let sourceOutage: Bool
}

enum AlertKind: String, Codable, Sendable {
    case priceDrop
    case priceSpike
    case tomorrowPublished
    case sourceOutage
}

struct AlertEvent: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let preferenceID: String
    let kind: AlertKind
    let title: String
    let message: String
    let stationID: String?
}

enum AlertEngine {
    static func evaluate(
        previous: FuelSnapshot?,
        current: FuelSnapshot,
        preferences: [AlertPreference],
        deliveredEventIDs: Set<String>
    ) -> [AlertEvent] {
        var events: [AlertEvent] = []

        for preference in preferences {
            if current.stations.isEmpty, preference.sourceOutage {
                appendIfNew(
                    AlertEvent(
                        id: "\(preference.id):\(current.source.id):outage:\(Int(current.checkedAt.timeIntervalSince1970))",
                        preferenceID: preference.id,
                        kind: .sourceOutage,
                        title: "Grid source unavailable",
                        message: "\(current.source.name) returned no station data.",
                        stationID: nil
                    ),
                    delivered: deliveredEventIDs,
                    to: &events
                )
            }

            let previousByStation = observations(in: previous, matching: preference)
            for (station, currentObservation) in observations(in: current, matching: preference).values {
                if currentObservation.validity == .tomorrow,
                   preference.tomorrowPublished,
                   previousByStation[station.id]?.1.validity != .tomorrow {
                    appendIfNew(
                        event(
                            preference: preference,
                            kind: .tomorrowPublished,
                            station: station,
                            observation: currentObservation,
                            message: "Tomorrow's \(preference.fuelGrade.shortName) price is now published at \(station.name)."
                        ),
                        delivered: deliveredEventIDs,
                        to: &events
                    )
                }

                guard let previousObservation = previousByStation[station.id]?.1,
                      currentObservation.validity == previousObservation.validity else { continue }
                let delta = ((currentObservation.priceCentsPerLitre - previousObservation.priceCentsPerLitre) * 10).rounded() / 10
                if delta <= -preference.dropThreshold {
                    appendIfNew(
                        event(
                            preference: preference,
                            kind: .priceDrop,
                            station: station,
                            observation: currentObservation,
                            message: "\(preference.fuelGrade.shortName) dropped \(String(format: "%.1f", abs(delta)))c/L at \(station.name)."
                        ),
                        delivered: deliveredEventIDs,
                        to: &events
                    )
                } else if delta >= preference.spikeThreshold {
                    appendIfNew(
                        event(
                            preference: preference,
                            kind: .priceSpike,
                            station: station,
                            observation: currentObservation,
                            message: "\(preference.fuelGrade.shortName) rose \(String(format: "%.1f", delta))c/L at \(station.name)."
                        ),
                        delivered: deliveredEventIDs,
                        to: &events
                    )
                }
            }
        }

        return events
    }

    private static func observations(
        in snapshot: FuelSnapshot?,
        matching preference: AlertPreference
    ) -> [String: (FuelStation, FuelPriceObservation)] {
        guard let snapshot else { return [:] }
        var result: [String: (FuelStation, FuelPriceObservation)] = [:]
        for station in snapshot.stations where preference.stationID == nil || preference.stationID == station.id {
            for observation in station.observations where observation.fuelGrade == preference.fuelGrade {
                result[station.id] = (station, observation)
            }
        }
        return result
    }

    private static func event(
        preference: AlertPreference,
        kind: AlertKind,
        station: FuelStation,
        observation: FuelPriceObservation,
        message: String
    ) -> AlertEvent {
        AlertEvent(
            id: "\(preference.id):\(kind.rawValue):\(observation.id)",
            preferenceID: preference.id,
            kind: kind,
            title: kind == .priceDrop ? "Price drop" : kind == .priceSpike ? "Price spike" : "Tomorrow price published",
            message: message,
            stationID: station.id
        )
    }

    private static func appendIfNew(
        _ event: AlertEvent,
        delivered: Set<String>,
        to events: inout [AlertEvent]
    ) {
        guard !delivered.contains(event.id) else { return }
        events.append(event)
    }
}
