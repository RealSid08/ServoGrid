import MapKit
import SwiftUI

struct StationDetailSheet: View {
    @Environment(AppStore.self) private var store
    let station: FuelStation
    @Binding var showingAlertSetup: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    priceBlock
                    metaBlock
                    timelineBlock
                    sourceBlock
                    actionsBlock
                }
                .padding(16)
            }
            .background(GridPalette.surface)
            .navigationTitle(station.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(GridPalette.surface)
        .accessibilityIdentifier(AccessibilityID.stationSheet)
        .sheet(isPresented: $showingAlertSetup) {
            AlertSetupView(station: station)
        }
    }

    private var observation: FuelPriceObservation? { station.selectedObservation }
    private var movement: PriceMovement { store.movement(for: station.id) }
    private var band: RelativePriceBand { store.relativeBand(for: station.id) }
    private var freshness: FreshnessState { store.freshness(for: station.id) }

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.selectedGrade.displayName.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(GridPalette.muted)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(observation.map { PresentationFormat.price($0.priceCentsPerLitre) } ?? "—")
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(GridPalette.ink)
                    .contentTransition(.numericText())
                    .animation(GridMotion.valueChange(), value: observation?.priceCentsPerLitre)
                Text("c/L")
                    .font(.system(.title3, design: .default, weight: .medium))
                    .foregroundStyle(GridPalette.muted)
                Text(movement.symbol)
                    .font(.system(.title2, design: .default, weight: .semibold))
                    .foregroundStyle(GridPalette.band(band))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(priceAccessibility)

            HStack(spacing: 12) {
                cue(movement.detailPhrase)
                cue(band.displayName, color: GridPalette.band(band))
                cue(freshness.displayName, color: GridPalette.freshness(freshness))
            }
            .font(.system(.caption, design: .default, weight: .medium))
        }
    }

    private var priceAccessibility: String {
        guard let observation else { return "\(station.name), price unavailable" }
        return "\(station.name), \(PresentationFormat.priceWithUnit(observation.priceCentsPerLitre)), \(movement.accessibilityPhrase), \(band.accessibilityPhrase)"
    }

    private func cue(_ text: String, color: Color = GridPalette.muted) -> some View {
        Text(text)
            .foregroundStyle(color)
    }

    private var metaBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Hairline()
            if let brand = station.brand, !brand.isEmpty {
                EvidenceRow(label: "Brand", value: brand)
            }
            EvidenceRow(label: "Address", value: [station.address, station.suburb, station.state, station.postcode]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", "))
            EvidenceRow(
                label: "Price validity",
                value: store.selectedDay == .tomorrow ? "Tomorrow · scheduled" : "Today"
            )
            if let restrictions = observation?.restrictions, !restrictions.isEmpty {
                EvidenceRow(label: "Restrictions", value: restrictions)
            }
        }
    }

    private var timelineBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Hairline()
            SectionLabel(title: "Evidence")
            EvidenceRow(label: "Price effective", value: PresentationFormat.timestamp(observation?.sourceEventAt))
            EvidenceRow(label: "Dataset published", value: PresentationFormat.timestamp(observation?.sourceDatasetAt))
            EvidenceRow(label: "First observed", value: PresentationFormat.timestamp(observation?.observedAt))
            EvidenceRow(label: "Last checked", value: PresentationFormat.timestamp(observation?.checkedAt))
        }
    }

    private var sourceBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Hairline()
            SectionLabel(title: "Source")
            TrustLabelView(text: store.trustLabel, emphasizeDemo: store.isDemo)
            Text(store.source.attribution)
                .font(.system(.body, design: .default))
                .foregroundStyle(GridPalette.ink)
                .accessibilityIdentifier(AccessibilityID.stationSource)
            Text(store.source.licenceName)
                .font(.system(.caption, design: .default))
                .foregroundStyle(GridPalette.muted)
            Link(destination: store.source.sourceURL) {
                Text(store.source.sourceURL.absoluteString)
                    .font(.system(.footnote, design: .default))
                    .underline()
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier(AccessibilityID.stationSourceLink)
        }
    }

    private var actionsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Hairline()
            Button {
                openDirections()
            } label: {
                Label("Directions in Maps", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(GridButtonStyle())
            .accessibilityIdentifier(AccessibilityID.stationDirections)

            Button {
                showingAlertSetup = true
            } label: {
                Label("Set a price alert", systemImage: "bell")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(GridButtonStyle(prominent: true))
            .accessibilityIdentifier(AccessibilityID.stationAlertSetup)
        }
    }

    private func openDirections() {
        let coordinate = CLLocationCoordinate2D(latitude: station.latitude, longitude: station.longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = station.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
