# DOC-RECONCILIATION.md

This file was produced by the `/doc-truth-up` documentation-reconciliation pass, which treats
the code as read-only ground truth and edits only documentation so it reflects the repo's actual
current state. No code was changed and no builds or tests were executed. Its purpose is to give
any reviewer a traceable record of what was verified, what was corrected, and what could not be
confirmed from source alone.

---

## Per-Claim Findings

### 1. What it is

**Status:** `consistent`
**Evidence:** `GhostRoutes/App/GhostRoutesApp.swift:3`, `GhostRoutes/App/ContentView.swift`,
`GhostRoutes/Data/Parsers/TakeoutParser.swift`, `GhostRoutes/Features/Map/GhostMapView.swift`.
Entry point, tab structure, Takeout import, ghost-map overlay all present and match the README
description. Core mission — privacy-first iOS location-history visualizer — accurately stated.

---

### 2. Current state

**Status:** `consistent`
**Evidence:** 9 test files confirmed in `GhostRoutesTests/`; @Test functions counted = 47
(TakeoutParserTests×8, GhostDetectorTests×7, LocationStoreTests×5, VisitClustererTests×6,
ImportPipelineTests×2, ChapterDetectorTests×5, AnimationStateTests×5, DouglasPeuckerTests×4,
MapViewModelTests×5). "40+ tests, 0 warnings, clean build" claim is consistent with what can be
read — 47 tests found; 0 warnings cannot be confirmed without building (marked unverifiable for
that sub-claim). All four phases described in IMPLEMENTATION-ROADMAP.md have corresponding code
(Phase 0-3 services and views, Phase 4 App Store artefacts including `PrivacyInfo.xcprivacy`,
`ExportOptions.plist`, and `fastlane/`). "v1.0.0 — App Store ready" is consistent with code.

**Unverifiable sub-claim:** "0 warnings, clean build" — cannot confirm without `xcodebuild`.

---

### 3. Stack

**Status:** `drifted` — fixed.

**Evidence:**

| Claim | File:Line | Before | After |
|---|---|---|---|
| Swift version | `GhostRoutes.xcodeproj/project.pbxproj:598,684` | `Swift 5.9+` | `Swift 6` |
| Swift version | `CLAUDE.md:7` (and Portfolio Context repeat at line 63) | `Swift 5.9+` | `Swift 6` |
| Image export tech | `GhostRoutes/Services/ExportService.swift:1-98` | `` `ImageRenderer` (SwiftUI, iOS 16+) `` | `` `MKMapSnapshotter` + `UIGraphicsImageRenderer` (Core Graphics composite, iOS 17+) `` |
| Image export tech | `CLAUDE.md:12` (and Portfolio Context repeat at line 67) | same as above | same correction |

**What changed (CLAUDE.md):**
- `Swift 5.9+` → `Swift 6` (two occurrences — main section and Portfolio Context block)
- `` `ImageRenderer` (SwiftUI, iOS 16+) `` → `` `MKMapSnapshotter` + `UIGraphicsImageRenderer` (Core Graphics composite, iOS 17+) `` (two occurrences)

`ExportService.swift` uses `MKMapSnapshotter.start()` to capture a map tile image, then composites
polylines and ghost circles via `UIGraphicsImageRenderer` / Core Graphics — not SwiftUI's
`ImageRenderer`. `SWIFT_VERSION = 6` is in both build configurations in `project.pbxproj`.

**Consistent sub-claims:**
- GRDB SQLite — `Package.resolved` pins GRDB at `7.10.0` ✓ (CLAUDE.md says "GRDB.swift 7.x")
- `actor` for database access — `actor LocationStore` (`LocationStore.swift:5`), `actor GhostStore`
  (`GhostStore.swift:5`), `actor GeocodeManager` (`GeocodeManager.swift:5`) ✓
- MapKit SwiftUI `Map` view with `MapPolyline` overlays ✓
- UserNotifications framework (`AlertsManager.swift`) ✓
- No third-party analytics/Firebase/Mixpanel — only GRDB in `Package.resolved` ✓

---

### 4. How to run

**Status:** `consistent`
**Evidence:** `README.md:26-33`. Build-and-run via Xcode is the only documented command; the
project has no `Package.swift` and `swift build` in the Makefile would not work for this iOS
Xcode project, but the README does not reference the Makefile and the Xcode-based instructions
are accurate.

---

### 5. Known risks / doc ↔ code contradictions

**Status:** `drifted` — fixed in `README.md` and `docs/PORTFOLIO-DISPOSITION.md`.

**a. Architecture section — three wrong type/API claims (README.md:46)**

| Wrong claim | Evidence | Correction |
|---|---|---|
| `` `ClusteringEngine` actor `` | `GhostRoutes/Services/VisitClusterer.swift:4` — `` struct VisitClusterer `` | `` `VisitClusterer` struct `` |
| `DBSCAN-style clustering pass` | `VisitClusterer.swift:8-55` — sequential temporal-spatial sweep (50 m radius + 30-min gap), not density-based | `temporal-spatial sweep` |
| `@Query macros` | `GhostRoutes/Features/Map/GhostMapView.swift:108-114` — data loaded via `viewModel.loadData(locationStore:ghostStore:)` | removed |
| `` `MKTileOverlay`-based approach `` | `GhostMapView.swift:47-66` — uses `MapPolyline` in SwiftUI `Map`; camera change callback prunes segments | `MapPolyline` + `onMapCameraChange` |

**b. Export feature description (README.md:16)**

Before: `exports ghost and visit data for use in other tools`
After: `renders a static PNG snapshot of the ghost map via the share sheet`

Evidence: `ExportService.swift` produces a `UIImage` (PNG) via `MKMapSnapshotter` +
`UIGraphicsImageRenderer`; there is no raw data export path.

**c. `ClusteringEngine` reference in PORTFOLIO-DISPOSITION (docs/PORTFOLIO-DISPOSITION.md:60-61)**

Before: `` A `ClusteringEngine` actor runs a DBSCAN-style pass ``
After: `` A `VisitClusterer` struct runs a temporal-spatial sweep ``

**d. Tech distinguisher row (docs/PORTFOLIO-DISPOSITION.md:236)**

Before: `DBSCAN clustering + MKTileOverlay time-slice + Swift 6 strict concurrency + @Query macros (iOS 17+)`
After: `temporal-spatial clustering + MapPolyline viewport gating + Swift 6 strict concurrency (iOS 17+)`

---

### 6. Next move

**Status:** `consistent`
**Evidence:** `docs/PORTFOLIO-DISPOSITION.md` describes the remaining unblock steps (App Store
Connect record, privacy nutrition labels, screenshots, `fastlane deliver` upload, submit for
review). These are all operator-only actions. No code stubs or TODO markers indicate
incomplete functionality in the shipped feature set.

---

## Contradictions for Manual Review

These are in files outside the editable set (`IMPLEMENTATION-ROADMAP.md`). A human should apply
the corrections below.

| File | Location | What is wrong | Suggested fix |
|---|---|---|---|
| `IMPLEMENTATION-ROADMAP.md` | Line 336 (Dependencies block) | States GRDB "Up to Next Major, starting from 6.0.0" | Update to reflect pinned version 7.10.0 per `Package.resolved` |
| `IMPLEMENTATION-ROADMAP.md` | Lines 26-82 (File Structure) | Lists several files that do not exist in the actual codebase: `Features/Map/OverlayRenderer.swift`, `Features/Chapters/ChaptersViewModel.swift`, `Features/Alerts/AlertsViewModel.swift`, `Features/Settings/ImportView.swift`, `Data/Parsers/HealthKitParser.swift` | Either remove these entries or add `(deferred to v2)` notation; note that `PermissionManager.swift`, `ImportPipeline.swift`, `VisitClusterer.swift`, `DocumentPicker.swift`, and `GhostAnnotationView.swift` exist in the codebase but are not listed |
| `IMPLEMENTATION-ROADMAP.md` | Lines 500-518 (Testing Strategy) | Lists `GeocodeManagerTests.swift` as a required test file; this file does not exist. The actual test suite has 9 files with different names (e.g., `VisitClustererTests`, `ChapterDetectorTests`, `AnimationStateTests`, `DouglasPeuckerTests`, `ImportPipelineTests`, `MapViewModelTests`, `LocationStoreTests`) | Update the automated test list to match the 9 actual test files |

---

## Footer

**Timestamp:** 2026-05-30 20:37:30 PDT
**Branch:** `docs/truth-up-2026-05-30`
**HEAD sha reconciled against:** `1e39a67ec302de2fd221aeba088c0084fbbd4983`
