# Ghost Routes — App Store Connect Metadata

## Identity

| Field | Value |
|-------|-------|
| **Name** | Ghost Routes |
| **Subtitle** | Map the places you left behind |
| **Bundle ID** | com.ghostroutes.app |
| **SKU** | GHOSTROUTES-001 |
| **Primary Category** | Navigation |
| **Secondary Category** | Utilities |
| **Age Rating** | 4+ |
| **Price** | Free |
| **Availability** | All territories |

---

## Keywords

```
location history,ghost map,places,visited,privacy,local,CLVisit,map,routes,memory
```

*(100 character limit — these are 76 characters)*

---

## Description

Every place you used to go is still on the map. You just stopped showing up.

Ghost Routes turns your iPhone's location history into a ghost map — a visualization that contrasts the routes and places you actively visit (bright, solid lines) against the ones you've quietly abandoned (translucent, fading traces). That coffee shop you went to every week for two years. The neighborhood you moved away from. The gym you were serious about.

Import your Google Location History or let Ghost Routes accumulate visits quietly in the background using Apple's CLVisit API. Then open the map and see your past staring back at you.

**What you get:**
• Ghost map — active routes in cyan, abandoned places fading by time and frequency
• Google Takeout import — bring in years of location history in minutes
• Ongoing CLVisit accumulation — your iPhone already knows where you go
• Ghost detection algorithm — places you visited regularly but haven't been in 90+ days
• Ghostliness scoring — ranked by how dramatically your visits dropped off
• Chronological playback — watch your location history animate oldest-first over 45 seconds
• Two-period comparison view — see how your routes changed between any two time spans
• Life chapters — automatic detection of major shifts in where you spend your time
• Ghost alerts — local notifications when a place crosses the ghost threshold
• Ghost Inbox — your history of detected abandonments, dismissible
• Place names — reverse geocoded via Apple's on-device CLGeocoder, no third-party APIs
• Mindful Mode — pause alerts for 30 days when you just need quiet
• Static PNG export — share a snapshot of your ghost map via the system share sheet
• One-tap data deletion — everything gone, no confirmation loops

**Privacy, for real:**
Location data never leaves your device. No backend. No account. No network egress for your data. The database is encrypted at rest and excluded from iCloud backup by design. The only thing Ghost Routes sends over the network is a reverse geocode request to Apple's infrastructure to name your ghost places.

No subscriptions. No IAP. Free, permanently.

---

## Promotional Text

*(Optional — appears above description, can be updated without new app version)*

```
See the places you used to go. Your location history, visualized as a ghost map — all on device, nothing in the cloud.
```

---

## Support URL

*(Enter your support URL — e.g. a GitHub repo or personal site)*

---

## Privacy Policy URL

*(Required — can be a simple page stating no data is collected)*

---

## Screenshots

### Required Sizes
- **6.7" Display** — 1290 × 2796 px (iPhone 16 Pro Max / iPhone 15 Pro Max)
- **6.1" Display** — 1179 × 2556 px (iPhone 16 / iPhone 15)

### Screenshot Plan (4 screenshots per size)

| # | Screen | Simulator State | Headline Overlay |
|---|--------|-----------------|------------------|
| 1 | GhostMapView | Map centered on a recognizable city grid; 3–5 cyan polylines (active routes); 4–6 translucent fading white polylines (ghosts) spread across the viewport; ghost callout visible for one location showing place name + "Last visited 4 months ago" | "See where you stopped going." |
| 2 | AnimationView | Mid-playback state — some routes already revealed in cyan; scrubber at roughly 40% progress; play/pause control visible at bottom | "Watch your history unfold." |
| 3 | ComparisonView | Split map with Period A (2023) routes in cyan and Period B (2024) routes in amber; date range chips visible at top showing the two selected periods; routes clearly occupy different geographic areas | "Compare any two chapters of your life." |
| 4 | GhostInboxView | List of 4–5 ghost alerts with place names, ghostliness score badges, last-visited dates, and dismiss buttons; first entry partially highlighted | "Your ghost inbox. Places that remember you." |

### How to Take Screenshots
1. Open Xcode → Simulator → select iPhone 16 Pro Max
2. Build and run the GhostRoutes target with sample data loaded (use the bundled test fixtures or import a trimmed Takeout JSON)
3. Navigate to each screen state
4. **Xcode menu: Product → Simulator → Take Screenshot** (saves to Desktop)
   OR: `xcrun simctl io booted screenshot ~/Desktop/screenshot.png`
5. Repeat for iPhone 16 (6.1") by switching simulator
6. Add marketing text overlays in Sketch, Figma, or Canva before uploading

---

## App Review Notes

```
Ghost Routes is a privacy-first location history visualizer. No login, no network access for user data,
no special entitlements beyond location (CLVisit, "Always" or "When In Use") and local notifications.
All location data is stored on-device in an encrypted SQLite database excluded from iCloud backup.

The app has two data sources:
1. CLVisit API — accumulates visits passively in the background (requires location permission)
2. Google Takeout import — user imports their own Location History JSON from the Files app

To test core features without years of location history:
1. On first launch, tap "Import from Google Takeout" and use the provided sample JSON
   (or use the simulator's location simulation feature with a GPX file)
2. After import, the ghost map should populate with routes and 1–3 ghost locations
3. Tap "Animate" to watch the chronological playback
4. Tap a ghost polyline to see the place name callout
5. Navigate to Compare tab and select two date ranges to see the comparison view

Location permission string explains the purpose clearly:
"Ghost Routes uses your location to discover the places you've stopped visiting."

No reviewer account needed. No in-app purchases. The app is entirely free.
```

---

## Checklist Before Submission

- [ ] Bundle ID `com.ghostroutes.app` registered in Apple Developer portal
- [ ] App icon 1024×1024 appears correctly in Xcode asset catalog (no warnings)
- [ ] `PrivacyInfo.xcprivacy` present in bundle — declares Location API, `NSPrivacyTracking = false`
- [ ] `NSLocationAlwaysAndWhenInUseUsageDescription` and `NSLocationWhenInUseUsageDescription` in Info.plist with plain-English strings
- [ ] `NSUserNotificationsUsageDescription` in Info.plist (for ghost alerts)
- [ ] Archive succeeds: `Product → Archive` with no errors
- [ ] Validate App passes with 0 errors (entitlement check, privacy manifest)
- [ ] All 8 screenshots uploaded (4 per required size)
- [ ] Description, keywords, subtitle filled in App Store Connect
- [ ] Price set to Free in Pricing and Availability
- [ ] Age rating questionnaire complete (4+)
- [ ] Support URL and Privacy Policy URL provided
- [ ] Privacy nutrition label: Location (Used, Not Linked to User, App Functionality); no data sold; no tracking
- [ ] TestFlight internal test complete — import Takeout JSON, verify ghost map, playback, comparison, inbox
- [ ] Delete All Data flow tested on device — SQLite empty, notifications cancelled, day count resets to 0
- [ ] Test on iPhone SE (3rd gen) — smallest supported screen, verify no layout overflow
- [ ] Submit for Review
