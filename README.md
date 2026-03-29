![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)
![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue?logo=apple)
![Xcode](https://img.shields.io/badge/Xcode-16%2B-blue?logo=xcode)
![License](https://img.shields.io/badge/license-MIT-green)

# GhostRoutes

GhostRoutes is an iOS app that surfaces the places you used to go but quietly stopped visiting. Import your Google Location History, and the app identifies "ghost locations" — spots where your visit frequency has dropped significantly from its historical peak — and plots them on a map alongside your movement routes.

## What it does

- **Ghost detection** — Clusters your location history into visited places, measures peak vs. recent visit frequency, and surfaces locations where activity has fallen below a configurable threshold.
- **Map visualization** — Renders your full movement history as route polylines, with ghost-adjacent segments highlighted so you can see where the drift happened.
- **Life chapters** — Detects periods of significant geographic shift (e.g., moving cities) by tracking 30-day centroid windows and flagging transitions where the centroid moves more than 2 km.
- **Period comparison** — Overlays two user-selected date ranges on a single map in contrasting colors (cyan vs. amber) to compare how your movement patterns changed over time.
- **Ghost inbox** — Collects dismissed and surfaced ghost alerts for triage.
- **Export** — Exports ghost and visit data for use outside the app.

## Tech stack

| Layer | Technology |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI + MapKit |
| Persistence | GRDB (SQLite) |
| Concurrency | Swift structured concurrency (`async`/`await`, `Task.detached`) |
| Location import | Google Takeout JSON parser |
| Geocoding | CoreLocation reverse geocoding |
| Geometry | Douglas-Peucker polyline simplification, Haversine distance |

## Prerequisites

- Xcode 16 or later
- iOS 17.0+ device or simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — used to generate the `.xcodeproj` from `project.yml`

## Getting started

```bash
# Install XcodeGen if needed
brew install xcodegen

# Clone the repo
git clone https://github.com/<your-username>/GhostRoutes.git
cd GhostRoutes

# Generate the Xcode project
xcodegen generate

# Open in Xcode
open GhostRoutes.xcodeproj
```

Build and run on a simulator or device running iOS 17+. On first launch, tap **Import** and select a `Records.json` file exported from [Google Takeout](https://takeout.google.com) (choose Location History → JSON format).

## Project structure

```
GhostRoutes/
├── App/                  Entry point and root ContentView
├── Data/
│   ├── Database/         GRDB schema, LocationStore, GhostStore
│   ├── Models/           LocationRecord, Visit, GhostLocation, LifeChapter, PlaceCache
│   └── Parsers/          Google Takeout JSON parser
├── Features/
│   ├── Map/              Main map view + MapViewModel
│   ├── Chapters/         Life chapters timeline
│   ├── Compare/          Two-period route comparison
│   ├── Alerts/           Ghost inbox
│   ├── Onboarding/       Import flow and document picker
│   └── Settings/         App settings
├── Services/
│   ├── GhostDetector     Core ghost scoring algorithm
│   ├── VisitClusterer    Grid-based visit clustering
│   ├── ChapterDetector   Geographic chapter boundary detection
│   ├── ImportPipeline    End-to-end import orchestration
│   ├── GeocodeManager    Reverse geocoding for ghost locations
│   └── ExportService     Data export
└── Utilities/
    ├── DouglasPeucker    Polyline simplification
    └── Haversine         Great-circle distance
GhostRoutesTests/         Unit tests for all core services
```

## Screenshot

> _Screenshot placeholder — run on device and add here._

## License

MIT — see [LICENSE](LICENSE).
