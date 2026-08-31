# Evaluation

## Product metric

The primary user-centred metric is **trusted price decision time**: median seconds from launch until a person can identify a station for their chosen grade and correctly state whether the evidence is live, scheduled, delayed, cached, unavailable, or demo.

The study target is under 10 seconds with at least 90% trust-state accuracy, compared with a list-style baseline where source state is buried in detail. This repository defines the protocol but does not claim a participant study was run. Simulator journey success is engineering evidence, not a substitute for user measurement.

Suggested measurement protocol:

1. Randomly assign the baseline or ServoGrid to a participant.
2. Ask them to find a station for a named grade and say both the price and trust state.
3. Stop timing when both are stated; score the trust classification separately.
4. Rotate live, scheduled, delayed, cached, unavailable, and demo scenarios.
5. Report median time, trust accuracy, sample size, device, and accessibility settings.

## Deterministic evaluation suite

`EvaluationSuiteTests` contains ten standard local-price classification cases plus one difficult mixed-evidence case.

| Case group | Evidence | Expected outcome |
| --- | --- | --- |
| 1–4 | Prices 150–165 c/L within a six-station cohort | Low |
| 5–7 | Prices 170–185 c/L within the same cohort | Typical |
| 8–10 | Prices 190–200 c/L within the same cohort | High |
| Difficult | Just-checked 99.9 c/L record with no source-owned timestamp and only one peer | Freshness unknown and relative band insufficient data |

The difficult case is intentional: reachability and a cheap-looking number are not enough evidence to assert freshness or a local bargain.

## Automated coverage

The unit/integration suite has 27 tests covering:

- validated stations, prices, coordinates, provenance, and four independent clocks;
- fresh/stale/unknown evaluation without laundering `checkedAt` into price time;
- movement only for the same station, grade, and validity day;
- relative bands, brief sample thresholds, alert thresholds, and alert deduplication;
- impossible coordinates/prices, future/missing timestamps, schema drift, duplicates, and empty-feed monitoring;
- WA RSS parsing and request formation;
- FuelCheck credential failure before network access;
- fixture labelling, versioned atomic cache round trips, app-store transitions, and notification permission timing.

The seven UI journeys cover launch and persistent Demo data disclosure, grade selection, clustered-map station detail and source link, Monitor navigation, the national source-access matrix, permission-safe alert setup, and a full evidence screenshot journey across all four tabs.

## Reproduced result

On 30 August 2026, Xcode 27 built the iOS 17 deployment target and the app was exercised on iPhone 17 Pro simulator runtimes for iOS 26.5 and iOS 27.0. The 27 unit tests and the six original focused UI journeys passed on iOS 26.5; the complete seven-journey UI suite passed on iOS 27.0. On 31 August, GitHub Actions independently passed the full iOS 26 unit/UI job and the iOS 27 source-compatibility job. A development-signed build was then installed and launched on a network-connected physical iPhone 17 Pro running iOS 27; CoreDevice independently confirmed the installed app record and running process. Exact replay commands are in `docs/REPRODUCTION.md`.

Xcode emits an App Intents metadata “skipped” message for targets that do not link App Intents. That is expected because ServoGrid has no App Intent. The iOS simulator may also emit an Apple accessibility-runtime message; neither is an app assertion or test failure.
