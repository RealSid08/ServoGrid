import Foundation

struct GridBrief: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let text: String
    let region: String
    let fuelGrade: FuelGrade
    let meanChange: Double
    let sampleSize: Int
    let generatedAt: Date
    let evidenceObservationIDs: [String]
    let sourceAttributions: [String]
}

enum GridBriefEngine {
    static func generate(
        region: String,
        fuelGrade: FuelGrade,
        current: FuelSnapshot,
        previous: FuelSnapshot,
        now: Date,
        minimumSampleSize: Int = 3,
        minimumMeanChange: Double = 1
    ) -> GridBrief? {
        guard current.source.id == previous.source.id else { return nil }

        let previousByStation = Dictionary(uniqueKeysWithValues: previous.stations.compactMap { station in
            station.observations.first(where: { $0.fuelGrade == fuelGrade && $0.validity == .today }).map {
                (station.id, $0)
            }
        })

        var pairs: [(FuelPriceObservation, FuelPriceObservation)] = []
        for station in current.stations {
            guard let currentObservation = station.observations.first(where: {
                $0.fuelGrade == fuelGrade && $0.validity == .today
            }), let previousObservation = previousByStation[station.id] else { continue }
            pairs.append((currentObservation, previousObservation))
        }

        guard pairs.count >= minimumSampleSize else { return nil }
        let mean = pairs.map { $0.0.priceCentsPerLitre - $0.1.priceCentsPerLitre }.reduce(0, +) / Double(pairs.count)
        guard abs(mean) >= minimumMeanChange else { return nil }

        let roundedMean = (mean * 10).rounded() / 10
        let direction = roundedMean > 0 ? "rose" : "fell"
        let magnitude = String(format: "%.1f", abs(roundedMean))
        let evidence = pairs.flatMap { [$0.0.id, $0.1.id] }.sorted()

        return GridBrief(
            id: "\(current.source.id):\(region):\(fuelGrade.rawValue):\(Int(now.timeIntervalSince1970))",
            text: "\(fuelGrade.shortName) \(direction) by \(magnitude)c/L across \(region), based on \(pairs.count) comparable stations.",
            region: region,
            fuelGrade: fuelGrade,
            meanChange: roundedMean,
            sampleSize: pairs.count,
            generatedAt: now,
            evidenceObservationIDs: evidence,
            sourceAttributions: [current.source.attribution]
        )
    }
}

