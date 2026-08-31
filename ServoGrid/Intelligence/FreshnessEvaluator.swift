import Foundation

struct FreshnessPolicy: Equatable, Sendable {
    let freshFor: TimeInterval
    let staleAfter: TimeInterval
}

enum FreshnessState: String, Codable, Sendable {
    case fresh
    case ageing
    case stale
    case unknown
}

enum FreshnessEvaluator {
    static func evaluate(
        _ observation: FuelPriceObservation,
        at now: Date,
        policy: FreshnessPolicy
    ) -> FreshnessState {
        guard let sourceTime = observation.sourceEventAt ?? observation.sourceDatasetAt else {
            return .unknown
        }

        let age = now.timeIntervalSince(sourceTime)
        guard age >= -300 else { return .unknown }
        if age <= policy.freshFor { return .fresh }
        if age <= policy.staleAfter { return .ageing }
        return .stale
    }
}

