import Foundation

enum PriceMovement: Equatable, Sendable {
    case down(delta: Double)
    case steady
    case up(delta: Double)
    case unavailable

    var symbol: String {
        switch self {
        case .down: "↓"
        case .steady: "="
        case .up: "↑"
        case .unavailable: "–"
        }
    }
}

enum PriceMovementCalculator {
    static func compare(
        current: FuelPriceObservation,
        previous: FuelPriceObservation,
        steadyTolerance: Double = 0.05
    ) -> PriceMovement {
        guard current.stationID == previous.stationID,
              current.fuelGrade == previous.fuelGrade,
              current.validity == previous.validity else {
            return .unavailable
        }

        let delta = ((current.priceCentsPerLitre - previous.priceCentsPerLitre) * 10).rounded() / 10
        if abs(delta) <= steadyTolerance { return .steady }
        return delta < 0 ? .down(delta: delta) : .up(delta: delta)
    }
}

