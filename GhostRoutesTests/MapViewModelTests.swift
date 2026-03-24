import CoreLocation
import Testing
import Foundation
@testable import GhostRoutes

@Suite("MapViewModel")
struct MapViewModelTests {

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

    // MARK: - Route Segment Building

    @Test("Two records produce 1 segment with correct startDate")
    func singleSegment() {
        let start = Date(timeIntervalSince1970: 1672531200)
        let records = makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: start, count: 5, intervalSeconds: 300
        )

        let segments = MapViewModel.buildRouteSegments(from: records, ghosts: [])

        #expect(segments.count == 1)
        #expect(abs(segments[0].startDate.timeIntervalSince(start)) < 1.0)
    }

    @Test("Time gap > 3600s splits into 2 segments")
    func timeGapSplits() {
        let start = Date(timeIntervalSince1970: 1672531200)
        var records = makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: start, count: 3, intervalSeconds: 300
        )
        // Add records 2 hours later
        records += makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: start.addingTimeInterval(7200), count: 3, intervalSeconds: 300
        )

        let segments = MapViewModel.buildRouteSegments(from: records, ghosts: [])

        #expect(segments.count == 2)
    }

    @Test("Segment near ghost cluster has isGhost = true")
    func ghostProximity() {
        let records = makeRecords(
            lat: 37.7749, lng: -122.4194,
            startTime: Date(timeIntervalSince1970: 1672531200),
            count: 5, intervalSeconds: 300
        )

        let ghost = GhostLocation(
            clusterLat: 37.7749,
            clusterLng: -122.4194,
            peakVisitsPerMonth: 10,
            currentVisitsPerMonth: 0,
            ghostlinessScore: 8.0,
            peakPeriodStart: Date(),
            peakPeriodEnd: Date(),
            lastVisitAt: Date(),
            isDismissed: false
        )

        let segments = MapViewModel.buildRouteSegments(from: records, ghosts: [ghost])

        #expect(segments.count == 1)
        #expect(segments[0].isGhost == true)
    }

    @Test("Empty records produce empty segments")
    func emptyRecords() {
        let segments = MapViewModel.buildRouteSegments(from: [], ghosts: [])
        #expect(segments.isEmpty)
    }

    // MARK: - Animation Filtering

    @Test("visibleSegmentsForAnimation filters by cutoff date")
    @MainActor
    func animationFiltering() {
        let vm = MapViewModel()
        let early = Date(timeIntervalSince1970: 1672531200)
        let late = Date(timeIntervalSince1970: 1688169600)

        vm.visibleRoutes = [
            MapViewModel.RouteSegment(
                coordinates: [CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)],
                isGhost: false,
                ghostlinessScore: nil,
                startDate: early
            ),
            MapViewModel.RouteSegment(
                coordinates: [CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41)],
                isGhost: true,
                ghostlinessScore: 5.0,
                startDate: late
            ),
        ]

        let midpoint = Date(timeIntervalSince1970: (early.timeIntervalSince1970 + late.timeIntervalSince1970) / 2)
        let filtered = vm.visibleSegmentsForAnimation(cutoff: midpoint)

        #expect(filtered.count == 1)
        #expect(filtered[0].isGhost == false)
    }
}
