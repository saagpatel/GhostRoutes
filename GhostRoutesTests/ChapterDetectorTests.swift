import Testing
import Foundation
@testable import GhostRoutes

@Suite("ChapterDetector")
struct ChapterDetectorTests {

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

                visits.append(Visit(
                    clusterLat: lat,
                    clusterLng: lng,
                    arrivedAt: visitDate,
                    departedAt: visitDate.addingTimeInterval(1800),
                    durationSeconds: 1800,
                    source: .takeout
                ))
            }
            current = monthEnd
        }
        return visits
    }

    private var referenceDate: Date {
        Calendar.current.date(from: DateComponents(year: 2024, month: 7, day: 1))!
    }

    // MARK: - Chapter Detection

    @Test("City move at month 6 produces 2 chapters")
    func twoChapters() {
        var visits: [Visit] = []

        // SF for 6 months
        visits += makeVisits(
            lat: 37.7749, lng: -122.4194,
            from: Calendar.current.date(byAdding: .month, value: -12, to: referenceDate)!,
            to: Calendar.current.date(byAdding: .month, value: -6, to: referenceDate)!,
            visitsPerMonth: 8
        )

        // LA for 6 months (>2km shift)
        visits += makeVisits(
            lat: 34.0522, lng: -118.2437,
            from: Calendar.current.date(byAdding: .month, value: -6, to: referenceDate)!,
            to: referenceDate,
            visitsPerMonth: 8
        )

        let chapters = ChapterDetector.detect(visits: visits)

        #expect(chapters.count == 2)
    }

    @Test("All visits in same area produces 1 chapter")
    func singleChapter() {
        let visits = makeVisits(
            lat: 37.7749, lng: -122.4194,
            from: Calendar.current.date(byAdding: .month, value: -12, to: referenceDate)!,
            to: referenceDate,
            visitsPerMonth: 8
        )

        let chapters = ChapterDetector.detect(visits: visits)

        #expect(chapters.count == 1)
    }

    @Test("Visits under 60 days returns empty")
    func tooShort() {
        let visits = makeVisits(
            lat: 37.7749, lng: -122.4194,
            from: Calendar.current.date(byAdding: .day, value: -50, to: referenceDate)!,
            to: referenceDate,
            visitsPerMonth: 8
        )

        let chapters = ChapterDetector.detect(visits: visits)

        #expect(chapters.isEmpty)
    }

    @Test("Three distinct locations produce 3 chapters")
    func threeChapters() {
        var visits: [Visit] = []

        // SF (4 months)
        visits += makeVisits(
            lat: 37.7749, lng: -122.4194,
            from: Calendar.current.date(byAdding: .month, value: -12, to: referenceDate)!,
            to: Calendar.current.date(byAdding: .month, value: -8, to: referenceDate)!,
            visitsPerMonth: 8
        )

        // LA (4 months)
        visits += makeVisits(
            lat: 34.0522, lng: -118.2437,
            from: Calendar.current.date(byAdding: .month, value: -8, to: referenceDate)!,
            to: Calendar.current.date(byAdding: .month, value: -4, to: referenceDate)!,
            visitsPerMonth: 8
        )

        // NYC (4 months)
        visits += makeVisits(
            lat: 40.7128, lng: -74.0060,
            from: Calendar.current.date(byAdding: .month, value: -4, to: referenceDate)!,
            to: referenceDate,
            visitsPerMonth: 8
        )

        let chapters = ChapterDetector.detect(visits: visits)

        #expect(chapters.count == 3)
    }

    @Test("Empty visits returns empty chapters")
    func emptyVisits() {
        let chapters = ChapterDetector.detect(visits: [])
        #expect(chapters.isEmpty)
    }
}
