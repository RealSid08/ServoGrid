import Foundation

struct SourceCapabilities: Sendable {
    let supportedGrades: Set<FuelGrade>
    let supportsToday: Bool
    let supportsTomorrow: Bool
    let supportsHistory: Bool
    let requiresCredentials: Bool
}

enum SourceFailure: Error, Equatable, Sendable {
    case unsupportedFuel(FuelGrade)
    case unsupportedDay(PriceValidity)
    case credentialsRequired(Jurisdiction)
    case unavailable(Jurisdiction, String)
    case invalidResponse(String)
    case httpStatus(Int)
}

protocol FuelSourceAdapter: Sendable {
    var source: SourceDescriptor { get }
    var capabilities: SourceCapabilities { get }

    func fetch(grade: FuelGrade, day: PriceValidity) async throws -> FuelSnapshot
}

