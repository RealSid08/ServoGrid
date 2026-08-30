import Foundation

enum Jurisdiction: String, CaseIterable, Codable, Sendable {
    case australianCapitalTerritory = "ACT"
    case newSouthWales = "NSW"
    case northernTerritory = "NT"
    case queensland = "QLD"
    case southAustralia = "SA"
    case tasmania = "TAS"
    case victoria = "VIC"
    case westernAustralia = "WA"
    case national = "AU"
}

enum CoverageMode: String, Codable, Sendable {
    case live
    case scheduled
    case delayed
    case demo
    case unavailable

    var trustLabel: String {
        switch self {
        case .live: "Live source"
        case .scheduled: "Scheduled price"
        case .delayed: "Delayed source"
        case .demo: "Demo data"
        case .unavailable: "Source unavailable"
        }
    }
}

struct SourceDescriptor: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let jurisdiction: Jurisdiction
    let coverage: CoverageMode
    let sourceURL: URL
    let attribution: String
    let licenceName: String
    let licenceURL: URL?

    init(
        id: String,
        name: String,
        jurisdiction: Jurisdiction,
        coverage: CoverageMode,
        sourceURL: URL,
        attribution: String,
        licenceName: String,
        licenceURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.jurisdiction = jurisdiction
        self.coverage = coverage
        self.sourceURL = sourceURL
        self.attribution = attribution
        self.licenceName = licenceName
        self.licenceURL = licenceURL
    }
}

