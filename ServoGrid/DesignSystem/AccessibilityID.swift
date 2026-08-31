import Foundation

enum AccessibilityID {
    static let tabGrid = "tab.grid"
    static let tabBriefs = "tab.briefs"
    static let tabMonitor = "tab.monitor"
    static let tabSettings = "tab.settings"
    static let trustLabel = "trust.label"
    static let gridStatus = "grid.status"
    static let gridMap = "grid.map"
    static let gridRefresh = "grid.refresh"
    static let gridLocate = "grid.locate"
    static let gridOffline = "grid.offline"
    static let gridEmpty = "grid.empty"
    static let gridError = "grid.error"
    static let gridStationIndex = "grid.station.index"
    static let dayToday = "day.today"
    static let dayTomorrow = "day.tomorrow"
    static let stationSheet = "station.sheet"
    static let stationSource = "station.source"
    static let stationSourceLink = "station.source.link"
    static let stationDirections = "station.directions"
    static let stationAlertSetup = "station.alert.setup"
    static let clusterMarker = "cluster.marker"
    static let briefsList = "briefs.list"
    static let briefsEmpty = "briefs.empty"
    static let monitorHealth = "monitor.health"
    static let monitorIssues = "monitor.issues"
    static let settingsSourceDemo = "settings.source.demo"
    static let settingsSourceFuelWatch = "settings.source.fuelwatch"
    static let settingsSourceMatrix = "settings.source.matrix"
    static let settingsCreateAlert = "settings.alert.create"
    static let alertSetup = "alert.setup"
    static let alertEnable = "alert.enable"
    static let alertDropThreshold = "alert.drop.threshold"
    static let alertSpikeThreshold = "alert.spike.threshold"

    static func fuelGrade(_ grade: FuelGrade) -> String {
        "fuel.grade.\(grade.rawValue)"
    }

    static func stationMarker(_ id: String) -> String {
        "station.marker.\(id)"
    }

    static func stationRow(_ id: String) -> String {
        "station.row.\(id)"
    }

    static func sourceRow(_ id: String) -> String {
        "settings.source.row.\(id)"
    }
}
