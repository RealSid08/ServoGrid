import CoreLocation
import Foundation

enum MonitorIssueCode: String, Codable, Sendable {
    case schemaDrift
    case emptyFeed
    case missingTimestamp
    case futureTimestamp
    case staleObservation
    case impossiblePrice
    case impossibleCoordinate
    case duplicateStation
}

enum MonitorSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

struct MonitorIssue: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let code: MonitorIssueCode
    let severity: MonitorSeverity
    let summary: String
    let stationID: String?
}

enum GridMonitor {
    static let supportedSchemaVersion = 1

    static func evaluate(
        snapshot: FuelSnapshot,
        now: Date,
        policy: FreshnessPolicy
    ) -> [MonitorIssue] {
        var issues: [MonitorIssue] = []

        if snapshot.schemaVersion != supportedSchemaVersion {
            issues.append(issue(.schemaDrift, .critical, "Unsupported snapshot schema \(snapshot.schemaVersion)."))
        }
        if snapshot.stations.isEmpty {
            issues.append(issue(.emptyFeed, .critical, "The source returned no stations."))
        }

        for station in snapshot.stations {
            if !(-90 ... 90).contains(station.latitude) || !(-180 ... 180).contains(station.longitude) {
                issues.append(issue(.impossibleCoordinate, .critical, "Station coordinates are outside Earth bounds.", station.id))
            }

            for observation in station.observations {
                if observation.sourceEventAt == nil, observation.sourceDatasetAt == nil {
                    issues.append(issue(.missingTimestamp, .warning, "Price has no source-owned timestamp.", station.id))
                }
                if let sourceTime = observation.sourceEventAt ?? observation.sourceDatasetAt,
                   sourceTime.timeIntervalSince(now) > 300 {
                    issues.append(issue(.futureTimestamp, .critical, "Source timestamp is more than five minutes in the future.", station.id))
                }
                if !(50 ... 500).contains(observation.priceCentsPerLitre) {
                    issues.append(issue(.impossiblePrice, .critical, "Price is outside ServoGrid's plausible fuel range.", station.id))
                }
                if FreshnessEvaluator.evaluate(observation, at: now, policy: policy) == .stale {
                    issues.append(issue(.staleObservation, .warning, "Price is older than the source freshness policy.", station.id))
                }
            }
        }

        for firstIndex in snapshot.stations.indices {
            for secondIndex in snapshot.stations.indices where secondIndex > firstIndex {
                let first = snapshot.stations[firstIndex]
                let second = snapshot.stations[secondIndex]
                let firstLocation = CLLocation(latitude: first.latitude, longitude: first.longitude)
                let secondLocation = CLLocation(latitude: second.latitude, longitude: second.longitude)
                if firstLocation.distance(from: secondLocation) <= 25,
                   first.suburb.caseInsensitiveCompare(second.suburb) == .orderedSame {
                    issues.append(issue(
                        .duplicateStation,
                        .warning,
                        "Two source records occupy nearly the same location.",
                        "\(first.id)|\(second.id)"
                    ))
                }
            }
        }

        return issues
    }

    private static func issue(
        _ code: MonitorIssueCode,
        _ severity: MonitorSeverity,
        _ summary: String,
        _ stationID: String? = nil
    ) -> MonitorIssue {
        MonitorIssue(
            id: "\(code.rawValue):\(stationID ?? "source")",
            code: code,
            severity: severity,
            summary: summary,
            stationID: stationID
        )
    }
}

