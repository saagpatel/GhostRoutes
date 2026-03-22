# Ghost Routes

## Overview
A privacy-first iOS app that ingests Apple CLVisit API data and Google Location History (Takeout) JSON to render a "ghost map" — a MapKit visualization contrasting current active routes (bright, solid) against abandoned places and patterns (translucent, fading). All processing is on-device. No backend. No accounts. Free App Store release.

## Tech Stack
- Language: Swift 5.9+ (structured concurrency — `async/await`, `actor`)
- UI: SwiftUI (iOS 17+ minimum — required for MapKit `MapPolyline` overlay support)
- Database: SQLite via GRDB.swift 7.x — type-safe ORM, WAL mode, Swift 6 strict concurrency
- Maps: MapKit (SwiftUI) — `Map` view with `MapPolyline` overlays
- Notifications: UserNotifications framework (local only, no push)
- Image Export: `ImageRenderer` (SwiftUI, iOS 16+)
- No third-party analytics, no Firebase, no Mixpanel

## Development Conventions
- SwiftUI-first; UIKit only where SwiftUI MapKit APIs are insufficient
- `actor` for all database access (`LocationStore`, `GhostStore`, `GeocodeManager`)
- `async/await` throughout — no completion handlers
- File naming: PascalCase for types/files, camelCase for properties
- Unit tests required for: `TakeoutParser`, `GhostDetector`, clustering algorithm — before any phase advances
- No network calls except `CLGeocoder` (Apple on-device, iOS 17+)

## Current Phase
**Phase 0: Foundation**
See IMPLEMENTATION-ROADMAP.md for full phase details, acceptance criteria, and verification checklists.

## Key Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Data sources | CLVisit (ongoing) + Google Takeout JSON import | Richest dataset; covers history + future accumulation |
| Monetization | Free, no IAP | Portfolio project; eliminates StoreKit complexity |
| Minimum ghost threshold | 90 days of location history | Below this, clustering produces false ghosts |
| Ghost detection ratio | current < 20% of peak frequency = ghost | 3-month rolling window; `GhostThresholds` constants are tunable |
| Place naming | CLGeocoder → locality fallback | Rate-limit safe at 1.1s queue intervals; no third-party APIs |
| Share format | Static PNG via `ShareLink` only | Video export deferred to v2 |
| App name | Ghost Routes | Locked — do not rename |
| iCloud backup | Excluded (`isExcludedFromBackup = true`) | Location data must never leave device |

## Do NOT
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
- Do not write location data to iCloud, CloudKit, or any network destination — ever
- Do not use `localStorage`, `UserDefaults`, or flat files for location data — SQLite via GRDB only
- Do not add third-party SDKs without explicit user approval (no Firebase, Amplitude, Sentry, etc.)
- Do not implement StoreKit or any IAP — this is a free app, permanently
- Do not reverse geocode in a tight loop — all CLGeocoder calls must go through `GeocodeManager` actor with 1.1s rate limiting
- Do not scaffold more than the current phase in one session — build phase by phase, verify before advancing
