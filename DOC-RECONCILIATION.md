# DOC-RECONCILIATION.md

This file was produced by the `/doc-truth-up` documentation-reconciliation pass, which treats
the code as read-only ground truth and edits only documentation so it reflects the repo's actual
current state. No code was changed and no builds or tests were executed. Its purpose is to give
any reviewer a traceable record of what was verified, what was corrected, and what could not be
confirmed from source alone.

This pass built on the prior reconciliation from 2026-05-30 (sha `1e39a67`). That run corrected
CLAUDE.md (Swift version, export tech) and README.md (Architecture type names, export description,
DBSCAN→temporal-spatial, MKTileOverlay→MapPolyline). This run verified those corrections held and
found two residual stale references in `docs/PORTFOLIO-DISPOSITION.md` that the prior pass missed.

---

## Per-Claim Findings

### 1. What it is

**Status:** `consistent`
**Evidence:** `GhostRoutes/App/GhostRoutesApp.swift`, `GhostRoutes/App/ContentView.swift`,
`GhostRoutes/Data/Parsers/TakeoutParser.swift`, `GhostRoutes/Features/Map/GhostMapView.swift`.
Entry point, tab structure, Takeout import, and ghost-map overlay all present and match the README
description. Core mission — privacy-first iOS location-history visualizer, all on-device — is
accurately stated across README.md, CLAUDE.md, and PORTFOLIO-DISPOSITION.md.

---

### 2. Current state

**Status:** `consistent`
**Evidence:** 9 test files confirmed in `GhostRoutesTests/` (TakeoutParserTests, GhostDetectorTests,
LocationStoreTests, VisitClustererTests, ImportPipelineTests, ChapterDetectorTests,
AnimationStateTests, DouglasPeuckerTests, MapViewModelTests). Count exceeds the "40+ tests" claim.
All four phases described in IMPLEMENTATION-ROADMAP.md have corresponding code (Phase 0-3 services
and views; Phase 4 App Store artefacts including `PrivacyInfo.xcprivacy`, `ExportOptions.plist`,
and `fastlane/`). CHANGELOG.md "Unreleased — Initial release" is accurate: no App Store submission
has been made yet. "v1.0.0 — App Store ready" means ready to submit, which is consistent with the
fastlane deliver scaffolding on main.

**Unverifiable sub-claim:** "0 warnings, clean build" — cannot confirm without `xcodebuild`.

---

### 3. Stack

**Status:** `consistent`
**Evidence:**
- `IPHONEOS_DEPLOYMENT_TARGET = 17.0` — `GhostRoutes.xcodeproj/project.pbxproj:589,676`
- `SWIFT_VERSION = 6` — `GhostRoutes.xcodeproj/project.pbxproj:598,684`
- GRDB pinned at 7.10.0 — `GhostRoutes.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- `actor LocationStore` — `GhostRoutes/Data/Database/LocationStore.swift`
- `actor GhostStore` — `GhostRoutes/Data/Database/GhostStore.swift`
- `actor GeocodeManager` — `GhostRoutes/Services/GeocodeManager.swift`
- `MapPolyline` in SwiftUI `Map` — `GhostRoutes/Features/Map/GhostMapView.swift:48`
- No `@Query` macros anywhere in `GhostRoutes/` — confirmed by full search
- No analytics SDKs — only GRDB in Package.resolved

All stack claims in README.md and CLAUDE.md match the code.

---

### 4. How to run

**Status:** `consistent`
**Evidence:** README.md:26-33 documents "Build and run in Xcode" as the only run path, which is
correct for this `.xcodeproj`-based iOS project. `Package.swift` does not exist at the repo root.
The README does not reference the Makefile.

---

### 5. Known risks / doc ↔ code contradictions

**Status:** `drifted` — fixed in `docs/PORTFOLIO-DISPOSITION.md`.

Two stale `@Query` and `MKTileOverlay` references survived the prior reconciliation pass because
they appeared in the "Current state in one paragraph" block and the Special concern table, not in
the two lines the prior pass targeted.

**a. "Current state" paragraph — stale SwiftUI data-loading and MapKit overlay claims**
File: `docs/PORTFOLIO-DISPOSITION.md` (approximately lines 64-67 before edit)

| Wrong claim | Evidence | Correction |
|---|---|---|
| `SwiftUI consumes these via @Query macros (iOS 17+)` | `GhostMapView.swift:5,106-114` — `@State private var viewModel = MapViewModel()` + `.task { await viewModel.loadData(...) }`; no `@Query` found anywhere in the codebase | `@State` view models loaded asynchronously via `.task` |
| `MapKit overlay uses a MKTileOverlay-style approach` | `GhostMapView.swift:48,64-65` — `MapPolyline(...)` inside SwiftUI `Map` with `onMapCameraChange` pruning | `MapPolyline` entries + `onMapCameraChange` pruning |

Before:
> SwiftUI consumes these via `@Query` macros (iOS 17+); the MapKit overlay uses a `MKTileOverlay`-style approach to redraw only the visible time slice, avoiding the all-polylines-at-once trap.

After:
> SwiftUI consumes these via `@State` view models loaded asynchronously via `.task`; the MapKit overlay uses `MapPolyline` entries inside a SwiftUI `Map` view, with `onMapCameraChange` pruning visible segments to avoid the all-overlays-at-once trap.

**b. Special concern table — iOS 17+ minimum reason**
File: `docs/PORTFOLIO-DISPOSITION.md` (approximately line 177 before edit)

Before:
> **iOS 17+ minimum (because `@Query`).** Confirm minimum-iOS target in xcodeproj matches the Swift 6 / `@Query` reality…

After:
> **iOS 17+ minimum (required for MapKit `MapPolyline` overlay support).** Confirm minimum-iOS target in xcodeproj matches the Swift 6 / MapKit reality…

Evidence: `@Query` not present in codebase; `MapPolyline` is the iOS 17+ dependency as stated in
CLAUDE.md ("iOS 17+ minimum — required for MapKit `MapPolyline` overlay support").

---

### 6. Next move

**Status:** `consistent`
**Evidence:** `docs/PORTFOLIO-DISPOSITION.md` correctly identifies the remaining operator-only
unblock steps: App Store Connect record creation, privacy nutrition labels, screenshots, and
`fastlane deliver` upload. No code stubs or TODO markers indicate incomplete functionality in the
v1.0 feature set. `ExportOptions.plist` and `fastlane/` scaffolding confirmed present on main.

---

## Contradictions for Manual Review

These are in files outside the editable set. A human should apply the corrections below.

| File | Location | What is wrong | Suggested fix |
|---|---|---|---|
| `Makefile` | Lines 1-14 | Defines `swift build`, `swift test`, `swift run` targets, which will not work for this iOS Xcode project (no root `Package.swift`; the project is `.xcodeproj`-based). README correctly says "Build and run in Xcode." | Remove the Makefile or replace its targets with `xcodebuild` equivalents |
| `IMPLEMENTATION-ROADMAP.md` | Line 336 (Dependencies block) | States GRDB "Up to Next Major, starting from 6.0.0" | Update to reflect pinned version 7.10.0 per `Package.resolved` |
| `IMPLEMENTATION-ROADMAP.md` | Lines 26-82 (File Structure) | Lists several files that do not exist: `Features/Map/OverlayRenderer.swift`, `Features/Chapters/ChaptersViewModel.swift`, `Features/Alerts/AlertsViewModel.swift`, `Features/Settings/ImportView.swift`, `Data/Parsers/HealthKitParser.swift`. Files present but unlisted: `PermissionManager.swift`, `ImportPipeline.swift`, `VisitClusterer.swift`, `DocumentPicker.swift`, `GhostAnnotationView.swift` | Either remove phantom entries or add `(deferred to v2)` notation; add missing files |
| `IMPLEMENTATION-ROADMAP.md` | Lines 500-518 (Testing Strategy) | Lists `GeocodeManagerTests.swift` as required; file does not exist. Actual suite: `VisitClustererTests`, `ChapterDetectorTests`, `AnimationStateTests`, `DouglasPeuckerTests`, `ImportPipelineTests`, `MapViewModelTests`, `LocationStoreTests` (plus `TakeoutParserTests`, `GhostDetectorTests`) | Update automated test list to match the 9 actual test files |

---

## Footer

**Timestamp:** 2026-06-02 19:29:29 PDT
**Branch:** `docs/truth-up-2026-06-02`
**HEAD sha reconciled against:** `6fc284b23032aedac97f6e5f85d8dbd474d4012e`
