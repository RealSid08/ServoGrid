import SwiftUI

struct MonitorScreen: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScreenScaffold(title: "Monitor", trustLabel: store.trustLabel, isDemo: store.isDemo) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch store.loadState {
                    case .idle, .loading:
                        Text("Checking source health…")
                            .font(.system(.body, design: .default))
                            .foregroundStyle(GridPalette.muted)
                            .padding(.top, 12)
                    case .failed(let message):
                        GridEmptyState(title: "Monitor unavailable", message: message, actionTitle: "Retry") {
                            Task { await store.refresh() }
                        }
                    case .offlineCached(let message):
                        Text(message)
                            .font(.system(.footnote, design: .default))
                            .foregroundStyle(GridPalette.amber)
                        healthAndIssues
                    case .loaded:
                        healthAndIssues
                    }

                    explanation
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var healthAndIssues: some View {
        if let health = store.sourceHealth {
            SourceHealthCard(health: health)
        }
        IssueList(issues: store.monitorIssues, isDemo: store.isDemo)
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "What this verifies")
            Text("The monitor checks timestamps, price and coordinate plausibility, schema version, empty feeds, and duplicate stations. It does not invent prices or upgrade demo fixtures into live data.")
                .font(.system(.footnote, design: .default))
                .foregroundStyle(GridPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SourceHealthCard: View {
    let health: SourceHealth

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(health.sourceName)
                    .font(.system(.headline, design: .default, weight: .semibold))
                Spacer()
                Text(health.state.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(GridPalette.health(health.state))
            }
            Text(health.message)
                .font(.system(.body, design: .default))
                .foregroundStyle(GridPalette.ink)
            HStack(spacing: 14) {
                metric("Last success", PresentationFormat.compactTimestamp(health.lastSuccess))
                metric("Last check", PresentationFormat.compactTimestamp(health.lastCheck))
            }
            HStack(spacing: 14) {
                metric("Records", "\(health.recordCount)")
                metric("Issues", "\(health.issueCount)")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GridPalette.surface)
        .overlay { Rectangle().strokeBorder(GridPalette.hairline, lineWidth: 0.5) }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(AccessibilityID.monitorHealth)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        [
            health.sourceName,
            health.state.displayName,
            health.message,
            "Last success \(PresentationFormat.compactTimestamp(health.lastSuccess))",
            "Last check \(PresentationFormat.compactTimestamp(health.lastCheck))",
            "\(health.recordCount) records",
            "\(health.issueCount) issues"
        ].joined(separator: ", ")
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(GridPalette.muted)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IssueList: View {
    let issues: [MonitorIssue]
    let isDemo: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Issues")
            if issues.isEmpty {
                Text(emptyCopy)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(GridPalette.muted)
                    .accessibilityIdentifier(AccessibilityID.monitorIssues)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedIssues) { issue in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: issue.severity.iconName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(GridPalette.severity(issue.severity))
                                .frame(width: 24, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(issue.severity.cue) \(issue.severity.displayName) · \(issue.code.displayName)")
                                    .font(.system(.caption, design: .default, weight: .semibold))
                                    .foregroundStyle(GridPalette.severity(issue.severity))
                                Text(issue.summary)
                                    .font(.system(.body, design: .default))
                            }
                        }
                        .padding(.vertical, 4)
                        Hairline()
                    }
                }
                .accessibilityIdentifier(AccessibilityID.monitorIssues)
            }
        }
    }

    private var sortedIssues: [MonitorIssue] {
        issues.sorted { lhs, rhs in
            severityRank(lhs.severity) < severityRank(rhs.severity)
        }
    }

    private func severityRank(_ severity: MonitorSeverity) -> Int {
        switch severity {
        case .critical: 0
        case .warning: 1
        case .info: 2
        }
    }

    private var emptyCopy: String {
        if isDemo {
            "Checks passed. These are fixture checks."
        } else {
            "Checks passed."
        }
    }
}
