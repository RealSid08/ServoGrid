import Foundation

enum SourceCatalog {
    static let fuelWatch = SourceDescriptor(
        id: "wa-fuelwatch",
        name: "WA FuelWatch",
        jurisdiction: .westernAustralia,
        coverage: .live,
        sourceURL: URL(string: "https://www.fuelwatch.wa.gov.au/tools/rss")!,
        attribution: "FuelWatch, Government of Western Australia",
        licenceName: "FuelWatch RSS reuse terms",
        licenceURL: URL(string: "https://www.fuelwatch.wa.gov.au/tools/rss")
    )

    static func fuelCheck(_ jurisdiction: Jurisdiction) -> SourceDescriptor {
        SourceDescriptor(
            id: jurisdiction == .tasmania ? "tas-fuelcheck" : "nsw-fuelcheck",
            name: jurisdiction == .tasmania ? "FuelCheck Tasmania" : "FuelCheck NSW",
            jurisdiction: jurisdiction,
            coverage: .live,
            sourceURL: URL(string: "https://api.nsw.gov.au/Product/Index/22")!,
            attribution: "FuelCheck, NSW Government\(jurisdiction == .tasmania ? " and Tasmanian Government" : "")",
            licenceName: "API.NSW subscriber agreement"
        )
    }

    static let queensland = restricted(
        id: "qld-fuel-prices",
        name: "Fuel Prices Queensland",
        jurisdiction: .queensland,
        url: "https://www.fuelpricesqld.com.au/",
        coverage: .unavailable,
        attribution: "Queensland Government"
    )

    static let southAustralia = restricted(
        id: "sa-fuel-pricing",
        name: "SA Fuel Pricing Information Scheme",
        jurisdiction: .southAustralia,
        url: "https://www.safuelpricinginformation.com.au/",
        coverage: .unavailable,
        attribution: "Government of South Australia"
    )

    static let victoria = restricted(
        id: "vic-servo-saver",
        name: "Servo Saver Public API",
        jurisdiction: .victoria,
        url: "https://discover.data.vic.gov.au/dataset/servo-saver-public-api",
        coverage: .delayed,
        attribution: "Service Victoria"
    )

    static let northernTerritory = restricted(
        id: "nt-myfuel",
        name: "MyFuel NT",
        jurisdiction: .northernTerritory,
        url: "https://myfuelnt.nt.gov.au/",
        coverage: .unavailable,
        attribution: "Northern Territory Consumer Affairs"
    )

    static let act = restricted(
        id: "act-fuelcheck",
        name: "ACT FuelCheck coverage",
        jurisdiction: .australianCapitalTerritory,
        url: "https://api.nsw.gov.au/Product/Index/22",
        coverage: .unavailable,
        attribution: "ACT Government / API.NSW"
    )

    static let demo = SourceDescriptor(
        id: "fixture-national",
        name: "ServoGrid evaluation fixtures",
        jurisdiction: .national,
        coverage: .demo,
        sourceURL: URL(string: "https://example.invalid/servogrid-fixture")!,
        attribution: "Synthetic ServoGrid demo data — not a live fuel source",
        licenceName: "Project fixture"
    )

    private static func restricted(
        id: String,
        name: String,
        jurisdiction: Jurisdiction,
        url: String,
        coverage: CoverageMode,
        attribution: String
    ) -> SourceDescriptor {
        SourceDescriptor(
            id: id,
            name: name,
            jurisdiction: jurisdiction,
            coverage: coverage,
            sourceURL: URL(string: url)!,
            attribution: attribution,
            licenceName: "Registration or permission required"
        )
    }
}

