# ServoGrid UI implementation brief

## Ownership boundary

You own the complete visual implementation only. Build the SwiftUI and MapKit surfaces, design system, app shell, and UI tests described below. The existing domain, intelligence, adapters, cache, services, fixtures, and app-store logic are already tested and are authoritative. Do not rewrite their algorithms, invent fuel prices, add network calls, add packages, or silently fall back from live data to fixtures. You may make the smallest compile-safe presentation accessor addition to `AppStore` only if a view cannot consume an existing value; otherwise leave non-UI code unchanged.

Run XcodeGen after adding files. Build and test your work with the installed Xcode 27 toolchain before stopping.

## Platform contract

- Native iPhone app, SwiftUI plus MapKit. Minimum iOS 17.0.
- Compile against the installed iOS 27 SDK with Swift 6 strict concurrency.
- Design for iOS 26/27, but availability-gate every API newer than iOS 17 and preserve an equivalent iOS 17 interaction.
- No third-party dependencies, web views, analytics, login, or onboarding gate.
- Respect Dynamic Type, VoiceOver, Reduce Motion, dark/light schemes, 44-point targets, safe areas, and one-handed use.
- Permission prompts must remain user initiated: location only from the locate control; notifications only when an alert is enabled.

## Product and visual direction

ServoGrid is an Australian fuel-price intelligence map, not a generic petrol finder. The memorable idea is a calm cartographic command grid: a near-black graphite/navy map frame, hairline grid/signal motifs, electric teal for trustworthy signal, amber for scheduled/ageing information, and coral for anomalies. In light mode, translate that into warm off-white, ink navy, and the same restrained signal accents. Avoid purple gradients, glass-card soup, enormous rounded rectangles, floating pills everywhere, fake charts, or decorative data.

Use crisp, editorial hierarchy. Large prices use monospaced digits and compact units. Briefs may use a restrained serif treatment for contrast, while controls and evidence use highly legible system typography. The interface should feel intentional and technical without becoming a sci-fi dashboard. Materials and blur are allowed only for controls over the map; use solid surfaces for evidence-heavy sheets.

Motion should explain state: marker selection, sheet presentation, refresh progress, tab selection, and value change. Use subtle haptics where appropriate. Gate newer symbol/content transitions and provide a no-animation Reduce Motion path.

## Required navigation and states

Create four stable top-level tabs with icons and accessibility identifiers:

1. **Grid** — default, full-bleed map.
2. **Briefs** — deterministic evidence-backed regional summaries.
3. **Monitor** — source health and anomaly evidence.
4. **Settings** — source selection, source matrix, alerts, permissions, privacy, and operational limits.

Every surface must render loading, loaded, offline-cache, failed/empty, and explicit demo states without crashes. `Demo data` must remain persistently visible whenever `store.isDemo` is true. Never call demo data live. Offline cached data must keep the failure message visible.

## Grid screen

- Full-bleed `MKMapView` wrapped with `UIViewRepresentable`, using reusable `MKAnnotationView` subclasses and real `MKClusterAnnotation` clustering. Do not fake clusters in SwiftUI.
- Start with a useful Australia-wide demo viewport and frame loaded annotations efficiently. Do not continually reset the camera after the user pans.
- Custom price markers show the selected price in cents per litre, a non-colour movement cue (`↓`, `=`, `↑`, or `–`), and a colour band from `store.relativeBand(for:)`. Marker accessibility labels must say the station, price with units, movement, and relative band.
- Cluster markers show count and a compact grid motif. Selecting a station writes `store.selectedStation`; selection presents the detail sheet. Selecting a cluster zooms in.
- Compact top status block: ServoGrid wordmark, trust label, source name, record count, and refresh action/progress. Keep it map-readable, not a giant card.
- Horizontal fuel-grade selector from `FuelGrade.allCases`; call `await store.select(grade:day:)`. Use full readable labels or accessible labels, not unexplained abbreviations alone.
- Today/tomorrow segmented control only when relevant; tomorrow must be visibly scheduled, not live. Disable or explain unsupported states.
- User-location button calls `location.requestNearbyLocation()` only after tapping. Show denial/error copy without blocking manual exploration.
- Clear empty/error action and an honest offline-cache strip.

## Station detail sheet

- Medium and large detents, visible drag indicator, navigation title, and a prominent selected-grade price.
- Show price movement, relative band, freshness, price validity, restrictions when present, address, and brand.
- A timeline/evidence section must separately label `Price effective`, `Dataset published`, `First observed`, and `Last checked`. Missing source times say `Not supplied`; do not substitute checked time.
- Show the trust label, source attribution, licence name, and a tappable source link.
- Apple Maps directions use a normal `MKMapItem` route action.
- Alert setup is an explicit user action. Offer a sensible threshold form, then call `store.enableAlert`. Explain that background refresh is best effort and local alerts are not continuous server monitoring.

## Briefs screen

- Render `store.briefs` as concise editorial cards with the generated sentence, region, grade, mean change, comparable sample size, generated time, and attribution.
- Include an evidence disclosure that shows the observation count/IDs without dumping unreadable raw JSON.
- If there is no qualifying brief, explicitly say that the evidence threshold was not met. Do not generate filler prose.

## Monitor screen

- Source health card from `store.sourceHealth`: operational/demo/degraded/unavailable state, last success, last check, record count, issue count, and message.
- List `store.monitorIssues`, grouped or clearly labelled by severity and code, with a non-colour icon/text cue. Empty state says checks passed; in demo mode, also states these are fixture checks.
- Include a compact explanation of what the monitor verifies: timestamps, price/coordinate plausibility, schema, empty feeds, and duplicates.

## Settings screen

- Source selector for explicit Demo and WA FuelWatch. Switching must call `store.switchSource(mode:adapter:seedSnapshot:)`; load the historical demo seed when switching back to Demo so Briefs remain evidence-backed.
- Display an Australia source-access matrix using existing `SourceCatalog` descriptors and honest status copy: WA public live/scheduled; NSW/TAS credentials/agreement required; VIC 24-hour delayed and approval required; QLD token/signup; SA registered publisher; NT third-party API/reuse unverified; ACT coverage unverified; national fixture demo only. Restricted rows link to their official source pages but are not selectable as live.
- Alert preference list with remove actions and a clear route to create an alert.
- Show `BackgroundRefreshService.limitation`, location/notification permission philosophy, no-account/no-analytics privacy, cache behavior, and an app/about section.

## App wiring

- Replace the placeholder `ServoGridApp` root with a production `AppEnvironment` and a root tab view.
- Start `await store.load()` once from the UI. Register best-effort background refresh in a lifecycle-safe place, schedule the next request without claiming it will run, and call `await store.refresh()` from the handler.
- Refresh when the app becomes active only when reasonable; do not cause loops or reset map interaction.
- Preserve compile-safe Swift 6 actor isolation.

## UI tests and identifiers

Implement deterministic UI tests using demo mode. At minimum cover:

- launch shows the Grid and persistent `Demo data` trust state;
- selecting a fuel grade updates the selected control;
- tapping a marker opens station detail and exposes source disclosure;
- Monitor navigation shows source health;
- Settings shows the honest source-access matrix;
- entering alert setup does not trigger notification authorization before the explicit enable action.

Add stable accessibility identifiers rather than relying on layout coordinates. Keep tests compatible with iOS 26.5 and iOS 27 simulators.

## Completion gate

Before stopping:

1. Run `xcodegen generate`.
2. Build the ServoGrid app for an available iPhone simulator with Xcode 27.
3. Run the unit tests and the UI tests you added.
4. Fix all errors introduced by your UI work.
5. Report the exact files changed and exact verification results. Do not commit; the parent agent will review and commit.
