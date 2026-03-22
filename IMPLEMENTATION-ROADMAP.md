# Ghost Routes — Implementation Roadmap

## Architecture

### System Overview
```
[Google Takeout JSON]  ──import──▶  [TakeoutParser]  ──▶  [LocationStore (SQLite)]
[CLVisit API]          ──stream──▶  [VisitManager]   ──▶  [LocationStore (SQLite)]
                                                                │
                                           ┌────────────────────┤
                                           │                    │
                                    [GhostDetector]    [GeocodeManager]
                                           │            (rate-limited actor)
                                    [GhostStore]       [PlaceCache (SQLite)]
                                           │
                         ┌─────────────────┼──────────────────┐
                         │                 │                  │
                   [MapViewModel]  [TimelineViewModel]  [AlertsManager]
                         │                 │
                   [GhostMapView]  [ComparisonView]
                   [AnimationView] [ChaptersView]
```

### File Structure
```
GhostRoutes/
├── GhostRoutesApp.swift                  # App entry point, environment setup
├── ContentView.swift                     # Root tab view (Map, Compare, Alerts, Settings)
│
├── Data/
│   ├── Models/
│   │   ├── LocationRecord.swift          # Raw location point (lat, lng, timestamp, source)
│   │   ├── Visit.swift                   # CLVisit-derived visit (place cluster + timestamps)
│   │   ├── GhostLocation.swift           # Detected ghost with ghostliness score
│   │   ├── LifeChapter.swift             # Auto-detected life chapter boundary
│   │   └── PlaceCache.swift              # Reverse geocoded place name + coordinates
│   ├── Database/
│   │   ├── AppDatabase.swift             # GRDB DatabasePool setup, migrations
│   │   ├── LocationStore.swift           # Actor: CRUD for LocationRecord + Visit
│   │   └── GhostStore.swift             # Actor: CRUD for GhostLocation + LifeChapter
│   └── Parsers/
│       ├── TakeoutParser.swift           # Parses Records.json (both v1 and v2 schemas)
│       └── HealthKitParser.swift         # (v2) Parses HKWorkoutRoute for GPS tracks
│
├── Services/
│   ├── VisitManager.swift                # CLLocationManager delegate, CLVisit handling
│   ├── GhostDetector.swift               # Core ghost detection algorithm
│   ├── GeocodeManager.swift              # Rate-limited CLGeocoder queue (actor, 1.1s delay)
│   ├── AlertsManager.swift               # UNUserNotificationCenter, ghost alert scheduling
│   ├── ChapterDetector.swift             # Life chapter boundary detection
│   └── ExportService.swift               # ImageRenderer → PNG → share sheet
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift          # First-launch flow (permissions, import CTA)
│   │   └── ImportProgressView.swift      # Progress bar + import summary
│   ├── Map/
│   │   ├── GhostMapView.swift            # Primary map with overlays
│   │   ├── MapViewModel.swift            # Overlay computation, zoom handling
│   │   ├── AnimationView.swift           # Chronological playback controls
│   │   └── OverlayRenderer.swift         # Active vs ghost polyline styling
│   ├── Compare/
│   │   ├── ComparisonView.swift          # Side-by-side period selector + split map
│   │   └── ComparisonViewModel.swift
│   ├── Chapters/
│   │   ├── ChaptersView.swift            # Life chapters scrubber + chapter map
│   │   └── ChaptersViewModel.swift
│   ├── Alerts/
│   │   ├── GhostInboxView.swift          # In-app ghost alert history
│   │   └── AlertsViewModel.swift
│   └── Settings/
│       ├── SettingsView.swift            # Mindful Mode, data management, thresholds
│       └── ImportView.swift              # Google Takeout import trigger + history
│
├── Resources/
│   ├── Assets.xcassets
│   └── PrivacyInfo.xcprivacy             # Required iOS 17 privacy manifest
│
└── Tests/
    ├── TakeoutParserTests.swift           # Unit tests with real Takeout fixture files
    ├── GhostDetectorTests.swift           # Algorithm tests with synthetic visit data
    └── GeocodeManagerTests.swift          # Rate limiting behavior tests
```

---

### Data Model

```sql
-- Raw location points ingested from Takeout or CLVisit
CREATE TABLE location_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    timestamp INTEGER NOT NULL,           -- Unix epoch seconds
    accuracy_meters REAL,
    source TEXT NOT NULL CHECK(source IN ('takeout', 'clvisit')),
    raw_json TEXT,                         -- Preserve original for debugging
    created_at INTEGER DEFAULT (strftime('%s', 'now'))
);
CREATE INDEX idx_location_timestamp ON location_records(timestamp);
CREATE INDEX idx_location_coords ON location_records(latitude, longitude);

-- Clustered place visits derived from location_records
CREATE TABLE visits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cluster_lat REAL NOT NULL,            -- Centroid of 50m cluster
    cluster_lng REAL NOT NULL,
    arrived_at INTEGER NOT NULL,          -- Unix epoch seconds
    departed_at INTEGER NOT NULL,
    duration_seconds INTEGER NOT NULL,
    source TEXT NOT NULL CHECK(source IN ('takeout', 'clvisit')),
    place_cache_id INTEGER REFERENCES place_cache(id)
);
CREATE INDEX idx_visits_cluster ON visits(cluster_lat, cluster_lng);
CREATE INDEX idx_visits_arrived ON visits(arrived_at);

-- Ghost locations detected by GhostDetector
CREATE TABLE ghost_locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    cluster_lat REAL NOT NULL,
    cluster_lng REAL NOT NULL,
    place_cache_id INTEGER REFERENCES place_cache(id),
    peak_visits_per_month REAL NOT NULL,
    current_visits_per_month REAL NOT NULL,
    ghostliness_score REAL NOT NULL,      -- (peak/current) × weeks_since_last_visit; higher = more haunted
    peak_period_start INTEGER NOT NULL,
    peak_period_end INTEGER NOT NULL,
    last_visit_at INTEGER NOT NULL,
    alert_sent_at INTEGER,                -- NULL = no alert sent yet
    is_dismissed INTEGER DEFAULT 0,
    detected_at INTEGER DEFAULT (strftime('%s', 'now'))
);
CREATE INDEX idx_ghost_score ON ghost_locations(ghostliness_score DESC);

-- Reverse geocode cache
CREATE TABLE place_cache (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    display_name TEXT NOT NULL,           -- "Blue Bottle Coffee" or "Mission District"
    locality TEXT,                        -- City/neighborhood fallback
    geocoded_at INTEGER NOT NULL,
    cache_key TEXT UNIQUE NOT NULL        -- "{lat_4dp}_{lng_4dp}" bucket key
);
CREATE UNIQUE INDEX idx_place_cache_key ON place_cache(cache_key);

-- Auto-detected life chapter boundaries
CREATE TABLE life_chapters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    starts_at INTEGER NOT NULL,
    ends_at INTEGER,                      -- NULL = current chapter
    label TEXT,                           -- User-editable label
    change_score REAL NOT NULL,           -- Magnitude of route pattern shift
    bounding_lat_min REAL,
    bounding_lat_max REAL,
    bounding_lng_min REAL,
    bounding_lng_max REAL
);
```

---

### Core Swift Type Definitions

```swift
// LocationRecord.swift
struct LocationRecord: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var accuracyMeters: Double?
    var source: DataSource
    var rawJson: String?

    enum DataSource: String, Codable {
        case takeout, clvisit
    }
}

// Visit.swift
struct Visit: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var clusterLat: Double
    var clusterLng: Double
    var arrivedAt: Date
    var departedAt: Date
    var durationSeconds: Int
    var source: LocationRecord.DataSource
    var placeCacheId: Int64?
}

// GhostLocation.swift
struct GhostLocation: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var clusterLat: Double
    var clusterLng: Double
    var placeCacheId: Int64?
    var peakVisitsPerMonth: Double
    var currentVisitsPerMonth: Double
    var ghostlinessScore: Double          // Higher = more haunted
    var peakPeriodStart: Date
    var peakPeriodEnd: Date
    var lastVisitAt: Date
    var alertSentAt: Date?
    var isDismissed: Bool
    var cachedDisplayName: String?        // Denormalized for map overlay performance
}

// LifeChapter.swift
struct LifeChapter: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var startsAt: Date
    var endsAt: Date?                     // nil = current chapter
    var label: String?                    // User-editable
    var changeScore: Double
    var boundingLatMin: Double?
    var boundingLatMax: Double?
    var boundingLngMin: Double?
    var boundingLngMax: Double?
}

// PlaceCache.swift
struct PlaceCache: Codable, FetchableRecord, PersistableRecord {
    var id: Int64?
    var latitude: Double
    var longitude: Double
    var displayName: String
    var locality: String?
    var geocodedAt: Date
    var cacheKey: String                  // "{lat_4dp}_{lng_4dp}"
}

// Ghost detection constants — tunable via GhostThresholds enum
enum GhostThresholds {
    static let minDaysOfHistory: Int = 90
    static let rollingWindowDays: Int = 90
    static let ghostThresholdRatio: Double = 0.20    // current < 20% of peak = ghost
    static let minPeakSustainedWeeks: Int = 4
    static let clusterRadiusMeters: Double = 50.0
    static let ghostlinessAlertThreshold: Double = 5.0
    static let alertCooldownDays: Int = 30
}

// TakeoutParser internal type — handles both JSON schemas
struct TakeoutLocation: Decodable {
    let latitudeE7: Int                   // Divide by 1e7 for degrees
    let longitudeE7: Int
    let timestamp: String?                // ISO 8601 (schema v2, 2022+)
    let timestampMs: String?              // Unix ms string (schema v1, pre-2022)
    let accuracy: Int?

    // Resolves either timestamp field to a Date
    var resolvedDate: Date? {
        if let ts = timestamp {
            return ISO8601DateFormatter().date(from: ts)
        } else if let ms = timestampMs, let epoch = Double(ms) {
            return Date(timeIntervalSince1970: epoch / 1000.0)
        }
        return nil
    }
}
```

---

### Google Takeout JSON Schemas

**Schema v2 (2022+) — file is `Records.json`:**
```json
{
  "locations": [
    {
      "latitudeE7": 377739390,
      "longitudeE7": -1224194190,
      "accuracy": 20,
      "timestamp": "2024-03-15T14:22:31.000Z"
    }
  ]
}
```

**Schema v1 (pre-2022) — file may be `LocationHistory.json`:**
```json
{
  "locations": [
    {
      "latitudeE7": 377739390,
      "longitudeE7": -1224194190,
      "accuracy": 20,
      "timestampMs": "1710512551000"
    }
  ]
}
```

**Schema detection:** Check first record for presence of `"timestamp"` key vs `"timestampMs"` key. Log detected schema version to console during import. Handle both in the same decoder by making both fields `Optional<String>` and resolving via `resolvedDate`.

---

### External APIs

| Service | Endpoint | Method | Auth | Rate Limit | Purpose |
|---------|----------|--------|------|------------|---------|
| CLGeocoder | On-device (Apple) | N/A | None (system) | ~1 req/sec; ~50/min | Reverse geocode ghost cluster centroids to place names |

No other external API calls. Zero network egress for location data.

### CLGeocoder Rate Limiting Implementation
All geocode calls must go through `GeocodeManager` actor:
```swift
actor GeocodeManager {
    private let geocoder = CLGeocoder()
    private let delaySeconds: Double = 1.1  // Safely under 1 req/sec limit

    func reversegeocode(latitude: Double, longitude: Double) async throws -> String {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        return placemarks.first?.name          // Specific venue
            ?? placemarks.first?.locality      // City/neighborhood fallback
            ?? "Near \(String(format: "%.4f", latitude))°N"
    }
}
```

---

### Dependencies

```bash
# GRDB.swift — SQLite ORM
# In Xcode: File → Add Package Dependencies
# URL: https://github.com/groue/GRDB.swift
# Version Rule: Up to Next Major, starting from 6.0.0

# All other dependencies are Apple system frameworks:
# MapKit, CoreLocation, UserNotifications, HealthKit (v2), SwiftUI
# No npm, no CocoaPods, no other SPM packages required
```

---

## Scope Boundaries

**In scope (v1):**
- Google Takeout JSON import (both schema versions)
- CLVisit API ongoing accumulation
- Ghost map visualization (active routes: bright solid; ghost routes: translucent fading)
- Ghost detection algorithm (90-day rolling window, 20% threshold, ghostliness scoring)
- Reverse geocoding with place name cache
- Chronological playback animation (45 seconds for typical dataset)
- Ghost alerts via local notifications (weekly scan, 30-day cooldown)
- Ghost Inbox (in-app alert history)
- Two-period time comparison view
- Life chapters detection + scrubber
- Static PNG export via share sheet
- Mindful Mode (30-day alert pause)
- One-tap delete all data in Settings
- Privacy manifest (`PrivacyInfo.xcprivacy`)

**Out of scope (never):**
- Any backend, server, or cloud sync
- iCloud or CloudKit integration
- Push notifications
- StoreKit / IAP / subscriptions
- Third-party analytics or crash reporting SDKs
- User accounts or authentication

**Deferred to v2:**
- Animated video export (ReplayKit)
- HealthKit workout route integration
- Ghost recommendations ("this place is still open")
- Collaborative ghost comparison with friends
- Apple Watch companion
- City-level aggregated foot traffic data

---

## Security & Credentials

- **No credentials exist.** No API keys, no tokens, no accounts.
- **Location data storage:** SQLite at `Application Support/GhostRoutes/` in the app sandbox. Set `isExcludedFromBackup = true` on this directory URL at first launch.
- **Encryption at rest:** Set `FileProtectionType.completeUnlessOpen` on the database file — encrypted when device is locked.
- **Network:** Zero location data egress. `CLGeocoder` in iOS 17+ resolves on-device where possible; any network call it makes is Apple's infrastructure, not ours.
- **Google Takeout JSON:** Parsed entirely in-memory. The original file is never copied into the app sandbox — only parsed `LocationRecord` structs are written to SQLite. User's copy of the file remains in their Files app / Downloads.
- **Delete all data:** Drops and recreates all 5 SQLite tables + cancels all pending `UNUserNotificationCenter` notifications. In `SettingsView`, show confirmation alert before executing. Post-delete, verify with `sqlite3` row count assertions in debug builds.

---

## Phase 0: Foundation (Week 1)

**Objective:** Xcode project scaffolded with GRDB, all 5 tables created via migrations, TakeoutParser handling both JSON schemas, GhostDetector algorithm implemented and unit tested. No UI built in this phase.

**Tasks:**
1. Create Xcode project `GhostRoutes`, iOS 17+ deployment target, SwiftUI lifecycle, Bundle ID `com.{yourname}.ghostroutes` — **Acceptance:** Project builds clean with 0 warnings on M4 Pro simulator (iPhone 15 Pro)
2. Add GRDB.swift 6.x via SPM (`https://github.com/groue/GRDB.swift`, Up to Next Major from 6.0.0) — **Acceptance:** `import GRDB` compiles without errors in `AppDatabase.swift`
3. Implement `AppDatabase.swift` with `DatabasePool` and all 5 table migrations (`location_records`, `visits`, `ghost_locations`, `place_cache`, `life_chapters`) — **Acceptance:** Run app on simulator, open Terminal: `sqlite3 ~/Library/Developer/CoreSimulator/Devices/{UUID}/data/Containers/Data/Application/{UUID}/Library/Application\ Support/GhostRoutes/db.sqlite ".tables"` → prints all 5 table names
4. Implement `LocationStore.swift` as an `actor` with insert/fetch methods for `LocationRecord` and `Visit` — **Acceptance:** Unit test inserts 100 `LocationRecord`s and reads them back; count matches; timestamps round-trip correctly
5. Add test fixture files to `Tests/`: `takeout_v1.json` (100 records, `timestampMs` schema) and `takeout_v2.json` (100 records, `timestamp` ISO schema) — **Acceptance:** Files committed; they are excerpts from a real Google Takeout export (not synthetic)
6. Implement `TakeoutParser.swift` with dual-schema detection and per-record error logging — **Acceptance:** `TakeoutParserTests` parses both fixture files; both produce exactly 100 `LocationRecord` structs; malformed record test (inject 1 bad record) produces 99 valid + 1 skipped logged to console
7. Implement `GhostDetector.swift` clustering (50m radius) + ghostliness scoring (rolling 90-day window, 20% peak ratio threshold) — **Acceptance:** `GhostDetectorTests` generates 6 months of synthetic visits to 10 locations, drops visit frequency to 0 on 3 of them for the final 60 days; detector returns exactly those 3 as ghosts, ranked by ghostliness score descending

**Verification checklist:**
- [ ] `xcodebuild test -scheme GhostRoutes` → all tests pass, 0 failures
- [ ] SQLite file exists at simulator app data path with 5 tables
- [ ] `TakeoutParser` handles 10MB JSON fixture in <5 seconds (add `XCTMeasure` block)
- [ ] `GhostDetector` identifies the 3 planted ghost locations in synthetic dataset

**Risks:**
- Takeout fixture files: pull your own Google Takeout export before writing any parser code. Go to [myaccount.google.com/data-and-privacy](https://myaccount.google.com/data-and-privacy) → Download your data → Location History (Timeline). Extract `Records.json`. Trim to 200 records for the test fixture. This is the most important pre-Phase-0 action.

---

## Phase 1: Import + Static Map (Weeks 2–3)

**Objective:** Full Takeout import flow with progress UI, ghost detection running end-to-end on real data, ghost map rendering in MapKit with correctly styled overlays.

**Tasks:**
1. Implement `ImportView.swift` — `UIDocumentPickerViewController` (wrapped in SwiftUI) for `.json` file selection, progress bar updating every 500 records, import summary sheet ("14,203 locations imported. 47 records skipped.") — **Acceptance:** Import your own Takeout JSON; progress bar animates; summary count is accurate; UI doesn't freeze during import
2. Wire full pipeline on background actor: `TakeoutParser` → `LocationStore` (insert `LocationRecord`s) → clustering → `GhostDetector` → `GhostStore` (insert `GhostLocation`s) — **Acceptance:** Pipeline completes without blocking main thread; Instruments → Time Profiler shows main thread idle during import; <30 seconds for 50MB file on device
3. Implement `GeocodeManager.swift` actor with 1.1s rate-limited queue and SQLite cache via `PlaceCache` — **Acceptance:** Insert 10 ghost locations, trigger geocoding; `os_log` timestamps show ≥1.1s between each CLGeocoder call; second run (cache hit) returns instantly with no CLGeocoder calls
4. Implement `GhostMapView.swift` using MapKit SwiftUI `Map` view — active routes: solid `Color(red: 0, green: 0.898, blue: 1.0)` (cyan `#00E5FF`) 3pt polylines; ghost routes: dashed white polylines at opacity `min(0.15 + ghostlinessScore * 0.05, 0.65)` — **Acceptance:** Map shows ≥5 ghost locations from your Takeout data with correct visual contrast between active and ghost styles
5. Implement zoom-level overlay simplification in `MapViewModel` — cap rendered overlays at 500 per zoom tile using Douglas-Peucker simplification — **Acceptance:** Instruments → Core Animation → map scroll/pinch-zoom on 20,000-point dataset sustains 60fps on iPhone 14 simulator
6. Implement `OnboardingView.swift` — `CLLocationManager` permission request (`Always`), notification permission request, Takeout import CTA, data threshold progress bar (show "X of 90 days accumulated" if below threshold) — **Acceptance:** Fresh app install on simulator → onboarding appears → tapping "Allow Location" triggers iOS permission dialog → below-threshold state shows progress bar with correct day count

**Verification checklist:**
- [ ] Import your own full Takeout export → ghost map populates with ≥3 ghost locations within 60 seconds of import completing
- [ ] Tap a ghost polyline → callout shows geocoded place name (or locality fallback)
- [ ] Instruments → Core Animation: map interaction at 60fps sustained
- [ ] Charles Proxy open during entire import + map render flow → zero outbound network calls to non-Apple domains

**Risks:**
- MapKit polyline performance fallback: if 60fps isn't achievable with live `MapPolyline` overlays, switch ghost routes to a pre-rendered `MKMapSnapshotter` image composited as a `UIImage` layer below the live map. Loses tap-to-callout interactivity but guarantees performance. Decide at Phase 1 completion based on Instruments data.

---

## Phase 2: CLVisit + Animation + Share (Weeks 4–5)

**Objective:** CLVisit data flowing into LocationStore continuously, chronological playback animation working at 60fps, PNG share export working.

**Tasks:**
1. Implement `VisitManager.swift` — `CLLocationManager` configured with `startMonitoringSignificantLocationChanges()` + `startMonitoringVisits()`; `CLVisit` events written to `LocationStore` as `LocationRecord` (source: `.clvisit`) + clustered `Visit` — **Acceptance:** Simulate location movement via Xcode → Debug → Simulate Location using a GPX file with 5 distinct stops; verify 5 `visits` rows appear in SQLite
2. Implement `AnimationView.swift` — `TimelineView` drives sequential reveal of polylines in chronological order over 45 seconds; controls: play/pause, replay, scrubber slider — **Acceptance:** Tap Play on populated ghost map; routes appear oldest-first and fade on time; animation completes in 40–50 seconds for a 2-year dataset; replay button resets and replays
3. Add `PrivacyInfo.xcprivacy` privacy manifest declaring: `NSPrivacyAccessedAPITypes` for location, `NSPrivacyCollectedDataTypes` (none), `NSPrivacyTracking = false` — **Acceptance:** Build archive in Xcode → validate with Instruments → Privacy Report shows no undeclared API usage
4. Implement `ExportService.swift` — `ImageRenderer` captures current `GhostMapView` at 3x scale → PNG data → `ShareLink` presenting iOS share sheet — **Acceptance:** Tap Share on populated map → share sheet appears → save to Photos → image shows ghost map overlays at full resolution (not blank)

**Verification checklist:**
- [ ] CLVisit simulation: 5 GPX stops → 5 rows in `visits` table (verify via `sqlite3` query)
- [ ] Animation plays on physical device without dropped frames (Instruments → Core Animation)
- [ ] Exported PNG at 3x renders ghost overlays correctly (check in Photos app at full zoom)
- [ ] `PrivacyInfo.xcprivacy` passes Xcode archive validation

---

## Phase 3: Alerts + Compare + Chapters (Weeks 6–7)

**Objective:** Ghost alerts scheduling and in-app inbox complete; two-period time comparison view; life chapters detection and scrubber.

**Tasks:**
1. Implement `AlertsManager.swift` — weekly `UNCalendarNotificationTrigger` (fires every Sunday at 9 AM) scans `ghost_locations` for ghostliness score >5.0 not alerted in last 30 days; schedules one `UNNotificationRequest` per qualifying ghost — **Acceptance:** In debug: replace trigger with `UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)` → notification appears in 10 seconds with correct ghost place name and "You haven't been here in X weeks" body
2. Implement `GhostInboxView.swift` — list of ghosts that have triggered alerts, sorted by ghostliness score; each row: place name, last visited date, score badge, dismiss button — **Acceptance:** After test alert fires → inbox shows the ghost entry; dismiss button marks `is_dismissed = 1` in SQLite and removes from list
3. Implement `ComparisonView.swift` — two date range pickers (Period A: start/end, Period B: start/end); map renders Period A routes in cyan and Period B routes in amber (`#FF9500`) simultaneously — **Acceptance:** Select Jan 1–Jun 30 2023 vs Jan 1–Jun 30 2024 from Takeout data; map shows visually distinct route patterns for each period
4. Implement `ChapterDetector.swift` — sliding 30-day window over visit bounding boxes; if centroid shifts >2km between consecutive windows, mark chapter boundary; minimum chapter duration: 60 days — **Acceptance:** Run `ChapterDetector` on your Takeout data; if you've moved or changed primary work location in the dataset's time range, it detects that event as a chapter boundary; prints detected chapters to console with date ranges
5. Implement `ChaptersView.swift` — horizontal `ScrollView` of chapter cards (date range + label); tapping a chapter animates map to that chapter's bounding box and shows only that chapter's routes — **Acceptance:** Tap each chapter card → map region animates to the correct geographic area; routes shown are filtered to that chapter's date range
6. Implement Mindful Mode in `SettingsView.swift` — `Toggle` stores pause-until date in `UserDefaults`; `AlertsManager` checks this date before scheduling any notification — **Acceptance:** Enable Mindful Mode → verify `UserDefaults` key `mindfulModePauseUntil` is set to 30 days from now → no ghost notifications fire during pause period (test by manually advancing the trigger)

**Verification checklist:**
- [ ] Ghost alert fires for a known ghost location from your real Takeout data
- [ ] Comparison view: cyan vs amber routes are visually distinct and geographically correct for the two selected periods
- [ ] Chapter detection finds ≥1 boundary in your real dataset (or produces a single "no chapters detected" state if data spans <6 months with no major location shifts)
- [ ] Mindful Mode pause: `UserDefaults` shows correct expiry date; no notifications in the pause window

---

## Phase 4: App Store Prep (Week 8)

**Objective:** TestFlight build validated, App Store listing complete, submitted for review.

**Tasks:**
1. Run full app on 2+ physical devices (iPhone and iPad) for 48 hours — **Acceptance:** Zero crashes in Crashlytics-equivalent (use Xcode Organizer → Crashes); all features function on both form factors
2. Create App Store screenshots: 6.7" (iPhone 15 Pro Max) and 12.9" (iPad Pro) in 4 slots — ghost map view, animation mid-playback, comparison view with two periods, ghost inbox — **Acceptance:** All 8 screenshot slots (4 per device size) filled; pass App Store Connect image dimension validation
3. Complete App Store Connect privacy questionnaire: Location data (precise, continuous, collected on device, not shared), no data collection, NSPrivacyTracking = false — **Acceptance:** Privacy nutrition label preview in App Store Connect shows correct data types; no "sells data" flag
4. Submit for App Review — **Acceptance:** App passes first review cycle. Pre-empt common rejections: test on iPhone SE (smallest supported screen), verify all `NSUsageDescription` strings explain why location is needed in plain English ("Ghost Routes uses your location to discover the places you've stopped visiting"), verify demo mode works if reviewer cannot test with real location history

**Pre-submission checklist:**
- [ ] Build archive passes all Xcode validation checks (no provisioning errors, no entitlement mismatches)
- [ ] `PrivacyInfo.xcprivacy` present in bundle (verify in Finder: right-click .ipa → Show Contents)
- [ ] All permission strings in `Info.plist` are present and human-readable
- [ ] App tested on iPhone SE 3rd gen (smallest screen) — no layout overflow
- [ ] Delete All Data flow tested on device — SQLite tables empty, notifications cancelled, progress bar resets to 0 days

---

## Testing Strategy

### Automated (unit tests — required before each phase advances)

**`TakeoutParserTests.swift`:**
- Parse `takeout_v1.json` (100 records) → 100 `LocationRecord` structs, correct `timestamp` values
- Parse `takeout_v2.json` (100 records) → 100 `LocationRecord` structs, correct `timestamp` values
- Parse file with 1 malformed record (missing `latitudeE7`) → 99 valid records, 1 error logged
- Parse empty `{"locations": []}` → 0 records, no crash
- `XCTMeasure`: parse 10MB fixture in <5 seconds

**`GhostDetectorTests.swift`:**
- 6 months synthetic data, 10 locations, 3 artificially dropped → detector returns those 3
- Ghost scores rank correctly: location dropped 90 days ago scores higher than location dropped 30 days ago
- Location at exactly 20% of peak frequency: NOT flagged as ghost (boundary condition)
- Location at 19.9% of peak frequency: flagged as ghost
- Dataset with <90 days of history: returns empty ghost array (threshold gate)

**`GeocodeManagerTests.swift`:**
- 3 sequential geocode calls: verify ≥1.1s elapsed between each via `Date` timestamps
- Cache hit: same coordinate geocoded twice → CLGeocoder called exactly once (verify with mock)

### Manual (per phase)
- Phase 1: Import real Takeout export → ghost map visually correct
- Phase 2: CLVisit simulation via Xcode GPX → visits in SQLite
- Phase 3: Ghost notification fires on device
- Phase 4: Full regression on physical iPhone + iPad
