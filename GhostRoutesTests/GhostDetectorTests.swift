import Testing
import Foundation
@testable import GhostRoutes

@Suite("GhostDetector")
struct GhostDetectorTests {

    // MARK: - Helpers

    /// Generate visits at a specific location over a date range.
    private func makeVisits(
        lat: Double,
        lng: Double,
        from start: Date,
        to end: Date,
        visitsPerMonth: Int
    ) -> [Visit] {
        let calendar = Calendar.current
        var visits: [Visit] = []
        var current = start

        while current < end {
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: current) ?? end
            let actualEnd = min(monthEnd, end)
            let daysInPeriod = max(
                calendar.dateComponents([.day], from: current, to: actualEnd).day ?? 30, 1
            )

            for i in 0..<visitsPerMonth {
                let dayOffset = (daysInPeriod * i) / max(visitsPerMonth, 1)
                guard let visitDate = calendar.date(byAdding: .day, value: dayOffset, to: current)
                else { continue }
                guard visitDate < actualEnd else { break }

                let duration = 1800
                visits.append(Visit(
                    clusterLat: lat,
                    clusterLng: lng,
                    arrivedAt: visitDate,
                    departedAt: visitDate.addingTimeInterval(Double(duration)),
                    durationSeconds: duration,
                    source: .takeout
                ))
            }

            current = monthEnd
        }

        return visits
    }

    private var referenceDate: Date {
        // Fixed reference date for deterministic tests: 2024-07-01
        Calendar.current.date(from: DateComponents(year: 2024, month: 7, day: 1))!
    }

    private func monthsAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -n, to: referenceDate)!
    }

    // MARK: - Core Detection

    @Test("Detects exactly 3 ghost locations from 10 total")
    func detectsThreeGhosts() {
        var allVisits: [Visit] = []

        // 7 active locations — steady visits throughout 12 months
        for i in 0..<7 {
            let lat = 37.77 + Double(i) * 0.01  // ~1km apart
            let lng = -122.42
            allVisits += makeVisits(
                lat: lat, lng: lng,
                from: monthsAgo(12), to: referenceDate,
                visitsPerMonth: 8
            )
        }

        // 3 ghost locations — active for 8 months, then abandoned for 4 months
        // 4-month gap exceeds the 90-day rolling window
        for i in 7..<10 {
            let lat = 37.77 + Double(i) * 0.01
            let lng = -122.42
            allVisits += makeVisits(
                lat: lat, lng: lng,
                from: monthsAgo(12), to: monthsAgo(4),
                visitsPerMonth: 8
            )
        }

        let ghosts = GhostDetector.detect(visits: allVisits, referenceDate: referenceDate)

        #expect(ghosts.count == 3)

        // Verify ghost coordinates match the abandoned locations (indices 7,8,9 → lat 37.84+)
        for ghost in ghosts {
            #expect(ghost.clusterLat >= 37.84)
        }
    }

    // MARK: - Score Ordering

    @Test("Ghost abandoned longer scores higher than one abandoned recently")
    func ghostScoreOrdering() {
        var allVisits: [Visit] = []

        // Ghost A: visited for 6 months, abandoned 6 months ago (long gap)
        allVisits += makeVisits(
            lat: 37.77, lng: -122.42,
            from: monthsAgo(12), to: monthsAgo(6),
            visitsPerMonth: 10
        )

        // Ghost B: visited for 8 months, abandoned 4 months ago (shorter gap)
        allVisits += makeVisits(
            lat: 37.80, lng: -122.42,
            from: monthsAgo(12), to: monthsAgo(4),
            visitsPerMonth: 10
        )

        let ghosts = GhostDetector.detect(visits: allVisits, referenceDate: referenceDate)

        #expect(ghosts.count == 2)
        // Ghost A (longer abandoned → higher weeksSinceLastVisit) should rank higher
        #expect(ghosts[0].clusterLat < 37.79)  // Ghost A at 37.77
    }

    // MARK: - Boundary Conditions

    @Test("Location at 30% of peak is NOT flagged as ghost")
    func aboveThresholdNotGhost() {
        var allVisits: [Visit] = []

        // Peak: 10 visits/month for 9 months, then 3 visits/month for 3 months (30% > 20%)
        allVisits += makeVisits(
            lat: 37.77, lng: -122.42,
            from: monthsAgo(12), to: monthsAgo(3),
            visitsPerMonth: 10
        )
        allVisits += makeVisits(
            lat: 37.77, lng: -122.42,
            from: monthsAgo(3), to: referenceDate,
            visitsPerMonth: 3
        )

        let ghosts = GhostDetector.detect(visits: allVisits, referenceDate: referenceDate)

        #expect(ghosts.isEmpty)
    }

    @Test("Location below 20% of peak IS flagged as ghost")
    func boundaryJustBelow20Percent() {
        var allVisits: [Visit] = []

        // Peak: 10 visits/month for 9 months, then 1 visit/month for 3 months (10%)
        allVisits += makeVisits(
            lat: 37.77, lng: -122.42,
            from: monthsAgo(12), to: monthsAgo(3),
            visitsPerMonth: 10
        )
        allVisits += makeVisits(
            lat: 37.77, lng: -122.42,
            from: monthsAgo(3), to: referenceDate,
            visitsPerMonth: 1
        )

        let ghosts = GhostDetector.detect(visits: allVisits, referenceDate: referenceDate)

        #expect(ghosts.count == 1)
    }

    // MARK: - Insufficient History

    @Test("Returns empty when history is less than 90 days")
    func insufficientHistory() {
        let sixtyDaysAgo = Calendar.current.date(
            byAdding: .day, value: -60, to: referenceDate
        )!

        let visits = makeVisits(
            lat: 37.77, lng: -122.42,
            from: sixtyDaysAgo, to: referenceDate,
            visitsPerMonth: 10
        )

        let ghosts = GhostDetector.detect(visits: visits, referenceDate: referenceDate)

        #expect(ghosts.isEmpty)
    }

    // MARK: - Clustering

    @Test("Visits 30m apart merge into one cluster; 200m apart stay separate")
    func clusterMerging() {
        // Two locations ~30m apart (should merge)
        let lat1 = 37.7749
        let lng1 = -122.4194
        let lat2 = 37.7749 + 0.00027  // ~30m north
        let lng2 = -122.4194

        // Third location ~200m away (should NOT merge)
        let lat3 = 37.7749 + 0.0018  // ~200m north
        let lng3 = -122.4194

        var allVisits: [Visit] = []
        allVisits += makeVisits(
            lat: lat1, lng: lng1,
            from: monthsAgo(12), to: monthsAgo(4),
            visitsPerMonth: 8
        )
        allVisits += makeVisits(
            lat: lat2, lng: lng2,
            from: monthsAgo(12), to: monthsAgo(4),
            visitsPerMonth: 8
        )
        allVisits += makeVisits(
            lat: lat3, lng: lng3,
            from: monthsAgo(12), to: monthsAgo(4),
            visitsPerMonth: 8
        )

        let ghosts = GhostDetector.detect(visits: allVisits, referenceDate: referenceDate)

        // Should have 2 ghosts: one merged cluster (lat1+lat2) and one separate (lat3)
        #expect(ghosts.count == 2)
    }

    // MARK: - Empty Input

    @Test("Empty visits array returns empty result")
    func emptyVisits() {
        let ghosts = GhostDetector.detect(visits: [], referenceDate: referenceDate)
        #expect(ghosts.isEmpty)
    }
}
