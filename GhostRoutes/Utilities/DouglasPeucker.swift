import CoreLocation
import Foundation

enum DouglasPeucker {

    /// Simplify a polyline by removing points within `tolerance` meters of the line.
    static func simplify(
        _ coordinates: [CLLocationCoordinate2D],
        tolerance: Double
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 2 else { return coordinates }

        // Find point with maximum distance from line between first and last
        var maxDistance = 0.0
        var maxIndex = 0

        let first = coordinates.first!
        let last = coordinates.last!

        for i in 1..<(coordinates.count - 1) {
            let dist = crossTrackDistance(
                point: coordinates[i],
                lineStart: first,
                lineEnd: last
            )
            if dist > maxDistance {
                maxDistance = dist
                maxIndex = i
            }
        }

        if maxDistance > tolerance {
            // Recurse on both halves
            let left = simplify(Array(coordinates[...maxIndex]), tolerance: tolerance)
            let right = simplify(Array(coordinates[maxIndex...]), tolerance: tolerance)
            // Concatenate, avoiding duplicate at split point
            return Array(left.dropLast()) + right
        } else {
            return [first, last]
        }
    }

    /// Perpendicular distance from a point to a great-circle line (in meters).
    /// Uses spherical cross-track formula.
    private static func crossTrackDistance(
        point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let R = 6_371_000.0  // Earth radius in meters

        let d13 = haversineDistance(
            lat1: lineStart.latitude, lng1: lineStart.longitude,
            lat2: point.latitude, lng2: point.longitude
        ) / R

        let θ13 = bearing(from: lineStart, to: point)
        let θ12 = bearing(from: lineStart, to: lineEnd)

        return abs(asin(sin(d13) * sin(θ13 - θ12))) * R
    }

    /// Initial bearing from one coordinate to another (radians).
    private static func bearing(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let dLng = (end.longitude - start.longitude) * .pi / 180

        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)

        return atan2(y, x)
    }
}
