# ServoGrid Design

## Product contract

ServoGrid is an iPhone-first, map-first view of Australian fuel prices. Its primary promise is visual speed and source honesty: a user can scan prices and movement immediately, while every observation exposes its jurisdictional source, effective time, publication time, check time, and trust state. ServoGrid never upgrades a reachable endpoint into a claim of fresh data.

The app is useful without an account, contains no analytics, and requests location or notification permission only after the user invokes the related feature. It targets iOS 17 and compiles with Xcode 27. Newer visual APIs must be availability-gated.

## Chosen architecture

ServoGrid uses a hybrid on-device architecture. Deterministic domain logic, data adapters, JSON caching, monitoring, briefs, alerts, and MapKit presentation run locally. Western Australia's public FuelWatch RSS endpoint is the initial live adapter because the government explicitly permits free app reuse with attribution. Jurisdictions requiring keys, registration, approval, or unverified reuse terms ship behind the same adapter protocol but remain unavailable until credentials and permission are configured. Checked-in fixtures are presentation and integration-test evidence only and are labelled `Demo data` throughout the UI.

A cloud aggregator was rejected because it would introduce hosting, secrets, costs, and a new operational trust boundary. A fixture-only implementation was rejected because it could not support the live product claim. An LLM dependency was rejected for briefs because price comparisons, freshness, and alert decisions must be reproducible.

## Modules and boundaries

- `Domain`: value types for station identity, fuel grade, source provenance, observation timing, availability, movement, relative price bands, and source health.
- `Intelligence`: pure calculators for freshness, price movement, local-relative colouring, monitor anomalies, regional summaries, alerts, and evidence-backed Grid Briefs.
- `Data`: a stable `FuelSourceAdapter` protocol, one adapter per jurisdiction, a network client, fixture loader, configuration/Keychain access, and a cache actor.
- `App`: an observable store that coordinates adapters, cache, selected fuel/day, filters, background refresh, location, and notification delivery.
- `Features`: map, station detail, market/briefs, Grid Monitor, and settings. Cursor CLI with `cursor-grok-4.6-high` owns these SwiftUI surfaces and their design system, consuming the tested interfaces rather than inventing pricing logic.

Each adapter returns normalized snapshots or a typed failure. The UI never parses provider payloads. Adapters cannot silently fall back from live data to fixtures; demo mode is an explicit repository selection and is visually persistent.

## Normalized data and time semantics

`FuelPriceObservation` preserves distinct clocks:

- `sourceEventAt`: when the price became effective at the source, if supplied.
- `sourceDatasetAt`: when the source dataset was published or produced, if supplied.
- `observedAt`: when ServoGrid first observed this exact record.
- `checkedAt`: when ServoGrid last checked the source, including checks that found no change.

It also stores the source identifier, source URL, licence/attribution, coverage mode (`live`, `scheduled`, `delayed`, `demo`, or `unavailable`), price in cents per litre, fuel grade, availability, optional restrictions, and tomorrow/today validity. Missing timestamps stay missing. Freshness is calculated from the strongest source-owned time available and the source-specific policy; `checkedAt` never masquerades as price recency.

Movement is derived only from comparable observations for the same normalized station, grade, and validity day. Relative colour is calculated against a sufficiently sized local cohort, with green/amber/red plus explicit text and arrow/equals symbols so meaning does not depend on colour.

## Source access decisions

| Jurisdiction | Runtime state in clean checkout | Reason |
| --- | --- | --- |
| WA FuelWatch | Live public RSS, today/tomorrow where published | Free reuse is explicitly allowed with FuelWatch attribution and link; feed returns bounded regional results. |
| NSW FuelCheck | Configurable, unavailable by default | V2 covers NSW and Tasmania but production use is authenticated and agreement/rate-limit based. Credentials belong in Keychain or an ignored xcconfig. |
| Tasmania FuelCheck | Configurable, unavailable by default | Same authenticated V2 contract as NSW. |
| ACT | Unavailable/demo | ACT consumer coverage through FuelCheck is not established by the public API documentation; do not infer it. |
| Queensland | Unavailable/demo | Current prices require data-consumer signup/token. Historical annual CSV resources may support research but are not live. |
| South Australia | Unavailable/demo | Current data is available to registered publishers under publisher terms. |
| Victoria Servo Saver | Delayed/unavailable, adapter complete | Free application is required and public output is explicitly delayed by 24 hours. It must never be labelled live. |
| Northern Territory MyFuel NT | Unavailable/demo | The consumer site is public and says prices are real-time, but a reproducible third-party API and current reuse terms were not verified. |

Authoritative references are recorded in `docs/DATA_SOURCES.md`. Network endpoints and keys are injected; no secret is committed.

## Map and interaction design

The launch view is a full-bleed Australian MapKit map with a compact ServoGrid status header, a horizontal fuel selector, today/tomorrow control when relevant, and price annotations. UIKit-backed `MKMapView` provides real clustering and reusable annotations. Each annotation shows cents per litre, movement, and local-relative band. Selecting it opens a station sheet with all grades, timestamps, trust labels, restrictions, source attribution, history, and Apple Maps directions.

Four stable top-level destinations keep the app map-first: Grid, Briefs, Monitor, and Settings. Grid remains the default and largest visual surface. Demo mode has an unmissable but non-obstructive badge. Loading, empty, offline-cache, stale, source-error, and permission-denied states have distinct copy and actions.

The identity uses a deep graphite/navy canvas, electric teal live signal, amber scheduled/delayed signal, and coral anomaly signal. Typography uses Dynamic Type-capable system faces. Controls meet 44-point targets, VoiceOver labels include price units and movement, and all information has a non-colour cue. Dark and light schemes are both first-class.

## Persistence, refresh, and notifications

The cache is a versioned JSON envelope in Application Support written atomically by an actor. It retains normalized stations plus bounded price history for movement and summaries. Source refresh is user-initiated on foreground entry and through best-effort `BGAppRefreshTask`; iOS decides whether background work runs, so ServoGrid cannot promise continuous monitoring while closed.

Alert preferences support area, station, grade, price drop/spike threshold, tomorrow publication, and source outage/staleness. The deterministic alert engine evaluates new snapshots against the prior cache, deduplicates events, then asks `UNUserNotificationCenter` to schedule local notifications. Permission is requested only when the user enables an alert. Without a server and remote push, alerts may arrive only after iOS grants the app background or foreground execution; this limitation is shown in Settings and README.

## Monitoring and briefs

Grid Monitor checks missing or future timestamps, stale snapshots, impossible coordinates/prices, unsupported schema versions, duplicate station identities/proximity, empty feeds, and abrupt source-wide dropouts. A source health card reports last success, last check, latency when known, record count, and anomaly count.

Grid Briefs are pure, evidence-backed sentences generated only when cohort and comparison thresholds are met. Every brief stores its underlying observations, geographic label, fuel grade, comparison window, sample size, and source attributions. If evidence is weak, the engine returns no brief rather than filling the space with prose.

## Verification contract

The test suite covers normalization, all four clocks, freshness, relative price bands, movement, brief thresholds, alert thresholds/deduplication, monitor anomalies, WA RSS parsing, authenticated-adapter configuration failures, fixture labelling, cache round trips, and deterministic network stubs. UI tests cover launch into explicit demo mode, fuel selection, marker-to-station sheet, source disclosure, Monitor navigation, and permission-safe alert setup.

Delivery requires XcodeGen regeneration, formatting/static checks, unit/integration/UI tests, an iOS 26.5 or 27 simulator build and launch, screenshots, `git diff --check`, device discovery, and device install/launch only when a compatible unlocked device and signing identity are available.

## Hackathon measurement

The primary user-centred metric is **trusted price decision time**: median seconds from app launch until a user can identify a station for the selected grade and correctly state whether its price is live, scheduled, delayed, cached, or demo. The baseline is a list-style prototype with source state buried in detail. The target is under 10 seconds with at least 90% trust-state accuracy across the evaluation suite.

