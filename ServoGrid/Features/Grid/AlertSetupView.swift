import SwiftUI

struct AlertSetupView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var station: FuelStation?

    @State private var areaName: String
    @State private var dropThreshold: Double
    @State private var spikeThreshold: Double
    @State private var tomorrowPublished: Bool
    @State private var sourceOutage: Bool
    @State private var statusMessage: String?

    init(station: FuelStation? = nil) {
        self.station = station
        _areaName = State(initialValue: station?.suburb ?? "Current source")
        _dropThreshold = State(initialValue: 5)
        _spikeThreshold = State(initialValue: 10)
        _tomorrowPublished = State(initialValue: true)
        _sourceOutage = State(initialValue: true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Local alerts fire only after ServoGrid can run. Background refresh is best effort and is not continuous server monitoring.")
                        .font(.system(.body, design: .default))
                        .foregroundStyle(GridPalette.muted)

                    labeledField("Area") {
                        TextField("Area name", text: $areaName)
                            .textFieldStyle(.plain)
                            .frame(minHeight: 44)
                    }

                    stepperField(
                        title: "Drop threshold",
                        value: $dropThreshold,
                        identifier: AccessibilityID.alertDropThreshold
                    )
                    stepperField(
                        title: "Spike threshold",
                        value: $spikeThreshold,
                        identifier: AccessibilityID.alertSpikeThreshold
                    )

                    Toggle("Tomorrow price published", isOn: $tomorrowPublished)
                        .frame(minHeight: 44)
                    Toggle("Source outage", isOn: $sourceOutage)
                        .frame(minHeight: 44)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(.footnote, design: .default))
                            .foregroundStyle(GridPalette.coral)
                    }

                    Button("Enable alert") {
                        Task { await enable() }
                    }
                    .buttonStyle(GridButtonStyle(prominent: true))
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(AccessibilityID.alertEnable)
                }
                .padding(16)
            }
            .background(GridPalette.surface)
            .navigationTitle("Alert setup")
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
        .accessibilityIdentifier(AccessibilityID.alertSetup)
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(title: title)
            content()
                .padding(.horizontal, 8)
                .overlay {
                    Rectangle().strokeBorder(GridPalette.hairline, lineWidth: 0.5)
                }
        }
    }

    private func stepperField(title: String, value: Binding<Double>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(title: title)
            HStack {
                Text("\(PresentationFormat.price(value.wrappedValue)) c/L")
                    .font(.system(.body, design: .monospaced))
                    .monospacedDigit()
                Spacer()
                Stepper(title, value: value, in: 1...40, step: 0.5)
                    .labelsHidden()
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier(identifier)
        }
    }

    private func enable() async {
        let trimmed = areaName.trimmingCharacters(in: .whitespacesAndNewlines)
        let preference = AlertPreference(
            id: "\(station?.id ?? "area"):\(store.selectedGrade.rawValue):\(trimmed)",
            areaName: trimmed.isEmpty ? "Current source" : trimmed,
            stationID: station?.id,
            fuelGrade: store.selectedGrade,
            dropThreshold: dropThreshold,
            spikeThreshold: spikeThreshold,
            tomorrowPublished: tomorrowPublished,
            sourceOutage: sourceOutage
        )
        let enabled = await store.enableAlert(preference)
        if enabled {
            GridHaptics.impact()
            dismiss()
        } else {
            statusMessage = "Notification permission was not granted. Alerts stay off until you enable them in Settings."
        }
    }
}
