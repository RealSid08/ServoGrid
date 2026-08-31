import Foundation

enum RelativePriceBand: String, Codable, Sendable {
    case low
    case typical
    case high
    case insufficientData
}

enum RelativePriceClassifier {
    static func classify(price: Double, localPrices: [Double]) -> RelativePriceBand {
        let sorted = localPrices.filter { $0.isFinite && $0 > 0 }.sorted()
        guard sorted.count >= 3 else { return .insufficientData }

        let lowCutoff = quantile(0.33, in: sorted)
        let highCutoff = quantile(0.75, in: sorted)
        if price < lowCutoff { return .low }
        if price > highCutoff { return .high }
        return .typical
    }

    private static func quantile(_ probability: Double, in sorted: [Double]) -> Double {
        let position = probability * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        guard lower != upper else { return sorted[lower] }
        let fraction = position - Double(lower)
        return sorted[lower] + ((sorted[upper] - sorted[lower]) * fraction)
    }
}

