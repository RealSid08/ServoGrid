import Foundation

enum PresentationFormat {
    static let australiaRegion = (
        centerLatitude: -25.6,
        centerLongitude: 134.4,
        latitudeDelta: 44.0,
        longitudeDelta: 48.0
    )

    static func price(_ centsPerLitre: Double) -> String {
        String(format: "%.1f", centsPerLitre)
    }

    static func priceWithUnit(_ centsPerLitre: Double) -> String {
        "\(price(centsPerLitre)) c/L"
    }

    static func signedCents(_ value: Double) -> String {
        let formatted = String(format: "%.1f", abs(value))
        if value > 0 { return "+\(formatted) c/L" }
        if value < 0 { return "−\(formatted) c/L" }
        return "0.0 c/L"
    }

    static func timestamp(_ date: Date?) -> String {
        guard let date else { return "Not supplied" }
        return timestampFormatter.string(from: date)
    }

    static func compactTimestamp(_ date: Date?) -> String {
        guard let date else { return "—" }
        return compactFormatter.string(from: date)
    }

    static func count(_ value: Int, singular: String, plural: String) -> String {
        value == 1 ? "1 \(singular)" : "\(value) \(plural)"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()

    private static let compactFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_AU")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()
}

extension FuelGrade {
    var displayName: String {
        switch self {
        case .unleaded91: "Unleaded 91"
        case .e10: "E10"
        case .unleaded95: "Unleaded 95"
        case .unleaded98: "Unleaded 98"
        case .diesel: "Diesel"
        case .premiumDiesel: "Premium Diesel"
        case .lpg: "LPG"
        case .e85: "E85"
        case .lowAromatic: "Low Aromatic"
        }
    }
}

extension PriceValidity {
    var displayName: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        }
    }
}

extension PriceMovement {
    var accessibilityPhrase: String {
        switch self {
        case .down(let delta):
            "down \(String(format: "%.1f", abs(delta))) cents per litre"
        case .steady:
            "steady"
        case .up(let delta):
            "up \(String(format: "%.1f", delta)) cents per litre"
        case .unavailable:
            "movement unavailable"
        }
    }

    var detailPhrase: String {
        switch self {
        case .down(let delta): "Down \(String(format: "%.1f", abs(delta))) c/L"
        case .steady: "Steady"
        case .up(let delta): "Up \(String(format: "%.1f", delta)) c/L"
        case .unavailable: "No comparable movement"
        }
    }
}

extension RelativePriceBand {
    var displayName: String {
        switch self {
        case .low: "Low"
        case .typical: "Typical"
        case .high: "High"
        case .insufficientData: "Insufficient data"
        }
    }

    var accessibilityPhrase: String {
        switch self {
        case .low: "low relative price"
        case .typical: "typical relative price"
        case .high: "high relative price"
        case .insufficientData: "insufficient local data"
        }
    }
}

extension FreshnessState {
    var displayName: String {
        switch self {
        case .fresh: "Fresh"
        case .ageing: "Ageing"
        case .stale: "Stale"
        case .unknown: "Unknown"
        }
    }
}

extension SourceHealthState {
    var displayName: String {
        switch self {
        case .operational: "Operational"
        case .degraded: "Degraded"
        case .unavailable: "Unavailable"
        case .demo: "Demo"
        }
    }
}

extension MonitorSeverity {
    var displayName: String {
        rawValue.capitalized
    }

    var cue: String {
        switch self {
        case .info: "i"
        case .warning: "!"
        case .critical: "×"
        }
    }

    var iconName: String {
        switch self {
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle"
        case .critical: "xmark.octagon"
        }
    }
}

extension MonitorIssueCode {
    var displayName: String {
        switch self {
        case .schemaDrift: "Schema"
        case .emptyFeed: "Empty feed"
        case .missingTimestamp: "Timestamp"
        case .futureTimestamp: "Future time"
        case .staleObservation: "Stale"
        case .impossiblePrice: "Price"
        case .impossibleCoordinate: "Coordinate"
        case .duplicateStation: "Duplicate"
        }
    }
}

extension AppLoadState {
    var errorMessage: String? {
        switch self {
        case .offlineCached(let message), .failed(let message): message
        default: nil
        }
    }
}

extension FuelStation {
    var selectedObservation: FuelPriceObservation? { observations.first }

    var coordinateAccessibility: String {
        let lat = String(format: "%.4f", latitude)
        let lon = String(format: "%.4f", longitude)
        return "\(suburb), \(state), \(lat), \(lon)"
    }
}
