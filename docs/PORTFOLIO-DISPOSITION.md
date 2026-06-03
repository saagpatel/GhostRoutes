# Ghost Routes — Portfolio Disposition

**Status:** Release Frozen (iOS App Store) — Swift 6 + SwiftUI +
MapKit + GRDB privacy-first location-history visualizer on
`origin/main`, with full App Store submission scaffolding shipped:
`APPSTORE-METADATA.md`, fastlane `deliver` config, `DEVELOPMENT_TEAM`
wired, Privacy Manifest, scheme generation, `ExportOptions.plist`,
PRIVACY.md (linked from App Store privacy URL), copyright applied,
and AI-generated app icon replacing the placeholder. **Third member
of the iOS App Store cluster** — Calibrate / Chromafield /
**GhostRoutes** now demonstrates the cluster pattern works across
three structurally-distinct iOS apps (prediction game / Metal
instrument / location-data visualizer).

> Disposition uses strict `origin/main` verification.
> **Stabilizes the iOS App Store cluster at 3 members in 2 rounds.**

---

## Verification posture

This repo has **only `origin`** (`saagpatel/GhostRoutes`) — no
`legacy-origin` remote. Clean migration state. Local clone's `main`
is tracking `origin/main` correctly.

Specifically verified on `origin/main`:

- Tip: `5055b4e` chore: replace placeholder icon with AI-generated app
  icon
- Substantive App Store prep commits on `origin/main`:
  - `5055b4e` chore: replace placeholder icon with AI-generated app icon
  - `475374e` chore: add fastlane deliver config for App Store metadata
    upload
  - `119a981` chore: replace placeholder app icon with gradient design
  - `5d7be45` chore: app store archive prep (signing, icons,
    screenshots)
  - `951c18d` chore: add privacy policy and update metadata URLs
  - `877e18e` chore: add copyright to metadata and ExportOptions.plist
  - `c650eac` chore(docs): add App Store Connect metadata
  - `81fd300` chore: App Store prep — DEVELOPMENT_TEAM, Privacy
    Manifest, scheme generation
- **Release scaffolding shipped on canonical main:**
  - `APPSTORE-METADATA.md` (full identity / keywords / description /
    promotional text / privacy URL pointing to repo's `PRIVACY.md`)
  - `PRIVACY.md` (linked from App Store metadata)
  - `fastlane/` (deliver config)
  - Privacy Manifest + DEVELOPMENT_TEAM
  - `project.yml` (XcodeGen-driven xcodeproj regeneration)
  - AI-generated icon
- Default branch: `main`

---

## Current state in one paragraph

Ghost Routes is a Swift 6 + SwiftUI + MapKit + GRDB privacy-first
visualizer for personal Google Takeout location history. The Takeout
importer streams `Records.json` in chunks, writing raw location
points to GRDB SQLite in batches of 500. A `VisitClusterer` struct
runs a temporal-spatial sweep, producing place records and visit events
in separate tables. A `GhostDetector` queries rolling frequency
windows in SQL to surface places the user has stopped visiting
(quietly dropped places, abandoned routes — the "ghost" framing).
SwiftUI consumes these via `@State` view models loaded asynchronously
via `.task`; the MapKit overlay uses `MapPolyline` entries inside a
SwiftUI `Map` view, with `onMapCameraChange` pruning visible segments
to avoid the all-overlays-at-once trap. Per
memory: v1.0 App Store ready. The release commits on canonical main
confirm: fastlane deliver + Privacy Manifest + DEVELOPMENT_TEAM +
final icon shipped; only the App Store Connect upload + screenshots +
submit remain.

For full detail see:
- `README.md` on `origin/main`
- `APPSTORE-METADATA.md`
- `PRIVACY.md` (linked from App Store privacy URL)
- `IMPLEMENTATION-ROADMAP.md`

---

## Why "Release Frozen (iOS App Store)" — third cluster member

Ghost Routes is the **third** iOS app audited; the cluster signature
holds:

| Signal | Calibrate | Chromafield | **Ghost Routes** |
|---|---|---|---|
| DEVELOPMENT_TEAM wired | `cd0031b` | `cf76108` | `81fd300` |
| Privacy Manifest | `63c1b24` | `cf76108` | `81fd300` |
| APPSTORE-METADATA.md | Yes | Yes | Yes |
| fastlane deliver config | Implied | `9341cc2` | `475374e` |
| ExportOptions.plist | Yes | Yes | Yes |
| AI-generated final icon | n/a | `72c89b0` | `5055b4e` |
| Privacy policy artifact on main | n/a (game) | URL only | **`PRIVACY.md` file on main** |

Three rows, same pattern. The cluster shape is now stable enough that
**triage of the remaining iOS apps in the portfolio (Liminal /
Nocturne / Redact / RoomTone / Seismoscope / Terroir / TideEngine /
Wavelength) can be done by quick scan of these signal columns** — no
new investigation needed per repo.

Ghost Routes extends the cluster with one new artifact: **PRIVACY.md
on canonical main as the App Store privacy URL target.** Calibrate
and Chromafield do not need this (predictions / Metal art have low
data-collection surface). Ghost Routes ingests the user's entire
Google Takeout location history — the privacy URL is load-bearing.

---

## Cluster taxonomy update

The iOS App Store cluster now has **three confirmed members**:

| Cluster | Count | Distribution |
|---|---|---|
| Signing (Apple desktop) | 22 | DMG via Apple Developer ID |
| **iOS App Store** | **3** | Calibrate / Chromafield / **Ghost Routes** |
| Static-host (web, 3 sub-shapes) | 3 | PWA / static SPA / SSR+Supabase |
| Self-hosted service | 1 | launchd + nginx |
| PyPI distribution | 1 (member 2 incoming this round) | `pip install` |
| Local-first pipeline | 1 | Worker + adapters |
| Operator-tool / dogfood | 1 | Operator-self |

Three members puts the iOS cluster on the same maturity level as the
static-host cluster (which also has 3 sub-shape members). The
distinguishing axis between iOS apps is **data-surface category** —
games (Calibrate), creative tools (Chromafield), personal-data
visualizers (Ghost Routes) — not signing or build mechanics.

---

## Unblock trigger (operator)

When ready to ship publicly:

1. **App Store Connect record created** for Ghost Routes bundle ID.
2. **Privacy nutrition labels — high-stakes for this app.** Even
   though Ghost Routes is local-first (no cloud, no server, no
   analytics), the data ingested is **historical location data from
   Google Takeout**. App Store reviewers and informed users will
   scrutinize this. Correct nutrition label posture:
   - "Location" → "Data Linked to You: No, Data Used to Track You: No"
   - Verify `PRIVACY.md` claims match the nutrition label exactly
3. **Required Reason API** — the Privacy Manifest must declare any
   API that touches user files (PHPhotoLibrary if export uses it;
   `NSPrivacyAccessedAPICategoryFileTimestamp` if file mtime is read
   for Takeout import).
4. **Background processing posture** — Takeout imports can take
   minutes for years of history. Verify behavior under iPad
   foreground-only backgrounding policy (operation completes, can be
   resumed, doesn't lose progress).
5. **MapKit overlay performance** — verify on lower-end iPads /
   older iPhones (A12/A13) that the time-slice tile overlay doesn't
   stutter when the user scrubs the timeline rapidly.
6. **Required screenshots** — per `APPSTORE-METADATA.md` plan.
7. **`fastlane deliver` upload** — config already on main; metadata
   upload is scripted.
8. **Submit for review.**

Estimated operator time once App Store Connect record + screenshots
exist: ~4-5 hours (privacy nutrition label care drives the timing).

---

## Portfolio operating system instructions

| Aspect | Posture |
|---|---|
| Portfolio status | `Release Frozen (iOS App Store)` |
| Distribution channel | **App Store Connect** |
| Review cadence | Suspend overdue counting |
| Resurface conditions | (a) Operator submits for App Store Review, (b) review feedback requires changes (privacy review especially), (c) Google Takeout schema change breaks the importer, (d) iOS location-data API tightening, or (e) v1.1 scope packet |
| Co-batch with | iOS App Store cluster: Calibrate / Chromafield / **Ghost Routes** — **now 3 repos** |
| Special concern | **Privacy nutrition labels are load-bearing.** Location data + historical scope = the privacy review will be more rigorous than a typical photo / drawing app. `PRIVACY.md` on main must reconcile with the App Store labels. |
| Special concern | **Google Takeout format drift.** Google has changed the Takeout location-history format multiple times (Records.json → semanticSegments.json → other variants). The importer is the most likely breakage path; pin/test against known good Takeout snapshots. |
| Special concern | **GRDB migration safety.** Local DB schema changes on app update need migrations; losing place clusters / visit events on an upgrade would be a category-bug for this app. |
| Special concern | **MapKit overlay redraw on time-slice scrub.** Performance budget is tight on older devices; verify before submission. |
| Special concern | **iOS 17+ minimum (required for MapKit `MapPolyline` overlay support).** Confirm minimum-iOS target in xcodeproj matches the Swift 6 / MapKit reality so older iPad users aren't shown a "device not supported" surprise. |

---

## Why this row stabilizes the iOS App Store cluster shape

Calibrate founded the cluster, Chromafield demonstrated the pattern
applies to a structurally-different iOS app. Ghost Routes demonstrates
the pattern survives a **third structurally-different shape** —
specifically, an app whose distinguishing characteristic is **user
data privacy**, which is the App Store concern category most likely
to break a cluster's "looks ready" claim.

If Ghost Routes can use the same DEVELOPMENT_TEAM + Privacy Manifest
+ APPSTORE-METADATA + fastlane deliver flow as Calibrate (game,
local-data-only) and Chromafield (creative tool, photo/video export)
**without bespoke privacy infrastructure being required at the cluster
level**, then the cluster signature is robust. The PRIVACY.md file on
canonical main is a per-app artifact, not a cluster-shaping artifact.

Conclusion: **the cluster reactivation procedure is stable.** Future
rounds can audit remaining iOS apps in batches without per-app
methodology rediscovery.

---

## Reactivation procedure (for the next code session)

1. Verify `git branch -vv` shows `main` tracking `origin/main`.
   Already correct as of this disposition pass.
2. Review the local stash (`r12-ghostroutes-stash`) — contains
   modifications to `CLAUDE.md` and **`project.yml`** (XcodeGen
   driver). The `project.yml` change is potentially substantive —
   inspect before discarding.
3. **Open `GhostRoutes.xcodeproj`** (regenerated from `project.yml`
   via XcodeGen) — confirm DEVELOPMENT_TEAM is still valid.
4. **Audit `PRIVACY.md`** against current data-flow reality (local
   only? any analytics SDK that snuck in? any crash reporter?).
5. **Test Google Takeout importer** against a current Takeout export
   — Google's schema drifts. Pin a known-good test fixture in
   `fixtures/` if not already.
6. **Run XCTest target** if one exists.
7. **Confirm `fastlane deliver` dry run** before live upload.
8. **Verify privacy nutrition labels match `PRIVACY.md` exactly.**

---

## Last known reference

| Field | Value |
|---|---|
| `origin/main` tip | `5055b4e` chore: replace placeholder icon with AI-generated app icon |
| Last substantive commit | `475374e` chore: add fastlane deliver config for App Store metadata upload |
| Default branch | `main` |
| Build system | **iOS / iPadOS / Swift 6 (strict concurrency) / SwiftUI / MapKit / GRDB / XcodeGen** |
| Phases shipped | v1.0 App Store ready per memory; release scaffolding confirms on canonical main |
| Release scaffolding | **`APPSTORE-METADATA.md` + `PRIVACY.md` + fastlane deliver + ExportOptions.plist + Privacy Manifest + DEVELOPMENT_TEAM + `project.yml`** |
| Distribution channel | **App Store Connect** |
| Tech distinguisher | Google Takeout streaming import + GRDB SQLite + temporal-spatial clustering + MapPolyline viewport gating + Swift 6 strict concurrency (iOS 17+) |
| Blocker | App Store Connect submission flow + privacy nutrition label review (operator-only) |
| Migration state | **No `legacy-origin` remote** — clean |
| Distinguishing feature | **Third iOS App Store cluster member.** Stabilizes the cluster pattern across three structurally-distinct iOS apps (game / Metal instrument / privacy-first location visualizer). Adds `PRIVACY.md` on canonical main as the first per-app privacy artifact in the cluster. |
