import Foundation

enum FuelGrade: String, CaseIterable, Codable, Sendable, Identifiable {
    case unleaded91
    case e10
    case unleaded95
    case unleaded98
    case diesel
    case premiumDiesel
    case lpg
    case e85
    case lowAromatic

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .unleaded91: "U91"
        case .e10: "E10"
        case .unleaded95: "U95"
        case .unleaded98: "U98"
        case .diesel: "Diesel"
        case .premiumDiesel: "P Diesel"
        case .lpg: "LPG"
        case .e85: "E85"
        case .lowAromatic: "LAF"
        }
    }

    init?(sourceName: String) {
        let normalized = sourceName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "U91", "ULP", "UNLEADED", "UNLEADED91", "91RON": self = .unleaded91
        case "E10", "UNLEADEDE10": self = .e10
        case "U95", "P95", "PULP95", "UNLEADED95", "95RON", "PULP": self = .unleaded95
        case "U98", "P98", "PULP98", "UNLEADED98", "98RON", "98": self = .unleaded98
        case "DIESEL", "DSL": self = .diesel
        case "PDSL", "PREMIUMDIESEL", "BRANDDIESEL": self = .premiumDiesel
        case "LPG": self = .lpg
        case "E85": self = .e85
        case "LAF", "LOWAROMATIC", "LOWAROMATICFUEL": self = .lowAromatic
        default: return nil
        }
    }
}

