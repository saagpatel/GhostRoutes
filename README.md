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
- **Export** — exports ghost and visit data for use in other tools
- **All on-device** — Google Takeout JSON parser runs locally; no data leaves the device

## Quick Start

### Prerequisites
- Xcode 16+
- iOS 17.0+ device or simulator

### Installation
```bash
git clone https://github.com/saagpatel/GhostRoutes
open GhostRoutes.xcodeproj
```

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

The Takeout importer streams the `Records.json` file in chunks, writing raw location points to GRDB in batches of 500. A `ClusteringEngine` actor then runs a DBSCAN-style clustering pass over the data, writing place records and visit events to separate tables. The `GhostDetector` queries rolling frequency windows directly in SQL and surfaces results to SwiftUI via `@Query` macros. The MapKit overlay redraws only the visible time slice using a `MKTileOverlay`-based approach to avoid loading all polyline data at once.

## License

MIT