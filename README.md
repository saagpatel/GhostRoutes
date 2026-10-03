# GhostRoutes

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> The places you used to go — and quietly stopped

GhostRoutes is a privacy-first iOS app that surfaces locations you've abandoned. Import your Google Location History and the app clusters your visits, measures peak vs. recent frequency, and marks places where activity has dropped significantly as "ghosts" on a map. Everything runs on-device — no backend, no cloud sync.

## Features

- **Ghost detection** — clusters location history into visited places, compares peak vs. recent visit frequency, surfaces locations below a configurable drift threshold
- **Route visualization** — renders your full movement history as polylines on MapKit, with ghost-adjacent segments highlighted
- **Life chapters** — detects periods of geographic shift by tracking 30-day centroid windows, flagging moves greater than 2 km
- **Period comparison** — overlays two date ranges in contrasting colors (cyan vs. amber) to compare movement patterns
- **Ghost inbox** — triage panel for dismissed and surfaced ghost alerts
- **Export** — renders a static PNG snapshot of the ghost map via the share sheet
- **All on-device** — Google Takeout JSON parser runs locally; no data leaves the device

## Quick Start

### Prerequisites
- macOS with full Xcode 16+ selected as the active developer directory (Command Line Tools alone cannot build iOS)
- XcodeGen on PATH (`brew install xcodegen` if it is not installed)
- An available iOS 17.0+ simulator; a device is only needed for device-specific checks

### Installation
```bash
git clone https://github.com/saagpatel/GhostRoutes
cd GhostRoutes
xcodegen generate
open GhostRoutes.xcodeproj
```

From this repository root, `make build` and `make test` generate the project and
run unsigned iOS Simulator build/tests. `make test` selects the first available
iPhone simulator and fails if none exists. Swift package resolution may download
GRDB; no location-history import is required for these fixture tests.

For a focused suite, generate the project and use an available simulator UUID:

```sh
make generate
xcrun simctl list devices available
# Replace SIMULATOR_UUID with an available iPhone simulator from the list.
xcodebuild test -project GhostRoutes.xcodeproj -scheme GhostRoutes \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -only-testing:GhostRoutesTests/GhostDetectorTests CODE_SIGNING_ALLOWED=NO
```

CI additionally builds the Release simulator configuration and runs `plutil -lint`
on `GhostRoutes/Resources/PrivacyInfo.xcprivacy` and `ExportOptions.plist`.
No separate Swift lint/formatter command is configured. Archive/App Store export
Makefile targets require signing/provisioning and are not local verification.
For changed map/import/export UI, inspect the affected flow in a disposable
simulator using `GhostRoutesTests/Fixtures` or synthetic visits, rather than personal
Takeout data. A browser cannot validate this native SwiftUI flow.

### Usage
Build and run. On first launch, tap **Import** to load a Google Takeout `Records.json` file. Location permission is requested for ongoing `CLVisit` monitoring.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI + MapKit |
| Persistence | GRDB (SQLite) |
| Concurrency | Swift structured concurrency |
| Import | Google Takeout JSON parser |

## Architecture

The Takeout importer streams the `Records.json` file in chunks, writing raw location points to GRDB in batches of 500. A `VisitClusterer` struct then runs a temporal-spatial sweep, grouping records within 50 m and 30-minute gaps into `Visit` records. The `GhostDetector` computes rolling frequency windows across these visits and surfaces results via `MapViewModel`. The MapKit layer renders overlays as `MapPolyline` entries inside a SwiftUI `Map`; an `onMapCameraChange` callback prunes which segments are live to avoid rendering the full dataset at once.

## License

MIT
