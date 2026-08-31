import Foundation

struct RestrictedJurisdictionAdapter: FuelSourceAdapter {
    let source: SourceDescriptor
    let capabilities: SourceCapabilities
    let reason: String

    func fetch(grade: FuelGrade, day: PriceValidity) async throws -> FuelSnapshot {
        throw SourceFailure.unavailable(source.jurisdiction, reason)
    }
}

enum RestrictedAdapters {
    static let queensland = RestrictedJurisdictionAdapter(
        source: SourceCatalog.queensland,
        capabilities: SourceCapabilities(
            supportedGrades: Set(FuelGrade.allCases), supportsToday: true, supportsTomorrow: false,
            supportsHistory: true, requiresCredentials: true
        ),
        reason: "Current data requires Fuel Prices Queensland data-consumer registration and a token."
    )

    static let southAustralia = RestrictedJurisdictionAdapter(
        source: SourceCatalog.southAustralia,
        capabilities: SourceCapabilities(
            supportedGrades: Set(FuelGrade.allCases), supportsToday: true, supportsTomorrow: false,
            supportsHistory: false, requiresCredentials: true
        ),
        reason: "Current data is available only to registered data publishers under publisher terms."
    )

    static let victoria = RestrictedJurisdictionAdapter(
        source: SourceCatalog.victoria,
        capabilities: SourceCapabilities(
            supportedGrades: Set(FuelGrade.allCases), supportsToday: true, supportsTomorrow: false,
            supportsHistory: false, requiresCredentials: true
        ),
        reason: "The Servo Saver API requires approval and its public dataset is delayed by 24 hours."
    )

    static let northernTerritory = RestrictedJurisdictionAdapter(
        source: SourceCatalog.northernTerritory,
        capabilities: SourceCapabilities(
            supportedGrades: Set(FuelGrade.allCases), supportsToday: true, supportsTomorrow: true,
            supportsHistory: true, requiresCredentials: false
        ),
        reason: "The consumer site is public, but a documented third-party API and current reuse terms were not verified."
    )

    static let act = RestrictedJurisdictionAdapter(
        source: SourceCatalog.act,
        capabilities: SourceCapabilities(
            supportedGrades: Set(FuelGrade.allCases), supportsToday: true, supportsTomorrow: false,
            supportsHistory: false, requiresCredentials: true
        ),
        reason: "Public FuelCheck API documentation verifies NSW and Tasmania coverage, not ACT coverage."
    )
}

