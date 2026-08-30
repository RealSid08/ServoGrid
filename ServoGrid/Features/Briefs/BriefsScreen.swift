import SwiftUI

struct BriefsScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScreenScaffold(title: "Briefs", trustLabel: store.trustLabel, isDemo: store.isDemo) {
            Group {
                switch store.loadState {
                case .idle, .loading:
                    GridEmptyState(
                        title: "Preparing briefs",
                        message: "Regional summaries appear only after comparable observations are loaded."
                    )
                case .failed(let message):
                    GridEmptyState(title: "Briefs unavailable", message: message, actionTitle: "Retry") {
                        Task { await store.refresh() }
                    }
                case .offlineCached(let message):
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(message)
                                .font(.system(.footnote, design: .default))
                                .foregroundStyle(GridPalette.amber)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                            briefsContent
                        }
                    }
                case .loaded:
                    briefsContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var briefsContent: some View {
        if store.briefs.isEmpty {
            GridEmptyState(
                title: "No qualifying brief",
                message: "The evidence threshold was not met for the current source, grade, and comparison window."
            )
            .accessibilityIdentifier(AccessibilityID.briefsEmpty)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.briefs) { brief in
                        BriefCard(brief: brief)
                    }
                }
                .padding(16)
            }
            .accessibilityIdentifier(AccessibilityID.briefsList)
        }
    }
}

private struct BriefCard: View {
    let brief: GridBrief

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(brief.region.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.3)
                .foregroundStyle(GridPalette.muted)
            Text(brief.text)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(GridPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Text(brief.fuelGrade.displayName)
                Text(PresentationFormat.signedCents(brief.meanChange))
                    .font(.system(.body, design: .monospaced))
                    .monospacedDigit()
                Text(PresentationFormat.count(brief.sampleSize, singular: "station", plural: "stations"))
            }
            .font(.system(.caption, design: .default, weight: .medium))
            .foregroundStyle(GridPalette.muted)

            Text("Generated \(PresentationFormat.timestamp(brief.generatedAt))")
                .font(.system(.caption2, design: .default))
                .foregroundStyle(GridPalette.muted)

            ForEach(brief.sourceAttributions, id: \.self) { attribution in
                Text(attribution)
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(GridPalette.muted)
            }

            DisclosureGroup("Evidence") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(brief.evidenceObservationIDs.count) observation IDs from \(brief.sampleSize) comparable stations.")
                        .font(.system(.footnote, design: .default))
                    ForEach(brief.evidenceObservationIDs, id: \.self) { identifier in
                        Text(identifier)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(GridPalette.ink)
                            .textSelection(.enabled)
                    }
                }
                .padding(.top, 6)
            }
            .tint(GridPalette.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GridPalette.surface)
        .overlay {
            Rectangle().strokeBorder(GridPalette.hairline, lineWidth: 0.5)
        }
    }
}
