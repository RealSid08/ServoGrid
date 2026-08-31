import MapKit
import SwiftUI

struct MapStationItem: Identifiable {
    var id: String { station.id }
    let station: FuelStation
    let priceCents: Double
    let movement: PriceMovement
    let band: RelativePriceBand
}

struct FuelMapView: UIViewRepresentable {
    var stations: [MapStationItem]
    var selectedStationID: String?
    var sourceID: String
    var showsUserLocation: Bool
    var centerCoordinate: CLLocationCoordinate2D?
    var colorScheme: ColorScheme
    var onSelectStation: (FuelStation) -> Void
    var onSelectCluster: () -> Void
    var onUserCameraChange: () -> Void
    var onConsumedCenter: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.register(PriceMarkerView.self, forAnnotationViewWithReuseIdentifier: PriceMarkerView.reuseID)
        mapView.register(ClusterMarkerView.self, forAnnotationViewWithReuseIdentifier: ClusterMarkerView.reuseID)
        mapView.register(
            ClusterMarkerView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )
        mapView.showsCompass = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.accessibilityIdentifier = AccessibilityID.gridMap

        let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        config.showsTraffic = false
        mapView.preferredConfiguration = config

        let australia = PresentationFormat.australiaRegion
        mapView.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: australia.centerLatitude,
                    longitude: australia.centerLongitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: australia.latitudeDelta,
                    longitudeDelta: australia.longitudeDelta
                )
            ),
            animated: false
        )
        context.coordinator.didSetInitialRegion = true
        applyChrome(mapView, colorScheme: colorScheme)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        applyChrome(mapView, colorScheme: colorScheme)
        mapView.showsUserLocation = showsUserLocation
        context.coordinator.syncAnnotations(on: mapView)
        if let centerCoordinate {
            context.coordinator.center(mapView, on: centerCoordinate)
            DispatchQueue.main.async { onConsumedCenter() }
        }
        context.coordinator.syncSelection(on: mapView)
    }

    private func applyChrome(_ mapView: MKMapView, colorScheme: ColorScheme) {
        mapView.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        mapView.backgroundColor = colorScheme == .dark
            ? GridPalette.markerFillDark
            : GridPalette.markerFillLight
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FuelMapView
        var didSetInitialRegion = false
        var userAdjustedCamera = false
        var framedSourceID: String?
        private var isProgrammaticRegionChange = false

        init(parent: FuelMapView) {
            self.parent = parent
        }

        func syncAnnotations(on mapView: MKMapView) {
            let existing = mapView.annotations.compactMap { $0 as? StationPointAnnotation }
            let incomingIDs = Set(parent.stations.map(\.id))
            let obsolete = existing.filter { !incomingIDs.contains($0.station.id) }
            if !obsolete.isEmpty {
                mapView.removeAnnotations(obsolete)
            }

            var additions: [StationPointAnnotation] = []
            for item in parent.stations {
                if let current = existing.first(where: { $0.station.id == item.id }) {
                    current.apply(priceCents: item.priceCents, movement: item.movement, band: item.band)
                    current.coordinate = CLLocationCoordinate2D(
                        latitude: item.station.latitude,
                        longitude: item.station.longitude
                    )
                    if let marker = mapView.view(for: current) as? PriceMarkerView {
                        marker.configure(current, selected: current.station.id == parent.selectedStationID)
                    }
                } else {
                    additions.append(
                        StationPointAnnotation(
                            station: item.station,
                            priceCents: item.priceCents,
                            movement: item.movement,
                            band: item.band
                        )
                    )
                }
            }
            if !additions.isEmpty {
                mapView.addAnnotations(additions)
            }

            if framedSourceID != parent.sourceID, !parent.stations.isEmpty {
                framedSourceID = parent.sourceID
                frameAnnotationsIfNeeded(mapView)
            }
        }

        func syncSelection(on mapView: MKMapView) {
            let selectedID = parent.selectedStationID
            for annotation in mapView.annotations {
                guard let station = annotation as? StationPointAnnotation else { continue }
                let shouldSelect = station.station.id == selectedID
                let isSelected = mapView.selectedAnnotations.contains { $0 === station }
                if shouldSelect, !isSelected {
                    mapView.selectAnnotation(station, animated: !UIAccessibility.isReduceMotionEnabled)
                } else if !shouldSelect, isSelected {
                    mapView.deselectAnnotation(station, animated: false)
                }
            }
        }

        func center(_ mapView: MKMapView, on coordinate: CLLocationCoordinate2D) {
            isProgrammaticRegionChange = true
            userAdjustedCamera = true
            mapView.setRegion(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                ),
                animated: !UIAccessibility.isReduceMotionEnabled
            )
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: ClusterMarkerView.reuseID,
                    for: cluster
                )
                if let clusterView = view as? ClusterMarkerView {
                    clusterView.configure(cluster)
                    return clusterView
                }
                return view
            }
            guard let station = annotation as? StationPointAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: PriceMarkerView.reuseID,
                for: station
            )
            if let marker = view as? PriceMarkerView {
                marker.configure(station, selected: station.station.id == parent.selectedStationID)
                return marker
            }
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                zoom(to: cluster, in: mapView)
                parent.onSelectCluster()
                return
            }
            if let station = view.annotation as? StationPointAnnotation {
                parent.onSelectStation(station.station)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isProgrammaticRegionChange {
                isProgrammaticRegionChange = false
                return
            }
            if didSetInitialRegion {
                userAdjustedCamera = true
                parent.onUserCameraChange()
            }
        }

        func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
            let elements = views.filter {
                $0.annotation is StationPointAnnotation || $0.annotation is MKClusterAnnotation
            }
            if !elements.isEmpty {
                mapView.accessibilityElements = elements
            }
        }

        private func frameAnnotationsIfNeeded(_ mapView: MKMapView) {
            guard !userAdjustedCamera else { return }
            let annotations = mapView.annotations.filter { $0 is StationPointAnnotation }
            guard !annotations.isEmpty else { return }
            isProgrammaticRegionChange = true
            mapView.showAnnotations(annotations, animated: false)
            var region = mapView.region
            region.span.latitudeDelta = min(max(region.span.latitudeDelta * 1.12, 8), 48)
            region.span.longitudeDelta = min(max(region.span.longitudeDelta * 1.12, 8), 52)
            mapView.setRegion(region, animated: false)
        }

        private func zoom(to cluster: MKClusterAnnotation, in mapView: MKMapView) {
            var zoomRect = MKMapRect.null
            for member in cluster.memberAnnotations {
                let point = MKMapPoint(member.coordinate)
                let rect = MKMapRect(x: point.x, y: point.y, width: 1, height: 1)
                zoomRect = zoomRect.union(rect)
            }
            isProgrammaticRegionChange = true
            userAdjustedCamera = true
            mapView.setVisibleMapRect(
                zoomRect,
                edgePadding: UIEdgeInsets(top: 90, left: 36, bottom: 160, right: 36),
                animated: !UIAccessibility.isReduceMotionEnabled
            )
        }
    }
}
