import SwiftUI

enum AppTab: String, Hashable, CaseIterable {
    case grid
    case briefs
    case monitor
    case settings
}

struct RootTabView: View {
    @State private var tab: AppTab = .grid

    var body: some View {
        TabView(selection: $tab) {
            GridScreen()
                .tabItem { Label("Grid", systemImage: "square.grid.2x2") }
                .tag(AppTab.grid)
                .accessibilityIdentifier(AccessibilityID.tabGrid)

            BriefsScreen()
                .tabItem { Label("Briefs", systemImage: "text.alignleft") }
                .tag(AppTab.briefs)
                .accessibilityIdentifier(AccessibilityID.tabBriefs)

            MonitorScreen()
                .tabItem { Label("Monitor", systemImage: "waveform.path.ecg") }
                .tag(AppTab.monitor)
                .accessibilityIdentifier(AccessibilityID.tabMonitor)

            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
                .accessibilityIdentifier(AccessibilityID.tabSettings)
        }
        .tint(GridPalette.teal)
        .sensoryFeedback(.selection, trigger: tab)
        .onChange(of: tab) { _, _ in
            GridHaptics.selection()
        }
    }
}
