import Foundation
import Observation

enum SourceMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case demo
    case fuelWatch

    var id: String { rawValue }
}

enum AppLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case offlineCached(String)
    case failed(String)
}

enum SourceHealthState: String, Codable, Sendable {
    case operational
    case degraded
    case unavailable
    case demo
}

struct SourceHealth: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let sourceName: String
    let state: SourceHealthState
    let lastSuccess: Date?
    let lastCheck: Date
    let recordCount: Int
    let issueCount: Int
    let message: String
}

@MainActor
@Observable
final class AppStore {
    private(set) var sourceMode: SourceMode
    private(set) var loadState: AppLoadState = .idle
    private(set) var activeSnapshot: FuelSnapshot?
    private(set) var previousSnapshot: FuelSnapshot?
    private(set) var sourceHealth: SourceHealth?
    private(set) var monitorIssues: [MonitorIssue] = []
    private(set) var briefs: [GridBrief] = []
    private(set) var alertPreferences: [AlertPreference] = []
    private(set) var deliveredAlertIDs: Set<String> = []
    var selectedGrade: FuelGrade = .unleaded91
    var selectedDay: PriceValidity = .today
    var selectedStation: FuelStation?

    private var adapter: any FuelSourceAdapter
    private let cache: SnapshotCache
    private let notifications: any NotificationScheduling
    private let now: @Sendable () -> Date
    private let freshnessPolicy = FreshnessPolicy(freshFor: 2 * 60 * 60, staleAfter: 26 * 60 * 60)

    init(
        sourceMode: SourceMode,
        adapter: any FuelSourceAdapter,
        cache: SnapshotCache,
        notifications: any NotificationScheduling,
        seedSnapshot: FuelSnapshot? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.sourceMode = sourceMode
        self.adapter = adapter
        self.cache = cache
        self.notifications = notifications
        self.previousSnapshot = seedSnapshot
        self.now = now
    }

    var stations: [FuelStation] { activeSnapshot?.stations ?? [] }
    var isDemo: Bool { activeSnapshot?.isDemo ?? (adapter.source.coverage == .demo) }
    var trustLabel: String { activeSnapshot?.trustLabel ?? adapter.source.coverage.trustLabel }
    var source: SourceDescriptor { activeSnapshot?.source ?? adapter.source }
    var supportsTomorrow: Bool { adapter.capabilities.supportsTomorrow }

    func load() async {
        loadState = .loading
        do {
            if let envelope = try await cache.load() {
                let matches = envelope.snapshots.filter { $0.source.id == adapter.source.id }
                if let cached = matches.last.flatMap(filteredSnapshot) {
                    activeSnapshot = cached
                    if matches.count > 1 {
                        previousSnapshot = matches.dropLast().last.flatMap(filteredSnapshot)
                    }
                    applyDerivedState(for: cached, errorMessage: nil)
                }
            }
        } catch {
            // A bad cache is ignored; the network/fixture adapter remains authoritative.
        }
        await refresh()
    }

    func refresh() async {
        if activeSnapshot == nil { loadState = .loading }
        do {
            let snapshot = try await adapter.fetch(grade: selectedGrade, day: selectedDay)
            if let activeSnapshot,
               activeSnapshot.source.id == snapshot.source.id,
               activeSnapshot != snapshot {
                previousSnapshot = activeSnapshot
            }
            activeSnapshot = snapshot
            applyDerivedState(for: snapshot, errorMessage: nil)
            await deliverAlerts(previous: previousSnapshot, current: snapshot)
            try await persist(snapshot)
        } catch {
            let message = Self.userMessage(for: error)
            if activeSnapshot != nil {
                loadState = .offlineCached(message)
                sourceHealth = SourceHealth(
                    id: adapter.source.id,
                    sourceName: adapter.source.name,
                    state: .unavailable,
                    lastSuccess: activeSnapshot?.checkedAt,
                    lastCheck: now(),
                    recordCount: stations.count,
                    issueCount: monitorIssues.count,
                    message: message
                )
            } else {
                loadState = .failed(message)
                sourceHealth = SourceHealth(
                    id: adapter.source.id,
                    sourceName: adapter.source.name,
                    state: .unavailable,
                    lastSuccess: nil,
                    lastCheck: now(),
                    recordCount: 0,
                    issueCount: 0,
                    message: message
                )
            }
        }
    }

    func select(grade: FuelGrade, day: PriceValidity) async {
        selectedGrade = grade
        selectedDay = day
        activeSnapshot = filteredSnapshot(activeSnapshot)
        await refresh()
    }

    func switchSource(mode: SourceMode, adapter: any FuelSourceAdapter, seedSnapshot: FuelSnapshot? = nil) async {
        sourceMode = mode
        self.adapter = adapter
        activeSnapshot = nil
        previousSnapshot = seedSnapshot
        selectedStation = nil
        monitorIssues = []
        briefs = []
        await load()
    }

    func movement(for stationID: String) -> PriceMovement {
        guard let current = observation(in: activeSnapshot, stationID: stationID),
              let previous = observation(in: previousSnapshot, stationID: stationID) else {
            return .unavailable
        }
        return PriceMovementCalculator.compare(current: current, previous: previous)
    }

    func relativeBand(for stationID: String) -> RelativePriceBand {
        guard let station = stations.first(where: { $0.id == stationID }),
              let observation = station.observations.first else { return .insufficientData }
        let localPrices = stations
            .filter { $0.state == station.state }
            .compactMap { $0.observations.first?.priceCentsPerLitre }
        return RelativePriceClassifier.classify(price: observation.priceCentsPerLitre, localPrices: localPrices)
    }

    func freshness(for stationID: String) -> FreshnessState {
        guard let observation = observation(in: activeSnapshot, stationID: stationID) else { return .unknown }
        return FreshnessEvaluator.evaluate(observation, at: now(), policy: freshnessPolicy)
    }

    func enableAlert(_ preference: AlertPreference) async -> Bool {
        guard await notifications.requestAuthorization() else { return false }
        if !alertPreferences.contains(where: { $0.id == preference.id }) {
            alertPreferences.append(preference)
        }
        return true
    }

    func removeAlert(id: String) {
        alertPreferences.removeAll { $0.id == id }
    }

    private func applyDerivedState(for snapshot: FuelSnapshot, errorMessage: String?) {
        monitorIssues = GridMonitor.evaluate(snapshot: snapshot, now: now(), policy: freshnessPolicy)
        briefs = makeBriefs(current: snapshot, previous: previousSnapshot)
        let state: SourceHealthState = snapshot.isDemo ? .demo : monitorIssues.contains(where: { $0.severity == .critical }) ? .degraded : .operational
        sourceHealth = SourceHealth(
            id: snapshot.source.id,
            sourceName: snapshot.source.name,
            state: state,
            lastSuccess: snapshot.checkedAt,
            lastCheck: snapshot.checkedAt,
            recordCount: snapshot.stations.count,
            issueCount: monitorIssues.count,
            message: errorMessage ?? (snapshot.isDemo ? "Explicit evaluation fixtures" : "Source responded successfully")
        )
        loadState = .loaded
    }

    private func makeBriefs(current: FuelSnapshot, previous: FuelSnapshot?) -> [GridBrief] {
        guard let previous else { return [] }
        let states = Set(current.stations.map(\.state))
        return states.compactMap { state in
            let currentRegion = subset(current, state: state)
            let previousRegion = subset(previous, state: state)
            return GridBriefEngine.generate(
                region: Self.regionName(for: state),
                fuelGrade: selectedGrade,
                current: currentRegion,
                previous: previousRegion,
                now: now()
            )
        }.sorted { $0.region < $1.region }
    }

    private func subset(_ snapshot: FuelSnapshot, state: String) -> FuelSnapshot {
        FuelSnapshot(
            schemaVersion: snapshot.schemaVersion,
            source: snapshot.source,
            stations: snapshot.stations.filter { $0.state == state },
            checkedAt: snapshot.checkedAt
        )
    }

    private func observation(in snapshot: FuelSnapshot?, stationID: String) -> FuelPriceObservation? {
        snapshot?.stations.first(where: { $0.id == stationID })?.observations.first(where: {
            $0.fuelGrade == selectedGrade && $0.validity == selectedDay
        })
    }

    private func filteredSnapshot(_ snapshot: FuelSnapshot?) -> FuelSnapshot? {
        guard let snapshot else { return nil }
        let filteredStations = snapshot.stations.compactMap { station -> FuelStation? in
            let observations = station.observations.filter {
                $0.fuelGrade == selectedGrade && $0.validity == selectedDay
            }
            guard !observations.isEmpty else { return nil }
            return try? FuelStation(
                id: station.id,
                sourceStationID: station.sourceStationID,
                name: station.name,
                brand: station.brand,
                address: station.address,
                suburb: station.suburb,
                state: station.state,
                postcode: station.postcode,
                latitude: station.latitude,
                longitude: station.longitude,
                observations: observations
            )
        }
        return FuelSnapshot(
            schemaVersion: snapshot.schemaVersion,
            source: snapshot.source,
            stations: filteredStations,
            checkedAt: snapshot.checkedAt
        )
    }

    private func deliverAlerts(previous: FuelSnapshot?, current: FuelSnapshot) async {
        let events = AlertEngine.evaluate(
            previous: previous,
            current: current,
            preferences: alertPreferences,
            deliveredEventIDs: deliveredAlertIDs
        )
        guard !events.isEmpty else { return }
        do {
            try await notifications.schedule(events)
            deliveredAlertIDs.formUnion(events.map(\.id))
        } catch {
            // Price state remains valid when local notification delivery fails.
        }
    }

    private func persist(_ snapshot: FuelSnapshot) async throws {
        var snapshots = (try await cache.load()?.snapshots ?? [])
        if !snapshots.contains(snapshot) { snapshots.append(snapshot) }
        if snapshots.count > 48 { snapshots.removeFirst(snapshots.count - 48) }
        try await cache.save(CacheEnvelope(version: SnapshotCache.currentVersion, snapshots: snapshots))
    }

    private static func regionName(for state: String) -> String {
        switch state {
        case "VIC": "Victoria"
        case "NSW": "New South Wales"
        case "QLD": "Queensland"
        case "WA": "Western Australia"
        case "SA": "South Australia"
        case "TAS": "Tasmania"
        case "NT": "Northern Territory"
        case "ACT": "Australian Capital Territory"
        default: state
        }
    }

    private static func userMessage(for error: Error) -> String {
        guard let failure = error as? SourceFailure else { return error.localizedDescription }
        return switch failure {
        case .unsupportedFuel(let grade): "\(grade.shortName) is not supported by this source."
        case .unsupportedDay: "Tomorrow prices are not supported by this source."
        case .credentialsRequired: "Source credentials are required and have not been configured."
        case .unavailable(_, let reason): reason
        case .invalidResponse(let reason): reason
        case .httpStatus(let code): "The source returned HTTP \(code)."
        }
    }
}
