import CoreLocation
import Testing
@testable import GhostRoutes

@Suite("DouglasPeucker")
struct DouglasPeuckerTests {

    @Test("Straight line of 100 points simplifies to 2 endpoints")
    func straightLine() {
        // 100 points on a straight line from (0, 0) to (1, 1)
        let coords = (0..<100).map { i in
            CLLocationCoordinate2D(
                latitude: Double(i) / 99.0,
                longitude: Double(i) / 99.0
            )
        }

        let simplified = DouglasPeucker.simplify(coords, tolerance: 100)

        #expect(simplified.count == 2)
        #expect(simplified.first?.latitude == coords.first?.latitude)
        #expect(simplified.last?.latitude == coords.last?.latitude)
    }

    @Test("Right-angle path preserves the corner point")
    func rightAngle() {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.77, longitude: -122.41),  // East
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),  // North (corner)
        ]

        // Very tight tolerance — should keep all points
        let simplified = DouglasPeucker.simplify(coords, tolerance: 1)

        #expect(simplified.count == 3)
    }

    @Test("Two points return as-is")
    func twoPoints() {
        let coords = [
            CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42),
            CLLocationCoordinate2D(latitude: 37.78, longitude: -122.41),
        ]

        let simplified = DouglasPeucker.simplify(coords, tolerance: 50)

        #expect(simplified.count == 2)
    }

    @Test("Empty and single point return as-is")
    func edgeCases() {
        #expect(DouglasPeucker.simplify([], tolerance: 50).isEmpty)

        let single = [CLLocationCoordinate2D(latitude: 37.77, longitude: -122.42)]
        #expect(DouglasPeucker.simplify(single, tolerance: 50).count == 1)
    }
}
