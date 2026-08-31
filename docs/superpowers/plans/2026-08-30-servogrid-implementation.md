# ServoGrid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a polished native ServoGrid iPhone app that maps trustworthy Australian fuel-price evidence, monitors source health, and fails closed where access is unavailable.

**Architecture:** Pure Swift domain/intelligence modules sit behind jurisdiction adapters and a versioned local cache. A single observable app store coordinates sources and services. Cursor CLI using `cursor-grok-4.6-high` implements the SwiftUI/MapKit visual layer against those tested contracts; Codex reviews and verifies the integrated result.

**Tech Stack:** Swift 6, SwiftUI, MapKit, CoreLocation, UserNotifications, BackgroundTasks, URLSession, XCTest/XCUITest, XcodeGen, iOS 17+

**Spec:** `docs/superpowers/specs/2026-08-30-servogrid-design.md`

## Global Constraints

- Target iOS 17.0; gate iOS 26/27 presentation APIs with availability checks.
- Never convert `checkedAt` into source freshness or claim fixtures are live.
- Secrets use Keychain or ignored `Secrets.xcconfig`; no committed credential values.
- Cursor UI model is exactly `cursor-grok-4.6-high`, not a fast variant.
- No server, analytics, tracking, account registration, paid service, or access-control bypass.
- `project.yml` is the Xcode project source of truth.

---

### Task 1: Project shell and deterministic domain core

**Files:**
- Create: `project.yml`, `ServoGrid/App/ServoGridApp.swift`, `ServoGrid/Domain/*.swift`
- Test: `ServoGridTests/DomainTests.swift`

**Interfaces:**
- Produces: `FuelGrade`, `Jurisdiction`, `SourceDescriptor`, `ObservationTimes`, `FuelPriceObservation`, `FuelStation`, `FuelSnapshot`, `CoverageMode`.

- [x] Write domain tests with literal observations covering valid normalization, distinct source clocks, invalid prices, invalid coordinates, and explicit demo state.
- [x] Generate the project and run the focused suite; verify red failures are caused by missing production types.
- [x] Implement small Codable/Sendable value types and validation without UI dependencies.
- [x] Run focused and full unit tests, then commit the independently testable domain slice.

### Task 2: Price intelligence and Grid Monitor

**Files:**
- Create: `ServoGrid/Intelligence/FreshnessEvaluator.swift`, `PriceMovementCalculator.swift`, `RelativePriceClassifier.swift`, `GridMonitor.swift`, `GridBriefEngine.swift`, `AlertEngine.swift`
- Test: `ServoGridTests/IntelligenceTests.swift`, `ServoGridTests/EvaluationSuiteTests.swift`

**Interfaces:**
- Consumes: normalized snapshots from Task 1.
- Produces: `FreshnessState`, `PriceMovement`, `RelativePriceBand`, `MonitorIssue`, `GridBrief`, and `AlertEvent` through pure static functions.

- [x] Write table-driven failing tests for fresh/stale/unknown, up/down/steady, local bands, missing/future timestamps, impossible values, schema drift, duplicates, brief evidence thresholds, and alert deduplication.
- [x] Run the focused tests and confirm each behavior fails for the intended missing branch.
- [x] Implement the calculators with source-owned time and hand-checkable percentile/threshold rules.
- [x] Add 10 evaluation cases plus one difficult mixed-source/stale-data case; run all tests and commit.

### Task 3: Data adapters, configuration, fixtures, and cache

**Files:**
- Create: `ServoGrid/Data/FuelSourceAdapter.swift`, `NetworkClient.swift`, `WA/FuelWatchAdapter.swift`, `FuelCheck/FuelCheckAdapter.swift`, jurisdiction adapters, `FixtureAdapter.swift`, `SnapshotCache.swift`, `CredentialStore.swift`
- Create: `ServoGrid/Resources/Fixtures/*.json`
- Test: `ServoGridTests/AdapterTests.swift`, `ServoGridTests/CacheTests.swift`

**Interfaces:**
- Produces: `FuelSourceAdapter.fetch(grade:day:) async throws -> FuelSnapshot`, typed `SourceFailure`, and `SnapshotCache.load/save`.

- [x] Write failing parser/adapter tests using complete XML/JSON URLProtocol fixtures and explicit missing-credential assertions.
- [x] Implement FuelWatch RSS parsing and bounded WA regional requests; preserve source date separately from check time.
- [x] Implement authenticated/configured adapter contracts for NSW/TAS, QLD, SA, delayed VIC, NT, and ACT with fail-closed default states.
- [x] Add realistic, clearly demo-labelled fixtures and versioned atomic cache round-trip tests; run and commit.

### Task 4: App orchestration, location, alerts, and background work

**Files:**
- Create: `ServoGrid/App/AppStore.swift`, `AppEnvironment.swift`, `Services/LocationService.swift`, `NotificationService.swift`, `BackgroundRefreshService.swift`
- Test: `ServoGridTests/AppStoreTests.swift`, `ServoGridTests/NotificationFlowTests.swift`

**Interfaces:**
- Produces observable state: stations, selected grade/day, loading/error/offline/demo status, source health, briefs, alert preferences, and selected station.

- [x] Write failing state-transition tests with actor-safe deterministic source doubles.
- [x] Implement cache-first startup, explicit demo/live repositories, refresh merging, source health, and no silent fallback.
- [x] Implement in-context location/notification permission calls and deterministic local-alert scheduling.
- [x] Register best-effort background refresh with honest unavailable/denied states; run and commit.

### Task 5: Cursor-owned visual experience

**Files:**
- Create/modify: `ServoGrid/DesignSystem/*.swift`, `ServoGrid/Features/**/*.swift`, app composition and UI-test identifiers.
- Test: `ServoGridUITests/CoreFlowUITests.swift`

**Interfaces:**
- Consumes only Task 1-4 public interfaces; UI must not parse provider payloads or decide freshness/price math.

- [x] Invoke Cursor Agent from the repository root with `agent -p --force --trust --model cursor-grok-4.6-high`, the written spec, public interface inventory, and explicit ownership of SwiftUI/MapKit files.
- [x] Require full-bleed clustered map, grade/day controls, annotated price/movement/trust, detail sheet, Briefs, Monitor, Settings, accessibility, dark/light mode, permission context, empty/error/offline/stale/demo states, and deterministic launch arguments.
- [x] Review Cursor's diff for contract violations, invented facts, secret values, deployment-target drift, giant files, and inaccessible colour-only cues; correct integration defects.
- [x] Build and run focused UI tests before committing the independently reviewable presentation slice.

### Task 6: Brand assets and hackathon evidence

**Files:**
- Create: `ServoGrid/Resources/Assets.xcassets`, `README.md`, `docs/DATA_SOURCES.md`, `docs/IMPROVEMENT_CHANGELOG.md`, `docs/EVALUATION.md`, `docs/DEMO_SCRIPT.md`, `docs/TRAJECTORIES.md`, `docs/REPRODUCTION.md`, `PRIVACY.md`, `LICENSES.md`

- [x] Generate a distinct ServoGrid app icon, inspect it, produce required asset sizes, and verify the asset catalogue compiles.
- [x] Document user, bottleneck, source table and terms, setup, exact commands, privacy, background limits, baseline-to-final iterations, primary metric, 11-case evaluation, difficult case, trajectory export, and under-five-minute demo.
- [x] Audit all claims against implemented behavior and current official source evidence; remove or qualify anything not reproduced.
- [x] Run doc/link/source probes that are safe and record time-sensitive results without embedding secrets; commit.

### Task 7: End-to-end release proof

**Files:**
- Modify only files needed to fix verified failures.
- Create: `Artifacts/screenshots/*.png` when simulator capture succeeds.

- [x] Regenerate with XcodeGen, format/lint Swift, compile with strict warnings, run all unit/integration tests, then run XCUITests on an available iPhone simulator.
- [x] Boot, install, and launch ServoGrid; verify process and capture Grid, station detail, Briefs, Monitor, and Settings screenshots.
- [x] Discover physical devices and signing identities. Install, launch, and verify the running process only if a compatible unlocked device and signing are available; otherwise record the exact blocker.
- [x] Run secret scan, `git diff --check`, project consistency checks, and a final requirement-by-requirement audit.
- [x] Create focused final commits and verify a clean working tree.
