import XCTest
@testable import ServoGrid

final class EvaluationSuiteTests: XCTestCase {
    func testTenStandardPriceClassificationCases() {
        let cohort = [150.0, 160, 170, 180, 190, 200]
        let cases: [(Double, RelativePriceBand)] = [
            (150, .low),
            (155, .low),
            (160, .low),
            (165, .low),
            (170, .typical),
            (180, .typical),
            (185, .typical),
            (190, .high),
            (195, .high),
            (200, .high)
        ]

        for (price, expected) in cases {
            XCTAssertEqual(RelativePriceClassifier.classify(price: price, localPrices: cohort), expected)
        }
    }

    func testDifficultMixedEvidenceCaseFailsClosed() throws {
        let checkedAt = ISO8601DateFormatter().date(from: "2026-08-30T12:00:00Z")!
        let observation = try FuelPriceObservation(
            id: "difficult-u91",
            stationID: "difficult",
            fuelGrade: .unleaded91,
            priceCentsPerLitre: 99.9,
            availability: .available,
            validity: .today,
            sourceEventAt: nil,
            sourceDatasetAt: nil,
            observedAt: checkedAt,
            checkedAt: checkedAt,
            restrictions: nil
        )

        XCTAssertEqual(
            FreshnessEvaluator.evaluate(
                observation,
                at: checkedAt,
                policy: FreshnessPolicy(freshFor: 3600, staleAfter: 7200)
            ),
            .unknown,
            "A just-checked record with no source-owned timestamp must not become fresh"
        )
        XCTAssertEqual(RelativePriceClassifier.classify(price: 99.9, localPrices: [99.9, 180]), .insufficientData)
    }
}
