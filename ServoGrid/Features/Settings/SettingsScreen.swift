import SwiftUI

struct SettingsScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(LocationService.self) private var location
    @State private var showingAlertSetup = false
    @State private var isSwitching = false

    var body: some View {
        ScreenScaffold(title: "Settings", trustLabel: store.trustLabel, isDemo: store.isDemo) {
            List {
                sourceSection
                matrixSection
                alertsSection
                permissionsSection
                privacySection
                cacheSection
                aboutSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(GridPalette.canvas)
        }
        .sheet(isPresented: $showingAlertSetup) {
            AlertSetupView(station: nil)
        }
    }

    private var sourceSection: some View {
        Section {
            sourceRow(
                title: "Demo",
                subtitle: "National evaluation fixtures",
                selected: store.sourceMode == .demo,
                identifier: AccessibilityID.settingsSourceDemo
            ) {
                Task { await switchSource(.demo) }
            }
            sourceRow(
                title: "WA FuelWatch",
                subtitle: "Public live and scheduled prices",
                selected: store.sourceMode == .fuelWatch,
                identifier: AccessibilityID.settingsSourceFuelWatch
            ) {
                Task { await switchSource(.fuelWatch) }
            }
            if isSwitching {
                HStack {
                    ProgressView()
                    Text("Switching source…")
                        .foregroundStyle(GridPalette.muted)
                }
                .frame(minHeight: 44)
            }
        } header: {
            SectionLabel(title: "Source")
        }
        .listRowBackground(GridPalette.surface)
        .listRowSeparatorTint(GridPalette.hairline)
    }

    private func sourceRow(
        title: String,
        subtitle: String,
        selected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(GridPalette.ink)
                    Text(subtitle)
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(GridPalette.muted)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(GridPalette.teal)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .disabled(isSwitching)
    }

    private var matrixSection: some View {
        Section {
            ForEach(SourceAccessMatrix.rows) { row in
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(row.descriptor.jurisdiction.rawValue)
                                .font(.system(.body, design: .monospaced, weight: .semibold))
                            Text(row.descriptor.name)
                                .foregroundStyle(GridPalette.ink)
                        }
                        Text(row.statusCopy)
                            .font(.system(.footnote, design: .default))
                            .foregroundStyle(GridPalette.muted)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier(AccessibilityID.sourceRow(row.descriptor.id))
                    .accessibilityLabel("\(row.descriptor.jurisdiction.rawValue) \(row.descriptor.name). \(row.statusCopy)")
                    if !row.selectableLive {
                        Link("Official source", destination: row.descriptor.sourceURL)
                            .font(.system(.footnote, design: .default, weight: .semibold))
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Australia source access")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(GridPalette.muted)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(AccessibilityID.settingsSourceMatrix)
        }
        .listRowBackground(GridPalette.surface)
        .listRowSeparatorTint(GridPalette.hairline)
        .accessibilityIdentifier(AccessibilityID.settingsSourceMatrix)
    }

    private var alertsSection: some View {
        Section {
            Button {
                showingAlertSetup = true
            } label: {
                Text("Create an alert")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier(AccessibilityID.settingsCreateAlert)

            if store.alertPreferences.isEmpty {
                Text("No alerts enabled.")
                    .foregroundStyle(GridPalette.muted)
            } else {
                ForEach(store.alertPreferences) { preference in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preference.areaName)
                            Text("\(preference.fuelGrade.displayName) · drop \(PresentationFormat.price(preference.dropThreshold)) · spike \(PresentationFormat.price(preference.spikeThreshold))")
                                .font(.system(.caption, design: .default))
                                .foregroundStyle(GridPalette.muted)
                        }
                        Spacer()
                        Button("Remove") {
                            store.removeAlert(id: preference.id)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        } header: {
            SectionLabel(title: "Alerts")
        } footer: {
            Text(BackgroundRefreshService.limitation)
        }
        .listRowBackground(GridPalette.surface)
        .listRowSeparatorTint(GridPalette.hairline)
    }

    private var permissionsSection: some View {
        Section {
            labeledValue("Location", locationStatus)
            labeledValue("Notifications", "Requested only when you enable an alert. Opening this screen does not prompt.")
        } header: {
            SectionLabel(title: "Permissions")
        } footer: {
            Text("Location is requested only from the locate control on the Grid. Notifications are requested only from the Enable alert action.")
        }
        .listRowBackground(GridPalette.surface)
        .listRowSeparatorTint(GridPalette.hairline)
    }

    private var privacySection: some View {
        Section {
            Text("No account. No analytics. Source requests stay on-device besides the fuel endpoint you explicitly select.")
                .font(.system(.body, design: .default))
        } header: {
            SectionLabel(title: "Privacy")
        }
        .listRowBackground(GridPalette.surface)
        .listRowSeparatorTint(GridPalette.hairline)
    }

    private var cacheSection: some View {
        Section {
            Text("Snapshots are stored locally as a versioned JSON envelope. Offline cached data stays visible with the failure message. Demo fixtures are never used as a silent fallback for live sources.")
                .font(.system(.body, design: .default))
        } header: {
            SectionLabel(title: "Cache")
        }
        .listRowBackground(GridPalette.surface)
        .listRowSeparatorTint(GridPalette.hairline)
    }

    private var aboutSection: some View {
        Section {
            labeledValue("App", "ServoGrid 1.0")
            labeledValue("Role", "Australian fuel-price intelligence map")
            labeledValue("Active source", store.source.name)
            labeledValue("Records", "\(store.stations.count)")
        } header: {
            SectionLabel(title: "About")
        }
        .listRowBackground(GridPalette.surface)
        .listRowSeparatorTint(GridPalette.hairline)
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .default, weight: .medium))
                .foregroundStyle(GridPalette.muted)
            Text(value)
                .font(.system(.body, design: .default))
                .foregroundStyle(GridPalette.ink)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var locationStatus: String {
        switch location.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            "Allowed for nearby prices after you tap Locate."
        case .denied, .restricted:
            "Off. The national grid remains explorable manually."
        case .notDetermined:
            "Not requested until you tap Locate."
        @unknown default:
            "Unknown."
        }
    }

    private func switchSource(_ mode: SourceMode) async {
        guard store.sourceMode != mode else { return }
        isSwitching = true
        defer { isSwitching = false }
        let seed: FuelSnapshot? = mode == .demo
            ? try? FixtureAdapter.loadSnapshot(resourceName: "demo-national-previous")
            : nil
        await store.switchSource(
            mode: mode,
            adapter: AppEnvironment.adapter(for: mode),
            seedSnapshot: seed
        )
    }
}

enum SourceAccessMatrix {
    struct Row: Identifiable {
        var id: String { descriptor.id }
        let descriptor: SourceDescriptor
        let statusCopy: String
        let selectableLive: Bool
    }

    static let rows: [Row] = [
        Row(
            descriptor: SourceCatalog.fuelWatch,
            statusCopy: "Public live and scheduled prices. Selectable as a live source.",
            selectableLive: true
        ),
        Row(
            descriptor: SourceCatalog.fuelCheck(.newSouthWales),
            statusCopy: "Credentials and subscriber agreement required. Not selectable as live.",
            selectableLive: false
        ),
        Row(
            descriptor: SourceCatalog.fuelCheck(.tasmania),
            statusCopy: "Credentials and subscriber agreement required. Not selectable as live.",
            selectableLive: false
        ),
        Row(
            descriptor: SourceCatalog.victoria,
            statusCopy: "24-hour delayed output and approval required. Not selectable as live.",
            selectableLive: false
        ),
        Row(
            descriptor: SourceCatalog.queensland,
            statusCopy: "Token and consumer signup required. Not selectable as live.",
            selectableLive: false
        ),
        Row(
            descriptor: SourceCatalog.southAustralia,
            statusCopy: "Registered publisher access only. Not selectable as live.",
            selectableLive: false
        ),
        Row(
            descriptor: SourceCatalog.northernTerritory,
            statusCopy: "Third-party API and reuse terms unverified. Not selectable as live.",
            selectableLive: false
        ),
        Row(
            descriptor: SourceCatalog.act,
            statusCopy: "Coverage unverified. Not selectable as live.",
            selectableLive: false
        ),
        Row(
            descriptor: SourceCatalog.demo,
            statusCopy: "National fixture demo only. Never labelled live.",
            selectableLive: false
        )
    ]
}
