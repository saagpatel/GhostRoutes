import Testing
import Foundation
@testable import GhostRoutes

@Suite("VisitClusterer")
struct VisitClustererTests {

    private func makeRecords(
        lat: Double,
        lng: Double,
        startTime: Date,
        count: Int,
        intervalSeconds: TimeInterval
    ) -> [LocationRecord] {
        (0..<count).map { i in
            LocationRecord(
                latitude: lat,
                longitude: lng,
                timestamp: startTime.addingTimeInterval(Double(i) * intervalSeconds),
                source: .takeout
            )
        }
    }

    // MARK: - Basic Clustering

    @Test("10 records at same location, 5 min apart → 1 visit")
    func singleCluster() {
        let records = makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: Date(timeIntervalSince1970: 1672531200),
            count: 10,
            intervalSeconds: 300  // 5 min
        )

        let visits = VisitClusterer.cluster(records)

        #expect(visits.count == 1)
        #expect(visits[0].durationSeconds == 2700)  // 9 * 300s = 45 min
    }

    @Test("Records at 2 locations 1km apart → 2 visits")
    func twoLocations() {
        let start = Date(timeIntervalSince1970: 1672531200)
        var records: [LocationRecord] = []

        // Location 1: 5 records, 5 min apart
        records += makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: start, count: 5, intervalSeconds: 300
        )
        // Location 2: 5 records, 5 min apart, starting 10 min after last at location 1
        records += makeRecords(
            lat: 37.7849, lng: -122.4194,  // ~1km north
            startTime: start.addingTimeInterval(1800),  // 30 min later
            count: 5, intervalSeconds: 300
        )

        let visits = VisitClusterer.cluster(records)

        #expect(visits.count == 2)
    }

    // MARK: - Time Gap

    @Test("2-hour gap at same location → 2 separate visits")
    func timeGapSplits() {
        let start = Date(timeIntervalSince1970: 1672531200)
        var records: [LocationRecord] = []

        // First visit: 5 records
        records += makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: start, count: 5, intervalSeconds: 300
        )
        // Same location, but 2 hours later
        records += makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: start.addingTimeInterval(7200),
            count: 5, intervalSeconds: 300
        )

        let visits = VisitClusterer.cluster(records)

        #expect(visits.count == 2)
    }

    // MARK: - Minimum Duration

    @Test("Visit shorter than 5 min is filtered out")
    func shortVisitFiltered() {
        let start = Date(timeIntervalSince1970: 1672531200)
        // Only 2 records, 2 min apart = 2 min duration < 5 min threshold
        let records = makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: start, count: 2, intervalSeconds: 120
        )

        let visits = VisitClusterer.cluster(records)

        #expect(visits.isEmpty)
    }

    // MARK: - Edge Cases

    @Test("Empty records → empty visits")
    func emptyRecords() {
        let visits = VisitClusterer.cluster([])
        #expect(visits.isEmpty)
    }

    @Test("Single record → no visit")
    func singleRecord() {
        let records = [LocationRecord(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: Date(),
            source: .takeout
        )]
        let visits = VisitClusterer.cluster(records)
        #expect(visits.isEmpty)
    }
}
