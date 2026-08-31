import MapKit
import SwiftUI

struct GridScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @Environment(\.colorScheme) private var colorScheme

    @State private var pendingCenter: CLLocationCoordinate2D?
    @State private var showingAlertSetup = false
    @State private var showingStationIndex = false

    var body: some View {
        ZStack(alignment: .top) {
            FuelMapView(
                stations: mapStations,
                selectedStationID: store.selectedStation?.id,
                sourceID: store.source.id,
                showsUserLocation: showsUserLocation,
                centerCoordinate: pendingCenter,
                colorScheme: colorScheme,
                onSelectStation: { station in
                    GridHaptics.selection()
                    store.selectedStation = station
                },
                onSelectCluster: {
                    GridHaptics.impact()
                },
                onUserCameraChange: {},
                onConsumedCenter: { pendingCenter = nil }
            )
            .ignoresSafeArea()
            .accessibilityIdentifier(AccessibilityID.gridMap)

            VStack(spacing: 8) {
                statusBlock
                    .accessibilityIdentifier(AccessibilityID.gridStatus)
                Spacer(minLength: 0)
                bottomControls
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .sheet(isPresented: $showingStationIndex) {
                StationIndexSheet(stations: store.stations) { station in
                    store.selectedStation = station
                    showingStationIndex = false
                }
            }
        }
        .background(GridPalette.canvas)
        .sheet(item: selectedStationBinding) { station in
            StationDetailSheet(station: station, showingAlertSetup: $showingAlertSetup)
        }
        .onChange(of: location.location?.timestamp) { _, _ in
            guard let coordinate = location.location?.coordinate else { return }
            pendingCenter = coordinate
        }
        .onChange(of: store.selectedGrade) { _, _ in
            store.selectedStation = nil
        }
        .onChange(of: store.selectedDay) { _, _ in
            store.selectedStation = nil
        }
    }

    private var selectedStationBinding: Binding<FuelStation?> {
        Binding(
            get: { store.selectedStation },
            set: { store.selectedStation = $0 }
        )
    }

    private var mapStations: [MapStationItem] {
        store.stations.compactMap { station in
            guard let observation = station.selectedObservation else { return nil }
            return MapStationItem(
                station: station,
                priceCents: observation.priceCentsPerLitre,
                movement: store.movement(for: station.id),
                band: store.relativeBand(for: station.id)
            )
        }
    }

    private var showsUserLocation: Bool {
        location.authorizationStatus == .authorizedWhenInUse
            || location.authorizationStatus == .authorizedAlways
    }

    private var statusBlock: some View {
        MapChrome {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ServoGrid")
                            .font(.system(.headline, design: .default, weight: .semibold))
                            .tracking(0.8)
                            .foregroundStyle(GridPalette.ink)
                        TrustLabelView(text: store.trustLabel, emphasizeDemo: store.isDemo)
                    }
                    Spacer(minLength: 8)
                    refreshControl
                }
                Button {
                    showingStationIndex = true
                } label: {
                    Text(statusLine)
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(GridPalette.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .disabled(store.stations.isEmpty)
                .accessibilityIdentifier(AccessibilityID.gridStationIndex)
                .accessibilityLabel("Station index, \(statusLine)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statusLine: String {
        let source = store.source.name
        let records = PresentationFormat.count(store.stations.count, singular: "record", plural: "records")
        switch store.loadState {
        case .loading, .idle:
            return "\(source) · loading"
        case .loaded:
            return "\(source) · \(records)"
        case .offlineCached:
            return "\(source) · \(records) · cached"
        case .failed:
            return "\(source) · unavailable"
        }
    }

    private var refreshControl: some View {
        Button {
            GridHaptics.impact()
            Task { await store.refresh() }
        } label: {
            Group {
                if store.loadState == .loading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .disabled(store.loadState == .loading)
        .accessibilityLabel("Refresh prices")
        .accessibilityIdentifier(AccessibilityID.gridRefresh)
    }

    private var bottomControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = store.loadState.errorMessage {
                statusStrip(
                    identifier: store.stations.isEmpty ? AccessibilityID.gridError : AccessibilityID.gridOffline,
                    text: message,
                    actionTitle: "Retry"
                ) {
                    Task { await store.refresh() }
                }
            } else if store.loadState == .loaded, store.stations.isEmpty {
                statusStrip(
                    identifier: AccessibilityID.gridEmpty,
                    text: "No stations for \(store.selectedGrade.displayName) · \(store.selectedDay.displayName).",
                    actionTitle: "Clear filters"
                ) {
                    Task { await store.select(grade: .unleaded91, day: .today) }
                }
            }

            if let locationError = location.errorMessage {
                statusStrip(identifier: "grid.location.error", text: locationError, actionTitle: nil, action: nil)
            }

            HStack(alignment: .bottom, spacing: 8) {
                fuelSelector
                locateButton
            }

            if store.supportsTomorrow || store.selectedDay == .tomorrow {
                dayControl
            }
        }
    }

    private func statusStrip(
        identifier: String,
        text: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        MapChrome {
            HStack(alignment: .center, spacing: 10) {
                Text(text)
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(GridPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .frame(minHeight: 44)
                }
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private var fuelSelector: some View {
        MapChrome {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(FuelGrade.allCases) { grade in
                        Button {
                            GridHaptics.selection()
                            Task { await store.select(grade: grade, day: store.selectedDay) }
                        } label: {
                            VStack(spacing: 4) {
                                Text(grade.shortName)
                                    .font(.system(.caption, design: .default, weight: store.selectedGrade == grade ? .semibold : .regular))
                                    .foregroundStyle(store.selectedGrade == grade ? GridPalette.ink : GridPalette.muted)
                                Rectangle()
                                    .fill(store.selectedGrade == grade ? GridPalette.teal : Color.clear)
                                    .frame(height: 1.5)
                            }
                            .padding(.horizontal, 8)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel(grade.displayName)
                        .accessibilityIdentifier(AccessibilityID.fuelGrade(grade))
                        .accessibilityAddTraits(store.selectedGrade == grade ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var locateButton: some View {
        Button {
            GridHaptics.impact()
            location.requestNearbyLocation()
        } label: {
            MapChrome {
                Image(systemName: "location")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
        }
        .accessibilityLabel("Show nearby prices")
        .accessibilityHint("Requests location only after you tap")
        .accessibilityIdentifier(AccessibilityID.gridLocate)
    }

    private var dayControl: some View {
        MapChrome {
            HStack(spacing: 0) {
                dayButton(.today)
                Rectangle()
                    .fill(GridPalette.hairline)
                    .frame(width: 0.5, height: 22)
                dayButton(.tomorrow)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func dayButton(_ day: PriceValidity) -> some View {
        let selected = store.selectedDay == day
        let tomorrowUnsupported = day == .tomorrow && !store.supportsTomorrow
        return Button {
            guard !tomorrowUnsupported else { return }
            GridHaptics.selection()
            Task { await store.select(grade: store.selectedGrade, day: day) }
        } label: {
            VStack(spacing: 2) {
                Text(day.displayName)
                    .font(.system(.subheadline, design: .default, weight: selected ? .semibold : .regular))
                if day == .tomorrow {
                    Text(tomorrowUnsupported ? "Unsupported" : "Scheduled")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(GridPalette.amber)
                }
            }
            .foregroundStyle(selected ? GridPalette.ink : GridPalette.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(tomorrowUnsupported)
        .accessibilityIdentifier(day == .today ? AccessibilityID.dayToday : AccessibilityID.dayTomorrow)
        .accessibilityLabel(day == .tomorrow ? "Tomorrow, scheduled" : "Today")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .opacity(tomorrowUnsupported ? 0.45 : 1)
    }
}

private struct StationIndexSheet: View {
    let stations: [FuelStation]
    let onSelect: (FuelStation) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(stations) { station in
                Button {
                    onSelect(station)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(station.name)
                            .foregroundStyle(GridPalette.ink)
                        Text("\(station.suburb), \(station.state)")
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(GridPalette.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier(AccessibilityID.stationRow(station.id))
                .listRowBackground(GridPalette.surface)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(GridPalette.surface)
            .navigationTitle("Stations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(GridPalette.surface)
    }
}
